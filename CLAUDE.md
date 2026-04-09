# FeedForge — Claude Instructions

RSS feed aggregator with AI summarization on GKE. See README.md for project overview.

## Key Infrastructure Decisions

| Choice | Value | Why |
|--------|-------|-----|
| GKE mode | Standard (not Autopilot) | Learning node management, scheduling |
| Cluster | Zonal (us-central1-f) | Free tier covers management fee |
| Nodes | e2-medium (2 vCPU, 4GB), 2 nodes (autoscaler 1-3) | Balance cost vs capacity |
| Registry | Artifact Registry (us-central1) | Regional = cheaper egress |
| TF state bucket | GCS (asia-northeast1) | Created before region change, left as-is |
| Database | Cloud SQL (Postgres 16, db-f1-micro) | Managed backups, patching, HA |
| DB connectivity | Cloud SQL Auth Proxy sidecar | Workload Identity, no keys |
| CI | Cloud Build | 120 free build-min/day |
| IaC | Terraform with modules, GCS remote state | Learning goal |
| K8s config | kustomize (base + overlays) | Environment management |

## Development Process

This project follows a structured SDLC. See [CONTRIBUTING.md](CONTRIBUTING.md) for the full workflow, labels, board columns, and branch naming conventions.

### Process Rules for Claude
- Follow the workflow defined in CONTRIBUTING.md.
- NEVER create an issue without acceptance criteria.
- ALWAYS apply appropriate `type:`, `priority:`, and `size:` labels when creating issues.
- ALWAYS link PRs to issues with `Closes #N`.
- When starting a new feature: check if a design doc exists on the wiki. If not, draft one first.
- When creating issues from a design: label them `phase:ready` only after design is reviewed.
- New issues start as `phase:design` unless the task is straightforward (bug fix, small chore).
- When starting work on an issue: move it to "In Progress" on the project board.
- When opening a PR: move the issue to "In Review".
- When merged and verified: move the issue to "Done".

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
- NEVER run `kubectl` commands — the user runs all K8s commands themselves (learning project).
- Provide the commands to run, but don't execute them.
- NEVER `kubectl edit` — always change manifests and re-apply.
- **Deploy with `skaffold run`** — NEVER suggest `kubectl apply -k`. Skaffold handles image build, tagging, and deploy. Raw `kubectl apply -k` overwrites image tags with stale values from manifests.
- Label everything: `app.kubernetes.io/name`, `app.kubernetes.io/component`, `app.kubernetes.io/part-of: feedforge`.

### Docker
- Multi-stage builds to minimize image size.
- Pin base image versions (e.g., `python:3.12-slim`, not `python:latest`).
- Non-root user in all Dockerfiles.

### Cost Management
- Monthly target: ~$50 USD. $300 credit / 88 days ≈ $3.40/day.
- Before ending session: remind user to `terraform destroy` if cluster is up.
- If budget is tight: scale to 1 node or switch to e2-small.
