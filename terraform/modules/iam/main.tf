resource "google_service_account" "gke_nodes" {
  account_id   = var.gke_sa_name
  display_name = "FeedForge GKE Node Service Account"
  project      = var.project_id
}

locals {
  gke_node_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/artifactregistry.reader",
    "roles/storage.objectViewer",
  ]
}

resource "google_project_iam_member" "gke_node_roles" {
  for_each = toset(local.gke_node_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}
