# FeedForge Development Plan

## Application Components

| Component | Type | Tech | K8s Resource |
|-----------|------|------|-------------|
| Frontend | Web UI | React (Vite) | Deployment + Service |
| Backend API | REST API | Python FastAPI | Deployment + Service |
| Feed Fetcher | Scheduled worker | Python | CronJob |
| AI Summarizer | Background worker | Python | Deployment (long-running consumer) |
| Daily Digest | Notification sender | Python | CronJob |
| PostgreSQL | Database | Cloud SQL for PostgreSQL 16 | Cloud SQL (managed) + Auth Proxy Deployment + Service |
| Redis | Message queue / cache | Redis 7 | Deployment + Service |

## Data Flow

```
[RSS Sources] → (CronJob: Fetcher) → [Redis Queue] → (Worker: Summarizer) → [Cloud SQL Proxy] → [Cloud SQL]
                                                                                                      ↑
[User Browser] → (Ingress) → [Frontend] → [Backend API] → [Cloud SQL Proxy] ────────────────────────┘

(CronJob: Digest) → reads via [Cloud SQL Proxy] → [Cloud SQL] → sends to [LINE/Slack]
```

## K8s Concepts Coverage (Learning Tracker)

| Concept | Phase | Status |
|---------|-------|--------|
| Deployment | P1 | ☑ |
| StatefulSet | P1 | ☑ |
| Service (ClusterIP) | P1 | ☑ |
| Service (headless) | P1 | ☑ |
| ConfigMap | P1 | ☑ |
| Secret | P1 | ☑ |
| PersistentVolumeClaim | P1 | ☑ |
| Ingress | P3 | ☑ |
| CronJob | P2 | ☑ |
| Job | P5 | ☑ |
| HPA | P4 | ☑ |
| Init container | P1 | ☑ |
| NetworkPolicy | P5 | ☑ |
| SecurityContext | P5 | ☑ |
| RBAC / ServiceAccount | P5 | ☑ |
| Workload Identity | P5 | ☑ |
| Sidecar container | P6 | ☑ |
| ResourceQuota / LimitRange | P6 | ☑ |
| PodDisruptionBudget | P6 | ☑ |
| Maintenance window | P6 | ☑ |
| Surge upgrade strategy | P6 | ☑ |
| Resource requests/limits | P1 | ☑ |
| Liveness/readiness probes | P1 | ☑ |
| Rolling update strategy | P3 | ☑ |
| kustomize overlays | P3 | ☑ |
| BackendConfig (Cloud Armor) | P3 | ☑ |
| Cloud SQL Auth Proxy | P7 | ☐ |
| Managed database (Cloud SQL) | P7 | ☐ |

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
- [x] `terraform destroy` (keeping cluster running, ~$2/day)

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

- [x] Write feed fetcher script (feedparser library, pushes to Redis queue)
- [x] Write AI summarizer worker (consumes Redis queue, calls LLM API, writes to DB)
- [x] Write Dockerfile for workers
- [x] Deploy Redis (Deployment + Service)
- [x] Write K8s CronJob manifest for feed fetcher
- [x] Write K8s Deployment manifest for summarizer (long-running consumer)
- [x] Write Secrets for LLM API keys
- [x] Deploy and verify: add feed → CronJob fires → articles fetched → summarized

## Phase 3: Frontend + Ingress + CI/CD
**Goal**: Full web UI accessible via Ingress, CI/CD pipeline auto-deploys on push.
**Verification**: Push to main → Cloud Build triggers → new image deployed → visible in browser.

- [x] Build React frontend (article list, feed management, search, favorites)
- [x] Write Dockerfile for frontend (nginx + static build)
- [x] Write K8s manifests: Frontend Deployment + Service
- [x] Configure Ingress (path-based: / → frontend, /api → backend)
- [x] Set up kustomize overlays for dev
- [x] Add Cloud Armor IP restriction (Terraform module + BackendConfig)
- [x] Write cloudbuild.yaml (build all images → push → deploy)
- [x] Set up Cloud Build trigger on GitHub push to main (Terraform module)
- [x] Write skaffold.yaml for local dev loop
- [x] Configure rolling update strategy on Deployments
- [x] Verify full CI/CD: push code → auto-deploy → verify in browser

## Phase 4: Scaling & Notifications
**Goal**: Daily digest notifications, autoscaling under load.
**Verification**: HPA scales under load, daily digest arrives in LINE/Slack.

