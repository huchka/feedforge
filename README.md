# FeedForge 🔥📰

A self-hosted RSS feed aggregator with AI-powered summarization, running on GKE.

## What it does

- Fetches RSS/Atom feeds on a configurable schedule
- Summarizes articles using LLM APIs (OpenAI / Anthropic)
- Auto-tags articles based on content
- Provides a searchable web UI with favorites and filters
- Sends daily digest notifications to LINE / Slack

## Architecture

```
[RSS Sources] → (CronJob: Fetcher) → [Redis] → (Worker: Summarizer) → [PostgreSQL]
                                                                             ↑
[Browser] → (Ingress) → [Frontend] → [Backend API] ────────────────────────┘

(CronJob: Digest) → reads [PostgreSQL] → sends to [LINE/Slack]
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Infrastructure | GCP, Terraform, GKE Standard |
| CI/CD | GitHub Actions, Artifact Registry |
| Backend | Python, FastAPI, SQLAlchemy, Alembic |
| Frontend | React, Vite, TypeScript |
| Database | PostgreSQL 16 |
| Queue | Redis 7 |
| AI | OpenAI / Anthropic API |
| K8s tooling | kustomize, skaffold |

## Project Goals

This project is primarily a **Kubernetes learning vehicle**. It covers:

Deployment, StatefulSet, CronJob, Job, DaemonSet, Ingress, HPA, Init containers, Sidecars, NetworkPolicy, RBAC, Workload Identity, SecurityContext, PVC, ConfigMap, Secrets, ResourceQuota, PodDisruptionBudget, and more.

## Getting Started

For local development (host-direct or kind cluster), see [docs/local-development.md](./docs/local-development.md).

For project context and phase breakdown, see [CLAUDE.md](./CLAUDE.md).

## Deploying to a Fresh Environment

End-to-end flow for standing up FeedForge on a new GCP project (or after a teardown).

### Prerequisites

- `gcloud`, `terraform`, `kubectl`, `skaffold`, `docker`, `kustomize`
- A GCP project with billing enabled
- A GCS bucket for Terraform state (name matches `terraform/environments/dev/backend.tf`)

### 1. Configure variables

Copy the example tfvars and fill in your project:

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edit: project_id, region, zone, allowed_ips, db_password
```

### 2. Authenticate

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project <PROJECT_ID>
```

### 3. Provision infrastructure

```bash
cd terraform/environments/dev
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Provisions: VPC, GKE (zonal, Standard), Cloud SQL (Postgres 16), Artifact Registry, IAM (Workload Identity for workloads + GitHub Actions WIF pool/provider), Secret Manager secret containers. Takes ~15–20 min.

After `terraform apply`, wire the WIF outputs into GitHub (Settings → Secrets and variables → Actions → Variables):

```bash
terraform output -raw github_actions_project_id                  # → GCP_PROJECT_ID
terraform output -raw github_actions_workload_identity_provider  # → GCP_WIF_PROVIDER
terraform output -raw github_actions_service_account_email       # → GCP_SA_EMAIL
```

> **Cloud Armor:** `SECURITY_POLICY_RULES` quota is 0 on new projects. The module is commented out in `main.tf` by default. Re-enable after requesting a quota increase, and restore `gateway/backend-policy.yaml` in `k8s/base/kustomization.yaml`.

### 4. Connect kubectl

```bash
gcloud container clusters get-credentials feedforge-dev \
  --zone <ZONE> --project <PROJECT_ID>

kubectl config set-context --current --namespace=feedforge
```

### 5. Bootstrap cluster resources

One-time setup before the app deploys.

**Install the Secrets Store CSI Driver + GCP provider:**

```bash
k8s/bootstrap/install-csi-secrets-store.sh
```

See [docs/secret-manager.md](docs/secret-manager.md) for Secret Manager provisioning details (populating secret values in GCP, IAM roles, kustomize overlay setup).

**Cross-namespace RBAC** (prometheus-adapter needs to read `extension-apiserver-authentication` in `kube-system`):

```bash
kubectl apply -f k8s/bootstrap/prometheus-adapter-auth-reader.yaml
```

### 6. First deploy (build + push + apply)

Use skaffold — it builds, pushes to Artifact Registry, and applies the overlay:

```bash
cd <repo root>
skaffold run
```

Verify:

```bash
kubectl get pods,hpa,gateway,httproute
kubectl get gateway feedforge-gateway -o jsonpath='{.status.addresses[0].value}'
```

### Teardown

```bash
cd terraform/environments/dev
terraform destroy
```

Cloud SQL has deletion protection — disable in the module first if this fails.

## Cost

Designed to run within GCP's $300 free trial credit (~$40-50/month with cost-conscious configuration).
