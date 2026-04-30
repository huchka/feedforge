# Secret Management with GCP Secret Manager

FeedForge production secrets are stored in
[GCP Secret Manager](https://cloud.google.com/secret-manager) and exposed to
pods as files under `/mnt/secrets/<group>/` via the
[Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/) with
the [GCP provider](https://github.com/GoogleCloudPlatform/secrets-store-csi-driver-provider-gcp).
Workloads read those files directly through `app.secrets`; no Kubernetes
`Secret` objects are involved on the cloud path.

## Architecture

```
GCP Secret Manager
        │
        ▼
  Secrets Store CSI Driver (DaemonSet, --enable-secret-rotation)
        │
        ▼
  SecretProviderClass (per secret group)
        │
        └── Mounts secrets as files in /mnt/secrets/<group>/
               │
               └── Read by app.secrets on each access
                   (DB: per pool connection; notifications: per send)
```

There is no longer a synced K8s `Secret` for `postgres-credentials` /
`notification-credentials` on the dev cluster. This eliminates two prior
problems:

1. **Cold-start race.** The synced Secret was produced asynchronously by a
   controller after the first pod mounted the SPC volume, so pods started
   before it existed. CSI mount files are written synchronously on container
   start, so the file path doesn't race.
2. **No hot-rotation.** Env vars resolved from a Secret are frozen at pod
   start. CSI files refresh on the rotation poll, so new pool connections
   pick up the new value without a restart.

## Secrets Inventory

### postgres-credentials (`/mnt/secrets/postgres/`)

| GCP Secret Name | File Name | Used By |
|---|---|---|
| `feedforge-postgres-user` | `POSTGRES_USER` | backend, summarizer, fetcher, digest |
| `feedforge-postgres-password` | `POSTGRES_PASSWORD` | backend, summarizer, fetcher, digest |

### notification-credentials (`/mnt/secrets/notification/`)

| GCP Secret Name | File Name | Used By |
|---|---|---|
| `feedforge-notification-webhook-url` | `NOTIFICATION_WEBHOOK_URL` | digest (Slack provider) |
| `feedforge-line-channel-token` | `LINE_CHANNEL_TOKEN` | digest (LINE provider) |
| `feedforge-line-user-id` | `LINE_USER_ID` | digest (LINE provider) |

## Prerequisites

1. **Secrets Store CSI Driver** must be installed on the GKE cluster. Run the
   bootstrap script:

   ```bash
   k8s/bootstrap/install-csi-secrets-store.sh
   ```

   The script installs the CSI driver with `enableSecretRotation=true` and
   `rotationPollInterval=2m`, plus the GCP provider DaemonSet. It is idempotent.

2. **Workload Identity** must be enabled on the GKE cluster (already configured).

3. **Secret Manager API** must be enabled (`secretmanager.googleapis.com`).
   This is managed in Terraform (`terraform/environments/dev/main.tf`).

## Provisioning Secrets

### 1. Populate secret values in GCP Secret Manager

The secret containers (e.g., `feedforge-postgres-user`) and IAM bindings are
created automatically by Terraform. Only the values need to be populated:

```bash
PROJECT_ID="project-76da2d1f-231c-4c94-ae9"

# Postgres credentials
echo -n "feedforge" | gcloud secrets versions add feedforge-postgres-user \
  --project="${PROJECT_ID}" --data-file=-

echo -n "<YOUR_PASSWORD>" | gcloud secrets versions add feedforge-postgres-password \
  --project="${PROJECT_ID}" --data-file=-

# Notification credentials (only needed if the digest provider is enabled)
# echo -n "<WEBHOOK_URL>" | gcloud secrets versions add feedforge-notification-webhook-url \
#   --project="${PROJECT_ID}" --data-file=-
# echo -n "<TOKEN>" | gcloud secrets versions add feedforge-line-channel-token \
#   --project="${PROJECT_ID}" --data-file=-
# echo -n "<USER_ID>" | gcloud secrets versions add feedforge-line-user-id \
#   --project="${PROJECT_ID}" --data-file=-
```

### 2. IAM access via Workload Identity

Each Kubernetes ServiceAccount is bound to a GCP service account via Workload
Identity. The `roles/secretmanager.secretAccessor` grants are managed in
Terraform (`terraform/environments/dev/main.tf`) as
`google_secret_manager_secret_iam_member` resources:

| GCP SA | Secrets |
|--------|---------|
| `feedforge-cloudsql-proxy` | All postgres + notification secrets |
| `feedforge-summarizer` | Postgres secrets |

### 3. SecretProviderClass PROJECT_ID

The base `SecretProviderClass` manifests have a literal `PROJECT_ID`
placeholder. Each overlay patches it with the real project ID via
strategic-merge patches:

- `k8s/overlays/dev/patches/spc-postgres-patch.yaml`
- `k8s/overlays/dev/patches/spc-notification-patch.yaml`

When adding a new environment, copy these patch files and update the project
ID. **Do not edit the base manifests directly.**

### 4. Deploy

```bash
skaffold run -p dev

# The synced K8s Secrets are intentionally absent. Verify the SPCs are healthy
# and the CSI mount is present in the pods:
kubectl -n feedforge get secretproviderclass
kubectl -n feedforge exec deploy/backend -- ls /mnt/secrets/postgres
```

## Rotating Secrets

Add a new version in Secret Manager:

```bash
echo -n "<NEW_VALUE>" | gcloud secrets versions add feedforge-postgres-password \
  --project="${PROJECT_ID}" --data-file=-
```

Within `rotationPollInterval` (2 minutes) the CSI driver re-reads Secret
Manager and rewrites the file at `/mnt/secrets/<group>/<file>`. Propagation
into the running app:

- **DB credentials.** SQLAlchemy's pool calls `_connect` (in
  `backend/app/database.py`) on each new connection, which re-reads the
  current values from `/mnt/secrets/postgres/`. New pool connections use the
  new password; existing pooled connections keep working with the old value
  until they recycle (idle timeout / `pool_recycle`). No pod restart needed.
- **Notification credentials.** Read on every send call inside
  `_send_slack` / `_send_line`, so the next digest run picks up the new
  value automatically.

To force immediate adoption (e.g. emergency rotation), restart the deployments
or wait for the cron'd workloads to fire:

```bash
kubectl -n feedforge rollout restart deployment/backend deployment/summarizer
```

## Local Development

Local-dev paths do not have the Secret-Store CSI driver installed, so
`/mnt/secrets/...` does not exist. `app.secrets.read_secret` falls back to
environment variables:

| File key | Env-var fallback |
|---|---|
| `POSTGRES_USER` | `FEEDFORGE_DB_USER` |
| `POSTGRES_PASSWORD` | `FEEDFORGE_DB_PASSWORD` |
| `NOTIFICATION_WEBHOOK_URL` | `FEEDFORGE_DIGEST_WEBHOOK_URL` |
| `LINE_CHANNEL_TOKEN` | `FEEDFORGE_DIGEST_LINE_TOKEN` |
| `LINE_USER_ID` | `FEEDFORGE_DIGEST_LINE_USER_ID` |

- **Docker-compose / pure Python** (`.env.local`): `pydantic-settings` loads
  the `FEEDFORGE_*` vars; the helper hits the env-var branch.
- **Local kind cluster** (`k8s/overlays/local`): the postgres-cnpg
  component (`k8s/components/postgres-cnpg/{backend,fetcher,summarizer,digest}-env-patch.yaml`)
  injects `FEEDFORGE_DB_USER` / `FEEDFORGE_DB_PASSWORD` from the in-cluster
  `postgres-credentials` Secret via `secretKeyRef`. The local overlay's
  `patches/digest-patch.yaml` does the same for the notification secret
  (sourced from the developer-provided `secret-notification.yaml`).

## Troubleshooting

### Pods stuck in ContainerCreating

The CSI driver and the GCP provider must be running:

```bash
kubectl get pods -n kube-system -l app=secrets-store-csi-driver
kubectl get pods -n kube-system -l app=csi-secrets-store-provider-gcp
```

### Permission denied accessing secrets

Verify Workload Identity binding and IAM:

```bash
kubectl get serviceaccount <name> -n feedforge -o yaml | grep gcp-service-account
gcloud secrets get-iam-policy feedforge-postgres-user --project="${PROJECT_ID}"
```

### App still uses old credentials after rotation

Mounted files refresh on the rotation poll (≤ 2 minutes). If the file content
is current but the app is still using the old value, the SQLAlchemy pool is
holding old connections — wait for `pool_recycle`, force traffic to drain
the pool, or `kubectl rollout restart` the workload.

```bash
kubectl -n feedforge exec deploy/backend -- cat /mnt/secrets/postgres/POSTGRES_USER
```
