# Plan: CI swap + auto-sync (Phase 3 of #32)

## Goal

CI no longer touches the cluster. On push to main: build + push images to Artifact Registry, then commit the new image tag to `k8s/overlays/dev/kustomization.yaml`. Argo CD picks up the commit (poll-based, ~3 min) and auto-syncs to the cluster (`prune + selfHeal`).

End state: zero `kubectl` calls from CI, no `roles/container.developer` needed on the GitHub Actions SA, drift between cluster and git becomes self-correcting, the Service/backend & Service/frontend OutOfSync condition we currently see gets cleaned up automatically.

## Context

- Issue: [#32](https://github.com/huchka/feedforge/issues/32). Phase 2 PR #47 merged.
- Phase 2 surfaced two real failures that this phase fixes:
  1. **Image tag mismatch**: `dev/kustomization.yaml` had a 7-char short SHA that was never built; CI uses 40-char SHAs. Manual sync caused `ImagePullBackOff` until we hand-pinned to a real tag.
  2. **CI now fails on every push to main**: skaffold's `kubectl apply` tries to remove Argo CD's adopted-instance label from cluster-scoped resources (ClusterRole/ClusterRoleBinding for prometheus-adapter, prometheus-server, kube-state-metrics) → 403 Forbidden because the GH Actions SA lacks `container.clusterRoles.update`.
- Phase 4 (later) narrows the SA further (drop `roles/container.developer` once Argo CD owns deploys).
- Branch: `infra/32-argocd-phase3-ci-swap`.

## Decisions (recommendations — surface for approval before coding)

### D1 — Image tag commit mechanism: in-line in build workflow
The build workflow runs `kustomize edit set image` then `git commit && git push` to main with `GITHUB_TOKEN`. Loop prevented by `[skip ci]` in the commit message.

- **Pro:** zero new components, single workflow file owns the whole flow, easy to reason about.
- **Con:** the workflow needs `contents: write`. Bot commits show as `github-actions[bot]`. If main becomes branch-protected later, requires bypass policy.

**Alternatives rejected:**
- *Argo CD Image Updater*: extra controller, watches registry, writes back to git. Powerful (per-image semver/regex policies) but overkill for a learning project running one tag-per-commit scheme.
- *Separate config repo*: best practice for multi-team / multi-env scale. For a single-repo single-env setup, splits the SDLC for no benefit.
- *PR-from-CI with auto-merge*: extra round-trip + extra CI run per push. Cleaner audit log, but slow.

### D2 — Build mechanism: keep skaffold for build, drop it for deploy
`skaffold build --push --tag=${{ github.sha }}` reuses the existing `skaffold.yaml` build config (backend + frontend artifacts). Only the deploy step goes away.

- **Pro:** no duplication of Dockerfile paths / image names. Skaffold is still the right tool for local `skaffold dev`.
- **Con:** keeps skaffold as a CI dependency. Acceptable.

**Alternative rejected:** bare `docker build && docker push` per image — more code, splits the source-of-truth for image build config.

### D3 — Sync policy on the Application
```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - PruneLast=true
```

- `prune: true` — resources removed from git get deleted from cluster.
- `selfHeal: true` — manual cluster edits get reverted within ~3 min.
- `PruneLast=true` — pruning happens after all sync waves; reduces accidental disruption when a resource is renamed (the new one comes up before the old one goes).

### D4 — Sync trigger: polling, not webhook
Argo CD's default 3-minute reconciliation interval. Webhook (sub-second) requires inbound HTTPS to argocd-server, which means an Ingress + TLS cert — out of scope for v1 (Argo CD is port-forward-only today).

- **Pro:** zero infra changes.
- **Con:** up to 3 min between commit and rollout in dev. Fine for learning-project velocity.

### D5 — Tag scope
Only `feedforge/backend` and `feedforge/frontend` get bumped (the two `images:` entries that exist today). Summarizer reuses the backend image transitively — covered.

### D6 — Workflow file naming
Replace `.github/workflows/deploy.yaml` (delete) with `.github/workflows/build-and-bump.yaml` (new). Keeping the old name with new content would obscure the diff.

### D7 — Race conditions
If two PRs merge in quick succession:
1. Build A starts, finishes, commits tag bump → push to main.
2. Build B starts (older code), finishes, tries to push tag bump → push rejected (non-fast-forward).

Mitigation: `git pull --rebase origin main` before push, with one retry on rejection. If still rejected after retry, fail the workflow loud — operator pushes again or re-runs CI. Cheap to recover.

The `concurrency` group from the old `deploy.yaml` is preserved (`group: deploy-main`, `cancel-in-progress: false`) to serialize builds and reduce the race window.

## Files

| Change | Path | Notes |
|---|---|---|
| Add | `.github/workflows/build-and-bump.yaml` | New workflow: build + push + tag-bump commit. |
| Delete | `.github/workflows/deploy.yaml` | Old skaffold-deploy workflow. |
| Modify | `k8s/argocd/applications/feedforge-dev.yaml` | Add `syncPolicy.automated + syncOptions`. |

No terraform changes (Phase 4 narrows SA IAM separately).

## New workflow sketch (`.github/workflows/build-and-bump.yaml`)

```yaml
name: build-and-bump

on:
  push:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: build-and-bump-main
  cancel-in-progress: false

jobs:
  build-and-bump:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    permissions:
      id-token: write    # WIF
      contents: write    # commit tag bump back to main
    env:
      SKAFFOLD_VERSION: v2.13.2
      OVERLAY_PATH: k8s/overlays/dev
      BACKEND_IMAGE:  us-central1-docker.pkg.dev/project-76da2d1f-231c-4c94-ae9/feedforge/backend
      FRONTEND_IMAGE: us-central1-docker.pkg.dev/project-76da2d1f-231c-4c94-ae9/feedforge/frontend
    steps:
      - uses: actions/checkout@v4
        with:
          # We push back; need the full ref + a token that can push.
          token: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/setup-buildx-action@v3

      - name: Auth GCP (WIF)
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ vars.GCP_WIF_PROVIDER }}
          service_account: ${{ vars.GCP_SA_EMAIL }}
          token_format: access_token

      - name: gcloud + AR docker auth
        uses: google-github-actions/setup-gcloud@v2
        with:
          project_id: ${{ vars.GCP_PROJECT_ID }}
      - run: gcloud auth configure-docker us-central1-docker.pkg.dev --quiet

      - name: Install skaffold
        run: |
          curl -fsSLo skaffold "https://storage.googleapis.com/skaffold/releases/${SKAFFOLD_VERSION}/skaffold-linux-amd64"
          sudo install skaffold /usr/local/bin/

      - name: Build + push images
        run: skaffold build --push --tag=${{ github.sha }}

      - name: Bump image tags in dev overlay
        run: |
          cd "${OVERLAY_PATH}"
          kustomize edit set image \
            "${BACKEND_IMAGE}=${BACKEND_IMAGE}:${{ github.sha }}" \
            "${FRONTEND_IMAGE}=${FRONTEND_IMAGE}:${{ github.sha }}"

      - name: Commit + push tag bump
        run: |
          git config user.name  "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git add "${OVERLAY_PATH}/kustomization.yaml"
          if git diff --cached --quiet; then
            echo "No tag change — nothing to commit."
            exit 0
          fi
          git commit -m "chore(deploy): bump dev image tag to ${GITHUB_SHA::12} [skip ci]"
          for i in 1 2 3; do
            git pull --rebase origin main && git push && exit 0
            echo "push rejected, retrying ($i)…"
            sleep 5
          done
          exit 1
```

Notes:
- `kustomize` is preinstalled on `ubuntu-latest`. Pin if that changes.
- `[skip ci]` keeps the bot's own commit from re-triggering this workflow.
- The `concurrency` group serializes; the `for` retry handles the narrow race window when two builds finish near-simultaneously.

## Updated Application

```yaml
spec:
  # ... existing fields unchanged ...

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - PruneLast=true
```

## Steps

### 1. Branch + plan doc
- `git checkout -b infra/32-argocd-phase3-ci-swap`
- This file at `.plans/20260503-argocd-phase3-ci-swap.md`.

### 2. Write `.github/workflows/build-and-bump.yaml`
- Per the sketch above.
- **Check:** `actionlint` passes (or eyeball; project doesn't currently lint workflows).

### 3. Delete `.github/workflows/deploy.yaml`
- **Check:** `git status` shows the deletion.

### 4. Update Application spec
- Edit `k8s/argocd/applications/feedforge-dev.yaml` to add `syncPolicy` block.
- **Check:** `kubectl apply --dry-run=client -f` parses without error.

### 5. Local sanity
- `kubectl kustomize k8s/overlays/dev` still renders cleanly.
- **Check:** no diff vs the current rendered output (we're not changing manifests, just CI).

### 6. PR
- Push branch, open PR. Body links #32, recaps Phase 2's failures and how this fixes them.
- Auto-merge enabled — squash-merge once kustomize renders pass.

### 7. Post-merge — first build is the test
The merge of this PR triggers `build-and-bump.yaml`:
1. Builds backend + frontend with tag = merge SHA.
2. Pushes to AR.
3. Commits `dev/kustomization.yaml` bump → push to main with `[skip ci]`.
4. Within ~3 min, Argo CD polls, detects new commit, auto-syncs.

**Check (≤ 5 min after merge):**
```sh
kubectl -n argocd get application feedforge-dev
# SYNC STATUS=Synced, HEALTH STATUS=Healthy
```
Pods should roll once with the new SHA and stay there.

### 8. Apply Application change to live cluster
After merge, the Application YAML in git has `syncPolicy`. Argo CD doesn't self-manage the Application yet (deferred to post-prod), so user runs:
```sh
kubectl apply -f k8s/argocd/applications/feedforge-dev.yaml
```
This flips the live Application to auto-sync. **Check:** `kubectl -n argocd get application feedforge-dev -o jsonpath='{.spec.syncPolicy}'` returns the policy block.

### 9. Verify self-heal
Optional sanity test:
```sh
# Drift the cluster manually
kubectl -n feedforge scale deploy/backend --replicas=5
# Watch Argo revert it within ~3 min
kubectl -n feedforge get deploy backend -w
```

## Risks / Rollback

| Risk | Likelihood | Impact | Mitigation / rollback |
|---|---|---|---|
| First post-merge build commits a SHA that's also the merge SHA → confusing log | Certain (by design) | None | This is correct behavior. Document in PR body. |
| `git push` from CI rejected even after rebase retry (multi-merge collision) | Low | Low | Workflow fails loud; re-run CI manually or push another commit. |
| Auto-sync deletes a resource that exists in cluster but not in git | Low | Medium | `prune: true` is the explicit ask. Check current cluster vs git for orphan resources before merging. |
| `selfHeal` reverts an emergency manual `kubectl edit` during incident | Low | Medium | Document: in incidents, *disable* the Application sync first (`kubectl -n argocd patch app feedforge-dev --type=merge -p '{"spec":{"syncPolicy":{"automated":null}}}'`), then edit. Re-enable after. |
| `[skip ci]` filter doesn't cover all CI workflows → loop | Very Low | High | Both `ci.yaml` (PR-only) and `build-and-bump.yaml` (push-only) won't be triggered by a push commit with `[skip ci]`. GitHub Actions honors this on commit messages. Verified. |
| Bot push gets blocked by future branch protection | None today | Medium | Personal repo, no protection. Revisit when prod arrives. |

**Rollback:** revert this PR. `deploy.yaml` returns, `build-and-bump.yaml` goes away, Application loses `syncPolicy`. Then `kubectl apply -f k8s/argocd/applications/feedforge-dev.yaml` to flip Argo back to manual sync. Cluster state remains whatever Argo last applied.

## Out of scope (deferred)

- Narrowing the GH Actions SA IAM (`roles/container.developer` removal) → Phase 4.
- Argo CD self-management of `Application` CRDs (App-of-Apps) → post-prod.
- Webhook-triggered sync (sub-second instead of 3 min) → needs Argo CD Ingress, post-prod.
- Per-component Application split → only if UI granularity becomes a need.
- Investigating the still-running `argocd-applicationset-controller` despite Phase 1's disable → orthogonal, separate task.
