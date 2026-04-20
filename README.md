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
| CI/CD | Cloud Build, Artifact Registry, Cloud Deploy |
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

See [CLAUDE.md](./CLAUDE.md) for the full development plan and phase breakdown.

## Bootstrap (Fresh Cluster)

After provisioning infrastructure with Terraform and connecting kubectl:

```bash
# 1. Install the Secrets Store CSI Driver + GCP provider
k8s/bootstrap/install-csi-secrets-store.sh

# 2. Cross-namespace RBAC for prometheus-adapter
kubectl apply -f k8s/bootstrap/prometheus-adapter-auth-reader.yaml

# 3. Deploy with skaffold
skaffold run
```

See [docs/secret-manager.md](docs/secret-manager.md) for Secret Manager provisioning details.

## Cost

Designed to run within GCP's $300 free trial credit (~$40-50/month with cost-conscious configuration).
