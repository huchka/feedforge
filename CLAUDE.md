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

This project follows a structured SDLC. All tracking lives on GitHub.

### Workflow Steps
1. **Requirements** — Define the feature/task with clear acceptance criteria before any design work.
2. **Design** — Write a design doc on the GitHub Wiki. Link it from the issue. For small tasks, inline in the issue is fine.
3. **Design review** — Self-review the design (re-read next day for non-trivial work). Update wiki page with decision.
4. **Task breakdown** — Create GitHub issues with acceptance criteria, labels, and wiki link. Break into sub-tasks if needed (use task lists in the parent issue).
5. **Implementation** — Feature branch per issue. Write tests alongside code. Branch naming: `feat/xxx`, `infra/xxx`, `fix/xxx`.
6. **PR** — Use the PR template. Reference issue with `Closes #N`. Self-review the diff before requesting merge.
7. **Merge & deploy** — Merge to main. Deploy with `skaffold run`. Verify in target environment.
8. **Verify** — Confirm acceptance criteria pass in the deployed environment.

### GitHub Structure
- **Project board**: "FeedForge" GitHub Project — columns: Backlog → Ready for Dev → In Progress → In Review → Done
- **Labels**: `type:` (feature/bug/chore/docs), `priority:` (high/medium/low), `phase:` (design/ready), `size:` (S/M/L)
- **Milestones**: group issues into logical releases or phases
- **Wiki**: design docs, one page per feature/epic
- **Issue templates**: feature, bug, chore — in `.github/ISSUE_TEMPLATE/`
- **PR template**: in `.github/PULL_REQUEST_TEMPLATE.md`

### Process Rules for Claude
- NEVER create an issue without acceptance criteria.
- ALWAYS apply appropriate `type:`, `priority:`, and `size:` labels when creating issues.
- ALWAYS link PRs to issues with `Closes #N`.
- When starting a new feature: check if a design doc exists on the wiki. If not, draft one first.
- When creating issues from a design: label them `phase:ready` only after design is reviewed.
- New issues start as `phase:design` unless the task is straightforward (bug fix, small chore).

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
