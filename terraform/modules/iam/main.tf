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
    "roles/aiplatform.user",
  ]
}

resource "google_project_iam_member" "gke_node_roles" {
  for_each = toset(local.gke_node_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# Cloud Build default SA — needs GKE deploy + AR push permissions
data "google_project" "project" {
  project_id = var.project_id
}

locals {
  cloud_build_sa = "${data.google_project.project.number}@cloudbuild.gserviceaccount.com"

  cloud_build_roles = [
    "roles/container.developer",
    "roles/artifactregistry.writer",
  ]
}

resource "google_project_iam_member" "cloud_build_roles" {
  for_each = toset(local.cloud_build_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${local.cloud_build_sa}"
}
