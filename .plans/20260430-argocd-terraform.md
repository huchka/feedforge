# Plan: Argo CD install via Terraform (Phase 1 of #32)

## Goal

Argo CD is running in the dev GKE cluster, installed via a new `terraform/modules/argocd/` module using the official Argo CD Helm chart. UI reachable via port-forward. No workloads under Argo CD's control yet — that's Phase 2.

## Context

- Issue: [#32](https://github.com/huchka/feedforge/issues/32) (size:L). Wiki design: `Migrate-Deploy-to-Argo-CD` (Draft).
- This is **Phase 1 of 4**. Phases 2–4 land later as separate PRs (Application CRD, CI workflow swap, IAM narrowing + cleanup).
- Existing terraform: root module in `terraform/environments/dev/`, sub-modules in `terraform/modules/<name>/`. Only the `google` provider is configured today (`~> 7.24`).
- GKE cluster `feedforge-cluster` (us-central1-f, Standard, e2-medium × 2, autoscaler 1–3) is already provisioned. Module `gke` already outputs `cluster_endpoint`, `cluster_ca_certificate`, `cluster_location`.
- Decisions confirmed in chat:
  1. Use the `helm` provider + official `argo/argo-cd` chart.
  2. Module manages **install only**. Application CRDs (Phase 2) will live as YAML in `k8s/argocd/applications/` and be applied with `kubectl`.
  3. Disable `dex`, `notifications-controller`, `applicationset-controller` for v1 to save ~150Mi (`e2-medium × 2` headroom is tight).
  4. Branch: `infra/32-argocd-terraform`.

## Approach

### New module: `terraform/modules/argocd/`

Files (per the project's TF rules):

- `versions.tf` — pin `terraform >= 1.5.0`, `helm ~> 2.16`, `kubernetes ~> 2.34`.
- `variables.tf` — `chart_version` (string), `namespace` (default `"argocd"`), `release_name` (default `"argocd"`).
- `main.tf` — `kubernetes_namespace.argocd` + `helm_release.argocd` with values disabling the three components above.
- `outputs.tf` — `namespace`, `release_name`, `chart_version`. Useful for Phase 2 dependency. (`chart_version` chosen over `release_status` for visibility — release status can be queried from the helm provider state.)

The module does not declare provider blocks — providers come from the root module per the project's TF rules.

### Helm release options

`helm_release` is configured with `wait = true` and `timeout = 600` (10 minutes) so terraform waits until all chart resources reach Ready before returning. Apply takes ~2–4 minutes typically; the longer timeout is a safety margin for slow image pulls on a cold cluster.

### Helm chart values (inline in `helm_release.values`)

```yaml
dex:
  enabled: false
notifications:
  enabled: false
applicationSet:
  enabled: false
```

Everything else uses chart defaults. Resource requests/limits are not overridden in v1 — chart defaults are sane (server: 256Mi, repo-server: 256Mi, application-controller: 1Gi). If we run out of headroom on the `e2-medium × 2` cluster, follow up with explicit `resources:` overrides.

### Provider wiring in `terraform/environments/dev/`

Two new files / changes:

**`versions.tf`** — add `helm` and `kubernetes` providers alongside `google`:

```hcl
helm = {
  source  = "hashicorp/helm"
  version = "~> 2.16"
}
kubernetes = {
  source  = "hashicorp/kubernetes"
  version = "~> 2.34"
}
```

**`main.tf`** — add provider config + module call:

```hcl
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${module.gke.cluster_endpoint}"
  cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
}

provider "helm" {
  kubernetes {
    host                   = "https://${module.gke.cluster_endpoint}"
    cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
    token                  = data.google_client_config.default.access_token
  }
}

module "argocd" {
  source        = "../../modules/argocd"
  chart_version = "7.7.7"
  depends_on    = [module.gke]
}
```

Pin chart `7.7.7` (latest as of this plan; bump explicitly later). This chart version installs Argo CD `~v2.13.x`.

### Cluster credentials

`provider "kubernetes"` uses `data.google_client_config.default` for short-lived OAuth2 tokens. This works because:

- The user runs `terraform apply` from a machine that's authenticated to GCP (`gcloud auth application-default login` already done, per CLAUDE.md).
- The token is bound to the same identity that runs `terraform apply` — no extra service account or kubeconfig juggling.
- Tokens expire in ~1h; that's fine for an apply that takes minutes.

Tradeoff: the user's gcloud identity needs `roles/container.developer` (or wider) on the cluster for terraform to talk to the K8s API. That's already granted to the user (they manage the cluster).

## Steps

Each step has a verification check.

### 1. Branch + plan doc + wiki update (no terraform yet)

- `git checkout -b infra/32-argocd-terraform`
- Plan doc lands at `.plans/20260430-argocd-terraform.md` (this file).
- Wiki doc updated locally to reflect terraform install (Install section, Phased rollout table, Alternatives table). Not pushed yet.
- **Check:** `git status` shows the plan doc + wiki working-copy changes (in `/tmp/feedforge-wiki-check/`, separate repo).

### 2. Write `terraform/modules/argocd/`

- `versions.tf`, `variables.tf`, `main.tf`, `outputs.tf` per the structure above.
- Inline values block with the three disabled components.
- **Check:** Files exist, follow project TF rules (pinned `~>` versions, typed/described variables, described outputs).

### 3. Wire providers and module call in `terraform/environments/dev/`

- Add `helm` + `kubernetes` to `versions.tf`.
- Add `data "google_client_config"` + provider blocks + `module "argocd"` to `main.tf`.
- **Check:** `terraform fmt -recursive` shows no diff after first run.

### 4. `terraform fmt -recursive`

- **Check:** No diff.

### 5. Hand off — user runs init/validate/plan

User executes (in `terraform/environments/dev/`):

```sh
terraform init -upgrade    # pulls helm + kubernetes providers
terraform validate
terraform plan -out=argocd.tfplan
```

Paste the plan output back. **Check:** plan creates exactly:
- 1 × `kubernetes_namespace.argocd`
- 1 × `helm_release.argocd`
- (no other changes)

If the plan shows unrelated changes, stop and investigate before applying.

### 6. User runs `terraform apply argocd.tfplan`

- **Check:** Apply succeeds. Helm release transitions to `Deployed`. Apply duration: ~2–4 minutes (chart pulls + pod start).

### 7. Verify Argo CD is healthy

```sh
kubectl -n argocd get pods
```

**Check:** All pods Ready. Expected pods (with dex/notifications/applicationset disabled):
- `argocd-application-controller-0`
- `argocd-redis-*`
- `argocd-repo-server-*`
- `argocd-server-*`

### 8. Retrieve initial admin password and access UI

```sh
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d ; echo

kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Browse to https://localhost:8080, log in as `admin` with that password. **Check:** UI loads. No Applications listed (expected — Phase 2 adds the first one).

### 9. Open PR

- Push `infra/32-argocd-terraform`.
- PR body references #32 and links the wiki design.
- Move issue to "In Review" on the project board (per CLAUDE.md SDLC rules).

### 10. After PR merges — push wiki draft

The wiki page goes from Draft → Approved once the PR lands and end-to-end works.

## Risks / Rollback

| Risk | Likelihood | Impact | Mitigation / rollback |
|---|---|---|---|
| Cluster headroom: Argo CD pushes `e2-medium × 2` over capacity, autoscaler bumps to 3 nodes (~$0.30/day extra) | Medium | Low (cost) | Disabled 3 components saves ~150Mi. Watch `kubectl top nodes` post-apply. If tight, add explicit `resources:` overrides in a follow-up. |
| Helm chart version `7.7.7` ships Argo CD with a breaking config change vs docs | Low | Medium | Pinned version. If install fails, `terraform destroy -target=module.argocd` (clean — only namespace + release) and pin lower. |
| `provider "kubernetes"` can't authenticate (token expired, wrong identity) | Low | Low | User's gcloud identity is already trusted by the cluster. If it fails, `gcloud auth application-default login` and re-plan. |
| Applying Argo CD inadvertently disrupts existing workloads | Very Low | High | Argo CD is in its own namespace `argocd` with no selectors over `feedforge` namespace. The Helm release only creates resources in `argocd`. Existing workloads are not touched. |
| Helm release state drifts from terraform state (e.g., user runs `helm upgrade` manually) | Low | Low | Don't run `helm` directly against this release. All upgrades via `terraform apply`. Document in module README. |

**Rollback procedure:**

```sh
# In terraform/environments/dev/
terraform destroy -target=module.argocd
```

This removes the `helm_release` (uninstalls Argo CD) and the `kubernetes_namespace.argocd`. All Argo CD resources are confined to that namespace, so destroy is clean.

If destroy fails because of stuck finalizers (Argo CD CRDs sometimes do this):

```sh
kubectl -n argocd delete applications.argoproj.io --all --wait=false
kubectl -n argocd patch applications.argoproj.io --all \
  --type=json -p='[{"op":"remove","path":"/metadata/finalizers"}]'
```

Then re-run `terraform destroy`.

## Out of scope (deferred to later phases)

- Application CRDs / actual workload deploys → Phase 2.
- New CI workflow that commits image tags → Phase 3.
- Removing `roles/container.developer` from `module.github_actions` → Phase 4.
- Argo CD Ingress / SSO / public exposure → not planned for v1.
- Argo CD self-management (Argo-managing-Argo) → deferred; revisit when prod arrives.
