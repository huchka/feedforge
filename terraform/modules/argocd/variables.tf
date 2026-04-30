variable "chart_version" {
  type        = string
  description = "Version of the argo/argo-cd Helm chart to install. Pin explicitly; bump deliberately. See https://github.com/argoproj/argo-helm/releases."
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace to install Argo CD into. Created by this module."
  default     = "argocd"
}

variable "release_name" {
  type        = string
  description = "Helm release name for the Argo CD install."
  default     = "argocd"
}
