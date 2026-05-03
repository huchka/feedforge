# Argo CD Applications

`Application` CRDs that tell Argo CD what to reconcile.

## Why this directory is outside `k8s/base` and `k8s/overlays`

These manifests are **not** part of any kustomization. They live in the
`argocd` namespace, not `feedforge`, and are applied directly with `kubectl`.
Folding them into a kustomize tree would mix two concerns (the workloads and
the controller that reconciles them) and complicate the bootstrap.

Self-management (Argo CD reconciling its own `Application` definitions —
"App-of-Apps") is deferred until prod ([#19](https://github.com/huchka/feedforge/issues/19)) lands.

## Applying

```sh
kubectl apply -f k8s/argocd/applications/feedforge-dev.yaml
```

Verify:

```sh
kubectl -n argocd get applications
```

## Sync policy

Manual today. Auto-sync (with `prune` and `selfHeal`) is added in Phase 3 of
[#32](https://github.com/huchka/feedforge/issues/32), in the same PR that
removes `.github/workflows/deploy.yaml`. Enabling auto-sync before that PR
would race the skaffold-from-CI deploy.

## Removing

`resources-finalizer.argocd.argoproj.io` cascades — deleting the Application
deletes the workloads it created. To delete the Application without
cascading:

```sh
kubectl -n argocd patch application feedforge-dev \
  --type=json -p='[{"op":"remove","path":"/metadata/finalizers"}]'
kubectl -n argocd delete application feedforge-dev
```
