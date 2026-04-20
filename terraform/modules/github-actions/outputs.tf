output "service_account_email" {
  value       = google_service_account.github_actions.email
  description = "Service account email to set as the GCP_SA_EMAIL repo variable in GitHub"
}

output "workload_identity_provider" {
  value       = google_iam_workload_identity_pool_provider.github.name
  description = "Full resource name of the WIF provider, e.g. projects/123/locations/global/workloadIdentityPools/github-pool/providers/github-provider. Set as the GCP_WIF_PROVIDER repo variable in GitHub."
}

output "workload_identity_pool_id" {
  value = google_iam_workload_identity_pool.github.workload_identity_pool_id
}
