output "cluster_name" {
  value = module.gke.cluster_name
}

output "cluster_endpoint" {
  value     = module.gke.cluster_endpoint
  sensitive = true
}

output "cluster_location" {
  value = module.gke.cluster_location
}

output "artifact_registry_url" {
  value = module.artifact_registry.repository_url
}

output "get_credentials_command" {
  value = "gcloud container clusters get-credentials ${module.gke.cluster_name} --zone ${var.zone} --project ${var.project_id}"
}

output "cloud_sql_connection_name" {
  value = module.cloud_sql.instance_connection_name
}

# GitHub Actions WIF — set these as repo variables in GitHub
# (Settings → Secrets and variables → Actions → Variables)
output "github_actions_project_id" {
  value       = var.project_id
  description = "Set as the GCP_PROJECT_ID repo variable in GitHub"
}

output "github_actions_service_account_email" {
  value       = module.github_actions.service_account_email
  description = "Set as the GCP_SA_EMAIL repo variable in GitHub"
}

output "github_actions_workload_identity_provider" {
  value       = module.github_actions.workload_identity_provider
  description = "Set as the GCP_WIF_PROVIDER repo variable in GitHub"
}
