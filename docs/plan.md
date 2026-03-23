# FeedForge Development Plan

## Application Components

| Component | Type | Tech | K8s Resource |
|-----------|------|------|-------------|
| Frontend | Web UI | React (Vite) | Deployment + Service |
| Backend API | REST API | Python FastAPI | Deployment + Service |
| Feed Fetcher | Scheduled worker | Python | CronJob |
| AI Summarizer | Background worker | Python | Deployment (long-running consumer) |
| Daily Digest | Notification sender | Python | CronJob |
| PostgreSQL | Database | PostgreSQL 16 | StatefulSet + PVC + headless Service |
| Redis | Message queue / cache | Redis 7 | Deployment + Service |

## Data Flow

```
[RSS Sources] → (CronJob: Fetcher) → [Redis Queue] → (Worker: Summarizer) → [PostgreSQL]
                                                                                    ↑
[User Browser] → (Ingress) → [Frontend] → [Backend API] ──────────────────────────┘

(CronJob: Digest) → reads [PostgreSQL] → sends to [LINE/Slack]
```

## K8s Concepts Coverage (Learning Tracker)

| Concept | Phase | Status |
|---------|-------|--------|
| Deployment | P1 | ☐ |
| StatefulSet | P1 | ☐ |
| Service (ClusterIP) | P1 | ☐ |
| Service (headless) | P1 | ☐ |
| ConfigMap | P1 | ☐ |
| Secret | P1 | ☐ |
| PersistentVolumeClaim | P1 | ☐ |
| Ingress | P3 | ☐ |
| CronJob | P2 | ☐ |
| Job | P2 | ☐ |
| HPA | P4 | ☐ |
| Init container | P1 | ☐ |
| Sidecar container | P4 | ☐ |
| NetworkPolicy | P4 | ☐ |
| RBAC / ServiceAccount | P4 | ☐ |
| Workload Identity | P4 | ☐ |
| SecurityContext | P4 | ☐ |
| ResourceQuota / LimitRange | P4 | ☐ |
| PodDisruptionBudget | P4 | ☐ |
| Resource requests/limits | P1 | ☐ |
| Liveness/readiness probes | P1 | ☐ |
| Rolling update strategy | P3 | ☐ |
| kustomize overlays | P3 | ☐ |

## Phase 0: GCP Foundation + GKE Cluster
**Goal**: GKE cluster running, nginx hello-world reachable from internet.
**Verification**: `curl <external-ip>` returns nginx welcome page.

- [x] Create GCP project, enable APIs (container, compute, artifactregistry, cloudbuild)
- [x] Create GCS bucket for Terraform state
- [x] Write Terraform: network module (VPC, subnet)
- [x] Write Terraform: gke module (cluster, node pool)
- [x] Write Terraform: artifact-registry module
- [x] Write Terraform: iam module (basic service accounts)
- [x] Write Terraform: dev environment (compose modules)
- [x] `terraform plan` → review → `terraform apply`
- [x] `gcloud container clusters get-credentials` → verify kubectl access
- [x] Deploy nginx pod + LoadBalancer Service manually
- [x] Verify external access
- [ ] `terraform destroy` (keeping cluster running, ~$2/day)

## Phase 1: Core Application (Backend + DB)
**Goal**: FastAPI backend + PostgreSQL running in cluster, CRUD for feeds and articles working.
**Verification**: `curl <cluster-ip>:8000/api/health` returns OK, can add feeds and list articles via API.

- [x] Write FastAPI app skeleton (health check, feed CRUD, article list)
- [x] Write SQLAlchemy models (Feed, Article)
- [x] Set up Alembic for DB migrations
- [x] Write Dockerfile for backend
- [x] Build and push image to Artifact Registry
- [x] Write K8s manifests: PostgreSQL StatefulSet + headless Service + PVC + Secret
- [x] Write K8s manifests: Backend Deployment + Service + ConfigMap
- [x] Use init container for DB migration
- [x] Set resource requests/limits on all pods
- [x] Add liveness/readiness probes to backend
- [x] Deploy and verify API works end-to-end

