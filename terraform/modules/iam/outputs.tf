output "gke_node_sa_email" {
  value = google_service_account.gke_nodes.email
}

output "cloud_build_sa_email" {
  value = google_service_account.cloud_build.email
}

output "db_backup_sa_email" {
  value = google_service_account.db_backup.email
}

output "db_backup_sa_name" {
  value = google_service_account.db_backup.name
}

output "db_backup_bucket_name" {
  value = google_storage_bucket.db_backup.name
}
