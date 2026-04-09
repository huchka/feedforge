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

output "cloudsql_private_ip" {
  value = module.cloudsql.private_ip_address
}

output "cloudsql_db_password" {
  value     = module.cloudsql.user_password
  sensitive = true
}
