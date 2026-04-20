# Secret Management with GCP Secret Manager

FeedForge secrets are stored in [GCP Secret Manager](https://cloud.google.com/secret-manager)
and synced into pods via the
[Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/) with the
[GCP provider](https://github.com/GoogleCloudPlatform/secrets-store-csi-driver-provider-gcp).

## Architecture

```
GCP Secret Manager
        │
        ▼
  Secrets Store CSI Driver (DaemonSet on each node)
        │
        ▼
  SecretProviderClass (per secret group)
        │
        ├── Mounts secrets as files in /mnt/secrets/<group>/
        └── Syncs to K8s Secret objects (secretObjects)
              │
              └── Consumed by pods via env vars (secretKeyRef / envFrom)
```

The CSI driver syncs secrets from GCP Secret Manager into:

1. **Files** mounted at `/mnt/secrets/<group>/` inside the pod
2. **Kubernetes Secret objects** (via `secretObjects`) that pods reference through
   existing `secretKeyRef` and `envFrom` configurations

This means application code does **not** need to change — env vars are populated
from the synced K8s Secret just as before.

## Secrets Inventory

### postgres-credentials

| GCP Secret Name | K8s Secret Key | Used By |
|---|---|---|
| `feedforge-postgres-user` | `POSTGRES_USER` | backend, summarizer, fetcher, digest, backup |
| `feedforge-postgres-password` | `POSTGRES_PASSWORD` | backend, summarizer, fetcher, digest, backup |

### notification-credentials

| GCP Secret Name | K8s Secret Key | Used By |
|---|---|---|
| `feedforge-notification-webhook-url` | `NOTIFICATION_WEBHOOK_URL` | digest (optional) |
| `feedforge-line-channel-token` | `LINE_CHANNEL_TOKEN` | digest (optional) |
| `feedforge-line-user-id` | `LINE_USER_ID` | digest (optional) |

## Prerequisites

1. **Secrets Store CSI Driver** must be installed on the GKE cluster. Run the
   bootstrap script:

   ```bash
   k8s/bootstrap/install-csi-secrets-store.sh
   ```

   This installs the CSI driver (with `syncSecret.enabled=true`) and the GCP
   provider via Helm. The script is idempotent — safe to re-run.

2. **Workload Identity** must be enabled on the GKE cluster (already configured).

3. **Secret Manager API** must be enabled (`secretmanager.googleapis.com`).
   This is managed in Terraform (`terraform/environments/dev/main.tf`).

## Provisioning Secrets

### 1. Create secrets in GCP Secret Manager

```bash
PROJECT_ID="project-76da2d1f-231c-4c94-ae9"

# Postgres credentials
gcloud secrets create feedforge-postgres-user \
  --project="${PROJECT_ID}" \
  --replication-policy="automatic"
echo -n "feedforge" | gcloud secrets versions add feedforge-postgres-user \
  --project="${PROJECT_ID}" --data-file=-

gcloud secrets create feedforge-postgres-password \
  --project="${PROJECT_ID}" \
  --replication-policy="automatic"
echo -n "<YOUR_PASSWORD>" | gcloud secrets versions add feedforge-postgres-password \
  --project="${PROJECT_ID}" --data-file=-

# Notification credentials (optional — only needed for digest notifications)
gcloud secrets create feedforge-notification-webhook-url \
  --project="${PROJECT_ID}" \
  --replication-policy="automatic"
gcloud secrets create feedforge-line-channel-token \
  --project="${PROJECT_ID}" \
  --replication-policy="automatic"
gcloud secrets create feedforge-line-user-id \
  --project="${PROJECT_ID}" \
  --replication-policy="automatic"
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
| `feedforge-db-backup` | Postgres secrets |

These are applied automatically by `terraform apply`. No manual `gcloud`
commands needed.

### 3. SecretProviderClass PROJECT_ID

The base `SecretProviderClass` manifests in `k8s/base/secret-store/` contain a
literal `PROJECT_ID` placeholder. Each overlay (e.g., `k8s/overlays/dev/`)
patches these with the real GCP project ID via kustomize strategic merge patches:

- `patches/spc-postgres-patch.yaml`
- `patches/spc-notification-patch.yaml`

When adding a new environment, copy these patch files into the new overlay and
update the project ID. **Do not edit the base manifests directly.**

### 4. Deploy

```bash
# Apply the updated manifests
skaffold run

# Verify secrets are synced
kubectl get secrets -n feedforge
kubectl describe secretproviderclasspodstatus -n feedforge
```

## Rotating Secrets

To rotate a secret, add a new version in Secret Manager:

```bash
echo -n "<NEW_VALUE>" | gcloud secrets versions add feedforge-postgres-password \
  --project="${PROJECT_ID}" --data-file=-
```

How the new value propagates depends on how pods consume the secret:

- **Mounted files** (`/mnt/secrets/<group>/`): The CSI driver's
  `--rotation-poll-interval` (default: 2 minutes) automatically refreshes
  mounted files when a new secret version is published. No pod restart needed.
- **Environment variables** (`secretKeyRef` / `envFrom`): Env vars are resolved
  at pod start time and are **not** auto-refreshed. A rolling restart is
  required to pick up new values:

  ```bash
  kubectl rollout restart deployment/backend -n feedforge
  ```

**Recommended practice:** If your application can read secrets from the mounted
files at `/mnt/secrets/<group>/` instead of env vars, rotation is fully
automatic. If using env vars (the current default), perform a rolling restart
after publishing a new secret version.

## Migration from Kubernetes Secrets

Previously, secrets were stored as plain Kubernetes Secrets created manually via
`kubectl create secret`. The old approach had these limitations:

- Base64-encoded, not encrypted at rest by default
- No audit logging for secret access
- No built-in rotation mechanism
- Secrets visible to anyone with `kubectl get secret` access

Once Secret Manager is confirmed working, any manually-created K8s Secrets
should be removed:

```bash
# Only run after confirming Secret Manager secrets are working
kubectl delete secret postgres-credentials -n feedforge
kubectl delete secret notification-credentials -n feedforge
```

## First Deploy

On a cold-start (first `skaffold run` on a fresh cluster), there is a brief race
condition:

1. The CSI driver creates the K8s Secret (`postgres-credentials`,
   `notification-credentials`) only **after** the first pod mounts the
   `SecretProviderClass` volume.
2. Other pods that reference these secrets via `secretKeyRef` may briefly
   CrashLoopBackOff until the Secret objects exist.

All `secretKeyRef` entries are marked `optional: true` to prevent immediate pod
failures. However, pods still need the env vars to function — their readiness
probes will fail until the secrets are available, keeping them out of the Service
endpoints until they are healthy.

This is a one-time bootstrap issue. After the first successful pod mount, the
K8s Secret persists and subsequent pod starts find it immediately.

## Troubleshooting

### Pods stuck in ContainerCreating

The CSI driver must be installed and the GCP provider must be running. Check:

```bash
kubectl get pods -n kube-system -l app=secrets-store-csi-driver
kubectl get pods -n kube-system -l app=csi-secrets-store-provider-gcp
```

### Permission denied accessing secrets

Verify Workload Identity binding and IAM roles:

```bash
# Check the KSA → GSA binding
kubectl get serviceaccount <name> -n feedforge -o yaml | grep gcp-service-account

# Check the GSA has secretAccessor role
gcloud secrets get-iam-policy feedforge-postgres-user --project="${PROJECT_ID}"
```

### Secrets not updating after rotation

Mounted files auto-refresh via the CSI driver's rotation poll interval. If the
application reads secrets from **env vars**, those are set at pod start and
require a restart:

```bash
kubectl rollout restart deployment/<name> -n feedforge
```
