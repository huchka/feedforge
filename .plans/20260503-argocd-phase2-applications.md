# Plan: Argo CD Application for dev (Phase 2 of #32)

## Goal

A single Argo CD `Application` named `feedforge-dev` reconciles `k8s/overlays/dev` to the cluster, with **manual** sync. Skaffold-from-CI keeps deploying for now (Phase 3 swaps it). UI shows the Application; one manual `Sync` click rolls the workloads from git.

## Context

- Issue: [#32](https://github.com/huchka/feedforge/issues/32). Wiki design: `Migrate-Deploy-to-Argo-CD` (Approved after Phase 1 merge).
- This is **Phase 2 of 4**. Phases 3–4 land later as separate PRs.
- Phase 1 (PR #43, commit 90d9ebf) installed Argo CD via terraform into the `argocd` namespace.
- Branch: `infra/32-argocd-phase2-applications`.

## Decisions (recommendations — surface for approval before coding)

### D1 — One Application, not many
Single `Application` pointing at `k8s/overlays/dev`. Per-component split is a future refinement, not a v1 requirement.

- **Pro:** matches today's deploy unit (one `kustomize build` of the dev overlay), no manifest restructuring, the "no full-cluster restart" win is preserved by Argo CD's per-resource diff (it only rolls Deployments whose spec changed).
- **Con:** coarser status in the Argo CD UI (`feedforge-dev` is `Healthy` or not, not per-component). Acceptable for v1.

### D2 — Sync policy: **manual** in Phase 2
`syncPolicy` is omitted (Argo CD default = manual). Phase 3 adds `automated.prune + automated.selfHeal` in the same PR that removes `deploy.yaml`.

- **Why manual:** if we enable auto-sync now, Argo CD and the still-active `deploy.yaml` (skaffold) will fight on every push to main. Manual sync makes the GitOps flow visible without racing CI.
- The first manual sync is expected to roll most pods to `a42276a` (the tag committed in `k8s/overlays/dev/kustomization.yaml`). Document this — it's not a regression, it's the intended GitOps source-of-truth becoming authoritative for the first time.

### D3 — Project: `default`
Use the auto-created `default` `AppProject`. A custom `AppProject` (limiting source repos, dest namespaces, allowed kinds) is a Phase 4 hardening item.

### D4 — Source repo / revision
- `repoURL: https://github.com/huchka/feedforge.git`
- `targetRevision: HEAD` (tracks main)
- `path: k8s/overlays/dev`
- Argo CD's bundled kustomize handles the `components:` field natively (kustomize ≥ 3.7).

### D5 — Destination
- `server: https://kubernetes.default.svc` (in-cluster)
- `namespace: feedforge` (sets the *default* namespace for resources without one — most of our resources have explicit `metadata.namespace`)

### D6 — Application manifest location
`k8s/argocd/applications/feedforge-dev.yaml`. New top-level dir matches the Phase 1 plan ("Application CRDs … live as YAML in `k8s/argocd/applications/` and are applied with `kubectl`").

Add `k8s/argocd/applications/README.md` documenting:
- These Applications are NOT under any kustomization — they are applied directly with `kubectl apply -f`.
- Why they are not self-managed by Argo CD yet (Argo-managing-Argo deferred to post-prod).
- The namespace they target (`argocd`).

## Approach

### Files added

```
k8s/argocd/applications/feedforge-dev.yaml
k8s/argocd/applications/README.md
```

### `feedforge-dev.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: feedforge-dev
  namespace: argocd
  labels:
    app.kubernetes.io/name: feedforge-dev
    app.kubernetes.io/part-of: feedforge
  finalizers:
    # Cascading delete: removing this Application also removes the workloads
    # it created. Without this, a `kubectl delete app feedforge-dev` orphans
    # the Deployments. Phase 3/4 will revisit if we add prod.
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default

  source:
    repoURL: https://github.com/huchka/feedforge.git
    targetRevision: HEAD
    path: k8s/overlays/dev
    # No `kustomize:` block — let Argo CD use the overlay's own kustomization
    # as-is. Image tag overrides stay in k8s/overlays/dev/kustomization.yaml
    # (Phase 3 will automate the bump-and-commit there).

  destination:
    server: https://kubernetes.default.svc
    namespace: feedforge

  # syncPolicy intentionally omitted — manual sync only in Phase 2.
  # Phase 3 will add:
  #   syncPolicy:
  #     automated:
  #       prune: true
  #       selfHeal: true
  #     syncOptions:
  #       - PruneLast=true

  # Tolerate small revision-history noise without flagging Healthy=false.
  revisionHistoryLimit: 10
```

### `README.md` (k8s/argocd/applications/)

Short — documents:
1. What lives here and why it's outside the main kustomize tree.
2. How to apply: `kubectl apply -f k8s/argocd/applications/feedforge-dev.yaml`.
3. Why sync is manual today (link to Phase 3 issue/plan).

## Steps

Each step has a verification check. I (Claude) write files; the user runs the kubectl + verification commands per CLAUDE.md.

### 1. Branch + plan doc
- `git checkout -b infra/32-argocd-phase2-applications`
- Plan doc at `.plans/20260503-argocd-phase2-applications.md` (this file).
- **Check:** `git status` shows the plan doc.

### 2. Pre-flight: confirm Phase 1 cluster state
User runs:
```sh
kubectl -n argocd get pods
kubectl -n argocd get crd | grep argoproj
```
- **Check:** all argocd-* pods Ready; `applications.argoproj.io` CRD present.
- If not healthy, stop and fix Phase 1 before touching Phase 2.

### 3. Write `k8s/argocd/applications/feedforge-dev.yaml`
- Per the YAML above.
- **Check:** `kubectl apply --dry-run=client -f k8s/argocd/applications/feedforge-dev.yaml` (read-only, doesn't hit cluster) prints `application.argoproj.io/feedforge-dev created (dry run)`.

### 4. Write `k8s/argocd/applications/README.md`
- Short, ~30 lines.
- **Check:** file exists and renders in Markdown.

### 5. Local kustomize sanity check
User runs (read-only, local YAML):
```sh
kubectl kustomize k8s/overlays/dev > /tmp/feedforge-dev-rendered.yaml
```
- **Check:** rendered without error. This is what Argo CD will see.

### 6. User applies the Application
```sh
kubectl apply -f k8s/argocd/applications/feedforge-dev.yaml
kubectl -n argocd get applications
```
- **Check:** `feedforge-dev` appears. Initial `SYNC STATUS` is likely `OutOfSync` (cluster currently reflects whatever skaffold last applied with a SHA tag from CI; git has `a42276a`).

### 7. Inspect diff in Argo CD UI (do NOT sync yet)
User port-forwards (already in Phase 1 instructions):
```sh
kubectl -n argocd port-forward svc/argocd-server 8080:443
```
Open https://localhost:8080 → `feedforge-dev` → "App Diff".

- **Check:** diff matches expectation — primarily image tag differences (`a42276a` ← whatever CI last pushed). No surprise resources being created or deleted.
- If the diff shows **Deletions** (resources in the cluster but not in git), STOP. That means skaffold added something out-of-band, or our overlay is missing something. Investigate before syncing.

### 8. User clicks "Sync" in the UI (or runs CLI sync)
```sh
# CLI alternative if preferred:
# argocd app sync feedforge-dev --prune=false
```
- **Check:** sync completes, Application status → `Synced`, `Healthy`. Note: this WILL roll Deployments back to image tag `a42276a` if CI has pushed newer images. That's expected for Phase 2.

### 9. Verify only the drifted Deployments rolled
```sh
kubectl -n feedforge get pods -L pod-template-hash --sort-by=.metadata.creationTimestamp
```
- **Check:** pods that didn't change config retain their pre-sync age. Only the changed Deployments have new pods. (This is the win we wanted vs. skaffold's run-id label causing full restarts.)

### 10. Open PR
- Push `infra/32-argocd-phase2-applications`.
- PR body: links #32, summarizes manual-sync rationale, points at Phase 3 follow-up issue (creates one if it doesn't exist).
- Move #32 from "In Progress" → "In Review" on the project board.

### 11. After merge — leave it alone for ~24h
- Don't enable auto-sync.
- Watch for drift in the Argo CD UI when CI runs deploys. Drift = expected (skaffold still owns the cluster). The drift is the visual proof we need Phase 3.

## Risks / Rollback

| Risk | Likelihood | Impact | Mitigation / rollback |
|---|---|---|---|
| First manual sync rolls Deployments to stale `a42276a` tag | High (expected) | Low (dev only) | Documented above. If undesirable, update `k8s/overlays/dev/kustomization.yaml` to the latest tag *before* clicking sync. |
| Argo CD diff shows unexpected deletions | Low | Medium | Step 7 stops here. Investigate the source of out-of-band resources before syncing. |
| Auto-sync accidentally enabled | Low | Medium | Spec omits `syncPolicy`. Code review on the PR catches additions. |
| CRD `Application` not registered (Phase 1 install incomplete) | Very Low | Low | Step 2 catches it before write. |
| `cluster_endpoint` / RBAC mismatch — the user can't `kubectl apply` to argocd ns | Very Low | Low | The user already has cluster-admin equivalent for this cluster (managed Phase 1 install). |
| Argo CD sync triggers HPA flap on `backend` (HPA + replicas in spec = flap per k8s rules) | Low | Low | Existing Deployments already follow our k8s rules — the HPA owns replicas, Deployment doesn't set replicas. Verified during #28 split. |

**Rollback:**
```sh
kubectl delete -f k8s/argocd/applications/feedforge-dev.yaml
```
The `resources-finalizer.argocd.argoproj.io` finalizer **will** delete the workloads it created. To delete the Application without cascading:
```sh
kubectl -n argocd patch application feedforge-dev \
  --type=json -p='[{"op":"remove","path":"/metadata/finalizers"}]'
kubectl -n argocd delete application feedforge-dev
```

## Out of scope (deferred to later phases)

- Auto-sync, prune, self-heal → Phase 3 (with CI swap, in same PR).
- Removing `.github/workflows/deploy.yaml` → Phase 3.
- Image-tag-update commits from CI → Phase 3.
- Custom `AppProject` with source/destination/kind allowlists → Phase 4.
- Argo CD Ingress / SSO → not planned for v1.
- Argo CD self-management (Argo-managing-Argo) → revisit when prod arrives.
- Splitting `feedforge-dev` into per-component Applications → future, only if UI granularity is needed.
