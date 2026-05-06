# Argo CD install via the official argo/argo-cd Helm chart.
#
# Trimmed for the e2-medium x 2 dev cluster:
#   - dex.enabled = false              (no SSO in v1)
#   - notifications.enabled = false    (no Slack/email in v1)
#   - applicationSet.replicas = 0      (chart has no `enabled` toggle for
#                                       this component — Deployment exists,
#                                       0 pods. We don't use ApplicationSet
#                                       generators in v1.)
#
# Application CRDs are NOT managed here — they live as YAML in
# k8s/argocd/applications/ and are applied with kubectl. See the
# "Migrate-Deploy-to-Argo-CD" wiki page.

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/name"    = "argocd"
      "app.kubernetes.io/part-of" = "argocd"
    }
  }
}

resource "helm_release" "argocd" {
  name       = var.release_name
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version

  # Wait for all chart resources to become Ready before returning.
  # Apply takes ~2-4 minutes; do not lower the timeout.
  wait    = true
  timeout = 600

  values = [
    yamlencode({
      dex = {
        enabled = false
      }
      notifications = {
        enabled = false
      }
      applicationSet = {
        # The chart unconditionally renders the ApplicationSet controller
        # (no top-level `enabled` key in 7.x or 9.x values). replicas: 0
        # is the closest off-switch the chart exposes.
        replicas = 0
      }
    })
  ]
}
