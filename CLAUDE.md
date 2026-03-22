# FeedForge — Claude Instructions

RSS feed aggregator with AI summarization on GKE. See README.md for project overview.

## Key Infrastructure Decisions

| Choice | Value | Why |
|--------|-------|-----|
| GKE mode | Standard (not Autopilot) | Learning node management, scheduling |
| Cluster | Zonal (asia-northeast1-a) | Free tier covers management fee |
| Nodes | e2-medium (2 vCPU, 4GB), 2 nodes (autoscaler 1-3) | Balance cost vs capacity |
| Registry | Artifact Registry (asia-northeast1) | Regional = cheaper egress |
| CI | Cloud Build | 120 free build-min/day |
| IaC | Terraform with modules, GCS remote state | Learning goal |
| K8s config | kustomize (base + overlays) | Environment management |

## Workflow Rules

### Git
- Branch: `main` + feature branches (`feat/xxx`, `infra/xxx`, `fix/xxx`)
- Conventional commits: `feat:`, `fix:`, `infra:`, `docs:`, `chore:`

### Terraform
- ALWAYS `terraform plan` before `apply`. Review the plan output.
- NEVER `terraform destroy` without confirming with user.
- Pin provider versions in `versions.tf`.
- Sensitive values in `terraform.tfvars` (gitignored).
- Format with `terraform fmt` before commit.

### Kubernetes
- `kubectl diff` before `kubectl apply` for manual deploys.
- NEVER `kubectl edit` — always change manifests and re-apply.
- NEVER `kubectl delete namespace` on production.
- Label everything: `app.kubernetes.io/name`, `app.kubernetes.io/component`, `app.kubernetes.io/part-of: feedforge`.

### Docker
- Multi-stage builds to minimize image size.
- Pin base image versions (e.g., `python:3.12-slim`, not `python:latest`).
- Non-root user in all Dockerfiles.

### Cost Management
- Monthly target: ~$50 USD. $300 credit / 88 days ≈ $3.40/day.
- Before ending session: remind user to `terraform destroy` if cluster is up.
- If budget is tight: scale to 1 node or switch to e2-small.
