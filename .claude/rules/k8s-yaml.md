# Kubernetes manifests — generation rules for feedforge

These rules cover patterns that `kubeconform` does NOT catch (it validates schema, not preferences or security defaults). Apply to any YAML file under `k8s/`.

## API versions — use stable only

- `apps/v1` — Deployment, StatefulSet, DaemonSet, ReplicaSet
- `batch/v1` — Job, CronJob
- `networking.k8s.io/v1` — Ingress, NetworkPolicy
- `autoscaling/v2` — HorizontalPodAutoscaler (NOT v2beta1, NOT v2beta2)
- `policy/v1` — PodDisruptionBudget (NOT policy/v1beta1)
- `rbac.authorization.k8s.io/v1` — Role, ClusterRole, RoleBinding, ClusterRoleBinding

If you write `*v1beta*` for any of the above, that's a bug — those APIs have all GA'd.

## Required labels (every workload)

```yaml
metadata:
  labels:
    app.kubernetes.io/name: <component>      # e.g. backend, frontend, postgres
    app.kubernetes.io/component: <role>      # e.g. api, worker, db
    app.kubernetes.io/part-of: feedforge
    app.kubernetes.io/instance: <name>       # usually matches metadata.name
```

`Selector` blocks (Deployment, Service, NetworkPolicy) reference these labels — never invent ad-hoc label keys.

## PodSpec defaults — non-negotiable

Every Pod template (Deployment, StatefulSet, Job, CronJob) MUST include:

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000           # or specific UID; never 0
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: <name>
      image: <pinned-tag>     # never :latest
      imagePullPolicy: IfNotPresent
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: [ALL]
      resources:
        requests:
          cpu: <value>
          memory: <value>
        limits:
          memory: <value>     # always set memory limit; CPU limit optional but document choice
      livenessProbe: { ... }
      readinessProbe: { ... }
```

If `readOnlyRootFilesystem: true` causes issues (e.g. tools writing to `/tmp`), add an `emptyDir` volume mount for the writable path — don't disable the protection.

## Workload kind selection

- **Deployment** — stateless app pods (backend API, frontend, summarizer worker)
- **StatefulSet** — stateful with stable identity (Postgres, Redis with persistence). For feedforge, Postgres is on Cloud SQL — no in-cluster StatefulSet for it. Redis 7 is in-cluster.
- **CronJob** — scheduled jobs (feed fetcher, daily digest sender)
- **Job** — one-shot (DB migrations); use `restartPolicy: OnFailure`

## Secrets — never inline

- No `stringData:` or `data:` with plaintext secrets in committed YAML.
- Secrets come from Secret Manager via the CSI driver (the project uses workload identity → secret manager). Reference via `volumeMounts` of the CSI-mounted secret, OR via `envFrom: secretRef:` for Kubernetes Secrets that are themselves synced from Secret Manager.
- For secret references in env vars: use `valueFrom.secretKeyRef`, never inline.

## NetworkPolicy

- Each namespace has a default-deny ingress policy. Workloads then declare what they accept via additional NetworkPolicies.
- A new workload MUST come with its NetworkPolicy in the same kustomize component.

## Service & Ingress

- Default `Service.spec.type: ClusterIP`. LoadBalancer only via Ingress.
- Ingress: project is migrating from `kubernetes.io/ingress.class: gce` to Gateway API (`gateway.networking.k8s.io`). Check the current overlay before generating — don't mix paradigms in the same overlay.

## Resources & probes — sizing hints

- `requests.cpu` typically `100m`–`500m`, `requests.memory` `128Mi`–`512Mi` for app pods.
- `livenessProbe` MUST NOT be too aggressive — `initialDelaySeconds: 30`, `periodSeconds: 10` is a safe default for HTTP apps. Aggressive liveness causes restart storms.
- `readinessProbe` should be the strict one — fail fast so Service stops sending traffic.

## Things NOT to do

- Don't set `imagePullPolicy: Always` with a pinned tag — defeats the cache.
- Don't use `hostNetwork`, `hostPID`, `hostPath` volumes (except for very specific debugging — and never in committed manifests).
- Don't reference ConfigMap/Secret keys that don't exist in the same kustomize overlay — kustomize won't catch this; it'll fail at apply time.
- Don't set `replicas` on a Deployment that has an HPA — the HPA owns the replica count; setting it on the Deployment causes flapping.