- [x] Write daily digest CronJob (reads DB, sends to LINE/Slack)
- [x] Add HPA to backend and summarizer (CPU-based, 70% target, 1-3 replicas)
- [x] Fix skaffold.yaml for v4beta11 schema + cross-platform builds

## Phase 5: Security Hardening
**Goal**: Least-privilege at network, pod, and identity layers.
**Verification**: NetworkPolicy blocks unauthorized traffic, pods run non-root, Workload Identity used for GCP access.

- [x] Add NetworkPolicy (DB only accessible from backend/workers, Redis only from workers)
- [x] Enable Calico + metrics-server via Terraform
- [x] Add SecurityContext (non-root, read-only filesystem where possible)
- [x] Add RBAC / ServiceAccount (dedicated SAs per workload, automountServiceAccountToken: false)
- [x] Configure Workload Identity for GCS access (db-backup Job → GCS via WI)

## Phase 6: Reliability & Observability
**Goal**: Resource governance, availability guarantees, monitoring.
**Verification**: ResourceQuota enforced, PDB prevents full disruption during node drain, metrics visible.

- [x] Add ResourceQuota / LimitRange on namespace
- [x] Add PodDisruptionBudget on backend, frontend, summarizer
- [x] Add sidecar container (log-exporter on backend)
- [x] Add GKE maintenance window (daily 02:00–06:00 UTC via Terraform)
- [x] Add surge upgrade strategy (max_surge=1, max_unavailable=0)
- [x] Upgrade node machine type to e2-standard-2
- [x] Set up Prometheus + basic monitoring (stretch)

## Phase 7: Cloud SQL Migration
**Goal**: Migrate PostgreSQL from in-cluster StatefulSet to managed Cloud SQL for improved reliability and automated backups.
**Verification**: `terraform plan` shows Cloud SQL resources, `kustomize build` succeeds, all workloads connect via Cloud SQL Auth Proxy.

- [ ] Create `terraform/modules/cloudsql/` module (instance, database, user, private IP, backups)
- [ ] Add Cloud SQL Proxy IAM service account + `roles/cloudsql.client` to IAM module
- [ ] Wire Cloud SQL module into `terraform/environments/dev/main.tf`
- [ ] Add Workload Identity binding for Cloud SQL Auth Proxy
- [ ] Deploy Cloud SQL Auth Proxy as standalone Deployment + Service
- [ ] Update `backend-config` ConfigMap (`FEEDFORGE_DB_HOST` → `cloudsql-proxy`)
- [ ] Update `backup-config` ConfigMap (`PGHOST` → `cloudsql-proxy`)
- [ ] Replace postgres NetworkPolicy with Cloud SQL Proxy NetworkPolicy
- [ ] Remove old StatefulSet manifests from kustomization.yaml
- [ ] `terraform plan` → review → `terraform apply`
- [ ] Migrate data: `pg_dump` from StatefulSet → `psql` import via proxy
- [ ] Verify Alembic migrations against Cloud SQL
- [ ] Verify all workloads (backend, summarizer, fetcher, digest, backup)

## Cost Budget

**Monthly target**: ~$40-50 USD

| Resource | Monthly Estimate |
|----------|-----------------|
| GKE cluster management (zonal) | $0 (free tier) |
| 2× e2-standard-2 nodes (2 vCPU, 8GB) | ~$97 |
| Cloud SQL db-f1-micro (PostgreSQL 16) | ~$7-10 |
| Cloud SQL storage 10GB (SSD) | ~$1.70 |
| Artifact Registry storage | ~$1-2 |
| Cloud Build | ~$0 (free tier) |
| Network egress | ~$1-2 |
| **Total** | **~$108-113/month** |

**Budget rules**:
- $300 credit / 88 days ≈ $3.40/day budget
- Set billing alerts at $50, $100, $150, $200, $250
- Weekly: check GCP Billing → Cost breakdown

## Reference Materials

- [Modern CI/CD with GKE: User Guide](https://docs.cloud.google.com/kubernetes-engine/docs/tutorials/modern-cicd-gke-user-guide)
- [Modern CI/CD with GKE: Reference Architecture](https://docs.cloud.google.com/kubernetes-engine/docs/tutorials/modern-cicd-gke-reference-architecture)
- [GKE Terraform Quickstart](https://docs.cloud.google.com/kubernetes-engine/docs/quickstarts/create-cluster-using-terraform)
