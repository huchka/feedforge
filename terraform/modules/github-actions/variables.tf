variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "github_repository" {
  type        = string
  description = "GitHub repository in owner/repo format allowed to impersonate the service account"
}

variable "pool_id" {
  type        = string
  default     = "github-pool"
  description = "Workload Identity Pool ID"
}

variable "provider_id" {
  type        = string
  default     = "github-provider"
  description = "Workload Identity Pool Provider ID"
}

variable "service_account_id" {
  type        = string
  default     = "feedforge-github-actions"
  description = "Account ID (pre-@) for the GitHub Actions service account"
}
