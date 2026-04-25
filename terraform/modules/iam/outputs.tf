output "gke_node_sa_email" {
  value = google_service_account.gke_nodes.email
}

output "cloudsql_proxy_sa_email" {
  value = google_service_account.cloudsql_proxy.email
}

output "cloudsql_proxy_sa_name" {
  value = google_service_account.cloudsql_proxy.name
}

output "summarizer_sa_email" {
  value = google_service_account.summarizer.email
}

output "summarizer_sa_name" {
  value = google_service_account.summarizer.name
}
