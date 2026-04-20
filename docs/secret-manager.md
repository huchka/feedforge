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
| `feedforge-postgres-user` | `POSTGRES_USER` | backend, summarizer, fetcher, digest, backup, postgres |
| `feedforge-postgres-password` | `POSTGRES_PASSWORD` | backend, summarizer, fetcher, digest, backup, postgres |

### notification-credentials

| GCP Secret Name | K8s Secret Key | Used By |
|---|---|---|
| `feedforge-notification-webhook-url` | `NOTIFICATION_WEBHOOK_URL` | digest (optional) |
| `feedforge-line-channel-token` | `LINE_CHANNEL_TOKEN` | digest (optional) |
| `feedforge-line-user-id` | `LINE_USER_ID` | digest (optional) |

## Prerequisites

1. **Secrets Store CSI Driver** must be installed on the GKE cluster:

   ```bash
   # Install the CSI driver
   helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
   helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
     --namespace kube-system \
     --set syncSecret.enabled=true

   # Install the GCP provider
   kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/secrets-store-csi-driver-provider-gcp/main/deploy/provider-gcp-plugin.yaml
   ```

2. **Workload Identity** must be enabled on the GKE cluster (already configured).

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

### 2. Grant IAM access via Workload Identity

Each Kubernetes ServiceAccount is bound to a GCP service account via Workload
Identity. Grant `roles/secretmanager.secretAccessor` to the GCP SAs that need
secret access:

```bash
PROJECT_ID="project-76da2d1f-231c-4c94-ae9"

# The cloudsql-proxy SA is used by: backend, fetcher, digest, postgres
gcloud secrets add-iam-policy-binding feedforge-postgres-user \
  --project="${PROJECT_ID}" \
  --role="roles/secretmanager.secretAccessor" \
  --member="serviceAccount:feedforge-cloudsql-proxy@${PROJECT_ID}.iam.gserviceaccount.com"
gcloud secrets add-iam-policy-binding feedforge-postgres-password \
  --project="${PROJECT_ID}" \
  --role="roles/secretmanager.secretAccessor" \
  --member="serviceAccount:feedforge-cloudsql-proxy@${PROJECT_ID}.iam.gserviceaccount.com"

# The summarizer SA
gcloud secrets add-iam-policy-binding feedforge-postgres-user \
  --project="${PROJECT_ID}" \
  --role="roles/secretmanager.secretAccessor" \
  --member="serviceAccount:feedforge-summarizer@${PROJECT_ID}.iam.gserviceaccount.com"
gcloud secrets add-iam-policy-binding feedforge-postgres-password \
  --project="${PROJECT_ID}" \
  --role="roles/secretmanager.secretAccessor" \
  --member="serviceAccount:feedforge-summarizer@${PROJECT_ID}.iam.gserviceaccount.com"

# The db-backup SA
gcloud secrets add-iam-policy-binding feedforge-postgres-user \
  --project="${PROJECT_ID}" \
  --role="roles/secretmanager.secretAccessor" \
  --member="serviceAccount:feedforge-db-backup@${PROJECT_ID}.iam.gserviceaccount.com"
gcloud secrets add-iam-policy-binding feedforge-postgres-password \
  --project="${PROJECT_ID}" \
  --role="roles/secretmanager.secretAccessor" \
  --member="serviceAccount:feedforge-db-backup@${PROJECT_ID}.iam.gserviceaccount.com"

# Notification secrets — only the cloudsql-proxy SA (used by digest)
for secret in feedforge-notification-webhook-url feedforge-line-channel-token feedforge-line-user-id; do
  gcloud secrets add-iam-policy-binding "${secret}" \
    --project="${PROJECT_ID}" \
    --role="roles/secretmanager.secretAccessor" \
    --member="serviceAccount:feedforge-cloudsql-proxy@${PROJECT_ID}.iam.gserviceaccount.com"
done
```

### 3. Update SecretProviderClass PROJECT_ID

Edit the `SecretProviderClass` manifests in `k8s/base/secret-store/` and replace
`PROJECT_ID` with your actual GCP project ID.

### 4. Deploy

```bash
# Apply the updated manifests
skaffold run

# Verify secrets are synced
kubectl get secrets -n feedforge
kubectl describe secretproviderclasspodstatus -n feedforge
```

## Rotating Secrets

To rotate a secret:

```bash
# Add a new version
echo -n "<NEW_VALUE>" | gcloud secrets versions add feedforge-postgres-password \
  --project="${PROJECT_ID}" --data-file=-

# The CSI driver will pick up the new version on the next pod restart.
# To force a refresh, restart the affected deployments:
kubectl rollout restart deployment/backend -n feedforge
```

## Migration from Kubernetes Secrets

Previously, secrets were stored as plain Kubernetes Secrets created manually via
`kubectl create secret`. The old approach had these limitations:

- Base64-encoded, not encrypted at rest by default
- No audit logging for secret access
- No built-in rotation mechanism
- Secrets visible to anyone with `kubectl get secret` access

The deprecated secret template is preserved at
`k8s/base/postgres/secret-postgres.yaml.deprecated` for reference. Once the
Secret Manager migration is confirmed working, this file should be deleted and
any manually-created K8s Secrets should be removed:

```bash
# Only run after confirming Secret Manager secrets are working
kubectl delete secret postgres-credentials -n feedforge
kubectl delete secret notification-credentials -n feedforge
```

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

The CSI driver caches secrets. Restart pods to pick up new versions:

```bash
kubectl rollout restart deployment/<name> -n feedforge
```
