output "namespace" {
  description = "Kubernetes namespace where Argo CD is installed."
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "release_name" {
  description = "Helm release name of the Argo CD install."
  value       = helm_release.argocd.name
}

output "chart_version" {
  description = "Version of the argo/argo-cd Helm chart that was installed."
  value       = helm_release.argocd.version
}
