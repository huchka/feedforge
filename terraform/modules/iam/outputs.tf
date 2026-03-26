output "gke_node_sa_email" {
  value = google_service_account.gke_nodes.email
}

output "cloud_build_sa_email" {
  value = google_service_account.cloud_build.email
}
