# Plan: narrow GH Actions SA IAM + verify end-to-end (Phase 4 of #32)

## Goal

Drop `roles/container.developer` from the GitHub Actions service account. CI no longer needs cluster access — Phase 3 made it write images to AR and image tags to git, never `kubectl`. Once the role is gone, the SA has the minimum surface for its actual job: push to Artifact Registry, push commits back to the repo via `GITHUB_TOKEN`.

End state: Argo CD owns deploys end-to-end. CI builds + commits. The `feedforge-github-actions` SA has only `roles/artifactregistry.writer`. Issue #32 closes.

## Context

- Issue: [#32](https://github.com/huchka/feedforge/issues/32). Phases 1, 2, 3 merged. Phase 3 PR was #48; the build-and-bump workflow has run successfully end-to-end at least once (commit `73eceb2`).
- One leftover from Phase 3: the live Application in `argocd` namespace doesn't yet have `syncPolicy` applied. The YAML in git has it (committed in PR #48), but the spec change wasn't propagated to the cluster — Argo CD doesn't self-manage the Application yet. So auto-sync is still off.
- Branch: `infra/32-argocd-phase4-narrow-iam`.

## Decisions

### D1 — Scope: SA IAM only, not Application self-management
This phase narrows the SA. Argo-managing-Argo (App-of-Apps so the Application's `syncPolicy` propagates via git) is still deferred to post-prod. Reason: until prod arrives, the gain doesn't justify the bootstrap awkwardness, and a one-time `kubectl apply` of the Application is fine.

### D2 — Order: verify GitOps works, *then* narrow
The safest sequence:
1. Apply `syncPolicy` to the live Application (engage auto-sync).
2. Watch Argo CD pick up the bot-committed tag (`592b57f...`) and reconcile.
3. *Then* narrow the SA in terraform.
4. Trigger a fresh build, watch the full loop work with the narrowed SA.

If we narrow before verifying, a permission gap we missed in Phase 3 would manifest as a CI failure that's hard to distinguish from a build flake. Verifying GitOps first eliminates that ambiguity.

### D3 — Don't touch the Workload Identity Federation pool / provider
The pool and provider blocks (`google_iam_workload_identity_pool`, `_provider`, `_iam_member`) stay exactly as-is. Only the project-level role binding for `container.developer` is removed. The SA still impersonates the pool, still gets a token, still pushes images.

### D4 — Keep `roles/iam.workloadIdentityUser` on the SA
That binding (`google_service_account_iam_member.github_actions_workload_identity_user`) is what lets the GitHub OIDC token impersonate the SA. Dropping it would break auth entirely. Untouched.

## Files

| Change | Path | Notes |
|---|---|---|
| Modify | `terraform/modules/github-actions/main.tf` | Remove `"roles/container.developer"` from `local.github_actions_roles`. One line. |

That's the entire IaC change. The local list goes from two roles to one.

## Steps

### 1. Branch + plan doc
- `git checkout -b infra/32-argocd-phase4-narrow-iam`
- This file at `.plans/20260506-argocd-phase4-narrow-iam.md`.

### 2. Engage auto-sync (no code change — the YAML in git is already correct)
You run:
```sh
git pull --ff-only   # ensure local has the bot's tag-bump commit (73eceb2)
kubectl apply -f k8s/argocd/applications/feedforge-dev.yaml
kubectl -n argocd get application feedforge-dev -o jsonpath='{.spec.syncPolicy}' ; echo
```
**Check:** the second command returns the `syncPolicy` block (not empty). Within ~3 min, Argo CD detects the new policy and starts reconciling toward `592b57f...` (the bot-committed tag). Watch:
```sh
kubectl -n argocd get application feedforge-dev -w
```
Expected: `OutOfSync → Progressing → Synced`. Pods roll once with the `592b57f...` image. After it lands, `kubectl -n feedforge get pods` shows fresh ages on backend, frontend, summarizer.

### 3. Edit the terraform
Remove one line from `local.github_actions_roles` in `terraform/modules/github-actions/main.tf`. Keep the trailing comment:
```hcl
locals {
  github_actions_roles = [
    "roles/artifactregistry.writer", # push images
  ]
}
```
**Check:** `terraform fmt -recursive` shows no diff.

### 4. terraform plan + apply (you run)
```sh
cd terraform/environments/dev
terraform plan -out=phase4.tfplan
```
**Check:** plan shows exactly one destroy:
```
# module.github_actions.google_project_iam_member.github_actions_roles["roles/container.developer"] will be destroyed
```
No other changes. If it shows anything else, stop.

```sh
terraform apply phase4.tfplan
```
Apply takes ~5s for an IAM binding removal.

### 5. Verify end-to-end with narrowed SA
Trigger a build to confirm CI still works without `roles/container.developer`:
```sh
gh workflow run build-and-bump.yaml --repo huchka/feedforge --ref main
gh run watch --repo huchka/feedforge
```
**Check:**
- Workflow succeeds (build + push + tag-bump commit).
- Within ~3 min after tag-bump commit, Argo CD auto-syncs.
- `kubectl -n feedforge get pods` shows new pod ages on backend/frontend/summarizer with the new SHA.
- `kubectl -n argocd get application feedforge-dev` says `Synced / Healthy`.

### 6. Close out #32
```sh
gh issue close 32 --repo huchka/feedforge --comment "GitOps migration complete across PRs #43 (Phase 1: Argo CD install), #47 (Phase 2: Application CRD), #48 (Phase 3: build-and-bump + auto-sync), and this PR (Phase 4: SA IAM narrowed). End-to-end: CI builds + pushes images + commits tag → Argo CD auto-syncs → only the changed Deployments roll. SA now has only roles/artifactregistry.writer."
```

### 7. PR + merge
PR body links #32, summarizes the end-to-end verification.

## Risks / Rollback

| Risk | Likelihood | Impact | Mitigation / rollback |
|---|---|---|---|
| Some unnoticed CI step still calls `kubectl` and fails after narrow | Low | Medium | Step 5 catches this. Rollback: revert the terraform change, `terraform apply` the binding back. SA regains `container.developer` in seconds. |
| `kubectl apply` of the Application surprises me (e.g. Argo refuses the new spec) | Very Low | Low | Spec is plain Kubernetes API; if apply rejects, the live Application is unchanged. Investigate the error. |
| Auto-sync triggers an unexpected mass change after step 2 | Low | Low | The git state at HEAD (`73eceb2`) is already what Argo last reconciled to (manually) on May 3. Drift since then = whatever skaffold tried (and failed) to do, plus any direct cluster edits. `selfHeal` reverts those. We've already accepted this. |
| `errored.tfstate` in `terraform/environments/dev/` — leftover from a past failed apply | Already present | None | Not relevant to this change. Worth cleaning up separately (`rm` after confirming there's no drift, or ignore). |

**Rollback procedure:** if step 5 reveals a regression, edit the locals list back to two roles, `terraform plan -out=rollback.tfplan && terraform apply rollback.tfplan`. The IAM binding returns. CI works as before. ~10s of "broken state" between detecting the issue and re-applying.

## Out of scope (deferred)

- Argo CD self-management of `Application` CRDs (App-of-Apps pattern) → post-prod.
- Webhook-triggered sync → needs Argo CD Ingress, post-prod.
- Investigating the still-running `argocd-applicationset-controller` (Phase 1's `applicationSet.enabled: false` didn't take) → orthogonal, separate task.
- GC of the 3 failed digest CronJob runs (`daily-digest-29627970`, etc.) → separate triage. The CronJob's `failedJobsHistoryLimit` will eventually clean them up.
- Cleanup of `terraform/environments/dev/errored.tfstate` → unrelated leftover.
