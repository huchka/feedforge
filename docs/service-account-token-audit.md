# Service Account Token Audit

This document tracks which pods have `automountServiceAccountToken` enabled and
the justification for each decision. The setting is configured at both the
ServiceAccount level and the pod spec level for defense in depth.

## Pods with token mounting DISABLED (automountServiceAccountToken: false)

These pods do not need Kubernetes API access. The SA token is not mounted,
reducing the attack surface if a pod is compromised.

| Workload | Kind | Reason token is not needed |
|---|---|---|
| backend | Deployment | Application workload. Uses Workload Identity for Cloud SQL (metadata server, not SA token). |
| frontend | Deployment | Static web UI (nginx). No GCP or K8s API access needed. |
| postgres | StatefulSet | Database. Uses Workload Identity for Secret Manager access. |
| redis | Deployment | In-memory cache. No external service access. |
| summarizer | Deployment | Worker. Uses Workload Identity for Cloud SQL and LLM API. |
| feed-fetcher | CronJob | Worker. Uses Workload Identity for Cloud SQL. |
| daily-digest | CronJob | Worker. Uses Workload Identity for Cloud SQL and notifications. |
| db-backup | Job | Backup job. Uses Workload Identity for GCS and Cloud SQL. |
| grafana | Deployment | Dashboard UI. Reads from Prometheus, no K8s API access needed. |
| nginx-hello | Deployment | Phase 0 verification pod. No API access needed. |

### Note on Workload Identity and SA tokens

Workload Identity on GKE uses the GKE metadata server (`169.254.169.254`) to
provide GCP credentials, **not** the mounted Kubernetes service account token.
Disabling `automountServiceAccountToken` does not affect Workload Identity.

The Cloud SQL Auth Proxy sidecar/init container uses Workload Identity and is
unaffected by this setting.

## Pods with token mounting ENABLED (automountServiceAccountToken: true)

These pods require Kubernetes API access for their core functionality.

| Workload | Kind | Reason token IS needed |
|---|---|---|
| prometheus | Deployment | Service discovery: queries the K8s API to discover scrape targets. Has ClusterRole for pods, services, endpoints, and nodes. |
| prometheus-adapter | Deployment | Custom metrics API: serves as a Kubernetes API extension (`custom.metrics.k8s.io`). Requires API access to register and serve custom metrics for HPA. |
| kube-state-metrics | Deployment | Cluster metrics: watches K8s API objects (deployments, pods, nodes, etc.) to export state metrics. Requires ClusterRole with broad read access. |
