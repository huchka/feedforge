# Local Development

Three-tier flow: host-direct → local Kubernetes (kind) → GKE dev cluster. See the [Local Development Workflow design doc](https://github.com/huchka/feedforge/wiki/Local-Development-Workflow) for the why.

## Prerequisites

```bash
# macOS via Homebrew
brew install uv kind kubectl skaffold node

# Optional: cloud-sql-proxy for the hybrid escape hatch
brew install cloud-sql-proxy
```

Docker Desktop, Rancher Desktop, or colima must be running for kind and docker-compose.

## Tier 1 — host-direct (fast inner loop)

For everyday backend or frontend work. Sub-second reload, native debugger.

```bash
# 1. Start Postgres + Redis on localhost
make compose-up

# 2. Configure backend env (one-time)
cp .env.local.example .env.local

# 3. Run backend
cd backend
uv sync
uv run alembic upgrade head
uv run uvicorn app.main:app --reload

# 4. Run frontend (separate terminal)
cd frontend
npm install
npm run dev
```

Backend on `http://localhost:8000`, frontend on `http://localhost:5173` (Vite default).

When done:

```bash
make compose-down
```

`make compose-down -v` would also wipe Postgres data — don't pass `-v` unless you mean it.

## Tier 2 — local Kubernetes (kind + Calico)

For validating K8s manifests, NetworkPolicy, debugging an in-cluster pod.

```bash
# 1. Bootstrap (one-time, ~3 min)
make cluster-up

# 2. Build images, deploy, port-forward
make dev-local      # watch + redeploy on change
# OR
make deploy-local   # one-shot
```

`make dev-local` port-forwards backend `:8000`, frontend `:8080`, debugpy `:5678` to localhost.

To attach VS Code's Python debugger to the in-cluster backend, add to `.vscode/launch.json`:

```json
{
  "name": "Attach to in-cluster backend",
  "type": "debugpy",
  "request": "attach",
  "connect": { "host": "localhost", "port": 5678 },
  "pathMappings": [
    { "localRoot": "${workspaceFolder}/backend", "remoteRoot": "/app" }
  ]
}
```

Set a breakpoint, hit an API endpoint, watch it land.

To wipe and recreate (data loss expected — CNPG storage is ephemeral on `kind delete cluster`):

```bash
make cluster-down
make cluster-up
make deploy-local
```

### What's in the local overlay

This first cut includes **backend + frontend + redis + an in-cluster CNPG Postgres**. NetworkPolicy is enforced (Calico), so you can verify policies work before pushing to GKE.

Not yet in the local overlay (handled only on the GKE dev cluster):

- `fetcher` / `summarizer` / `digest` workloads — need Cloud SQL Proxy and CSI patches
- Observability stack (Prometheus / Grafana / kube-state-metrics)
- Gateway / Ingress
- HPA (kind has no metrics-server by default)

These are tracked as follow-up work.

## Tier 3 — GKE dev cluster

Unchanged. Push to `main`, GitHub Actions builds and deploys via `skaffold run`. See [README — Deploying](../README.md#deploying-to-a-fresh-environment).

## Hybrid: Tier 1 against real Cloud SQL

For the rare case where a bug only repros against prod-shaped data.

```bash
# 1. Authenticate
gcloud auth application-default login

# 2. Start the proxy on localhost:5433 (avoid colliding with compose Postgres on 5432)
make use-cloudsql

# 3. Update .env.local while the proxy runs:
#    FEEDFORGE_DB_HOST=localhost
#    FEEDFORGE_DB_PORT=5433
#    FEEDFORGE_DB_USER=<from Secret Manager>
#    FEEDFORGE_DB_PASSWORD=<from Secret Manager>

# 4. Run backend as in Tier 1
```

Stop with Ctrl-C in the `make use-cloudsql` terminal.

## Troubleshooting

**`kind create cluster` hangs.** Increase Docker's memory allocation to ≥4 GB and CPU to ≥2.

**Calico pods stuck Pending.** Check `kubectl -n calico-system get pods` and `kubectl -n tigera-operator get pods`. The `tigera-operator` Deployment must be Running before Calico can install.

**`make deploy-local` fails with image pull errors.** Skaffold should `kind load` images automatically. If it doesn't, check the skaffold profile is active: `skaffold diagnose -p local`.

**Backend pod CrashLoopBackOff with DB connection refused.** Check the CNPG Cluster is ready: `kubectl get cluster feedforge-db -n feedforge`. The first boot takes ~30s.

**Port-forward dies.** `skaffold dev` re-establishes on each redeploy. If one-shot, re-run `kubectl port-forward svc/backend 8000:8000 -n feedforge`.