## Phase 2: Workers (Feed Fetcher + AI Summarizer)
**Goal**: Feeds are fetched on schedule, articles are summarized automatically.
**Verification**: Add a feed URL → wait for CronJob → articles appear with summaries.

- [ ] Write feed fetcher script (feedparser library, pushes to Redis queue)
- [ ] Write AI summarizer worker (consumes Redis queue, calls LLM API, writes to DB)
- [ ] Write Dockerfile for workers
- [ ] Deploy Redis (Deployment + Service)
- [ ] Write K8s CronJob manifest for feed fetcher
- [ ] Write K8s Deployment manifest for summarizer (long-running consumer)
- [ ] Write Secrets for LLM API keys
- [ ] Deploy and verify: add feed → CronJob fires → articles fetched → summarized

## Phase 3: Frontend + Ingress + CI/CD
**Goal**: Full web UI accessible via Ingress, CI/CD pipeline auto-deploys on push.
**Verification**: Push to main → Cloud Build triggers → new image deployed → visible in browser.

- [ ] Build React frontend (article list, feed management, search, favorites)
- [ ] Write Dockerfile for frontend (nginx + static build)
- [ ] Write K8s manifests: Frontend Deployment + Service
- [ ] Configure Ingress (path-based: / → frontend, /api → backend)
- [ ] Set up kustomize overlays for dev
- [ ] Write cloudbuild.yaml (build all images → push → deploy)
- [ ] Set up Cloud Build trigger on GitHub push to main
- [ ] Write skaffold.yaml for local dev loop
- [ ] Configure rolling update strategy on Deployments
- [ ] Verify full CI/CD: push code → auto-deploy → verify in browser

## Phase 4: Advanced K8s + Notifications
**Goal**: Production-hardened with advanced K8s features, daily digest notifications.
**Verification**: HPA scales under load, NetworkPolicy blocks unauthorized traffic, daily digest arrives.

- [ ] Write daily digest CronJob (reads DB, sends to LINE/Slack)
- [ ] Add HPA to backend and summarizer (CPU-based, then custom metrics)
- [ ] Add NetworkPolicy (DB only accessible from backend/workers, Redis only from workers)
- [ ] Configure Workload Identity for GCS access (optional: backup DB to GCS)
- [ ] Add SecurityContext (non-root, read-only filesystem where possible)
- [ ] Add ResourceQuota / LimitRange on namespace
- [ ] Add PodDisruptionBudget on backend
- [ ] Add sidecar container (e.g., CloudSQL proxy pattern or metrics exporter)
- [ ] Set up Prometheus + basic monitoring (stretch)

## Cost Budget

**Monthly target**: ~$40-50 USD

| Resource | Monthly Estimate |
|----------|-----------------|
| GKE cluster management (zonal) | $0 (free tier) |
| 2× e2-medium nodes (2 vCPU, 4GB) | ~$49 |
| Persistent disk 20GB (SSD) | ~$3.40 |
| Artifact Registry storage | ~$1-2 |
| Cloud Build | ~$0 (free tier) |
| Network egress | ~$1-2 |
| **Total** | **~$55/month** |

**Budget rules**:
- $300 credit / 88 days ≈ $3.40/day budget
- Set billing alerts at $50, $100, $150, $200, $250
- Weekly: check GCP Billing → Cost breakdown

## Reference Materials

- [Modern CI/CD with GKE: User Guide](https://docs.cloud.google.com/kubernetes-engine/docs/tutorials/modern-cicd-gke-user-guide)
- [Modern CI/CD with GKE: Reference Architecture](https://docs.cloud.google.com/kubernetes-engine/docs/tutorials/modern-cicd-gke-reference-architecture)
- [GKE Terraform Quickstart](https://docs.cloud.google.com/kubernetes-engine/docs/quickstarts/create-cluster-using-terraform)
