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

# Cloud Build — user-managed SA (required for v2 triggers)
resource "google_service_account" "cloud_build" {
  account_id   = "feedforge-cloud-build"
  display_name = "FeedForge Cloud Build Service Account"
  project      = var.project_id
}

locals {
  cloud_build_roles = [
    "roles/container.developer",
    "roles/artifactregistry.writer",
    "roles/logging.logWriter",
  ]
}

resource "google_project_iam_member" "cloud_build_roles" {
  for_each = toset(local.cloud_build_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_build.email}"
}

# --- Cloud SQL Proxy (Workload Identity) ---

resource "google_service_account" "cloudsql_proxy" {
  account_id   = "feedforge-cloudsql-proxy"
  display_name = "FeedForge Cloud SQL Proxy Service Account"
  project      = var.project_id
}

resource "google_project_iam_member" "cloudsql_proxy_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloudsql_proxy.email}"
}

# --- Summarizer (Workload Identity) ---

resource "google_service_account" "summarizer" {
  account_id   = "feedforge-summarizer"
  display_name = "FeedForge Summarizer Service Account"
  project      = var.project_id
}

locals {
  summarizer_roles = [
    "roles/aiplatform.user",
    "roles/cloudsql.client",
  ]
}

resource "google_project_iam_member" "summarizer_roles" {
  for_each = toset(local.summarizer_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.summarizer.email}"
}

# --- DB Backup (Workload Identity) ---

resource "google_service_account" "db_backup" {
  account_id   = "feedforge-db-backup"
  display_name = "FeedForge DB Backup Service Account"
  project      = var.project_id
}

locals {
  db_backup_roles = [
    "roles/cloudsql.client",
    "roles/storage.objectCreator",
  ]
}

resource "google_project_iam_member" "db_backup_roles" {
  for_each = toset(local.db_backup_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.db_backup.email}"
}

