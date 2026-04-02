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

# --- DB Backup (Workload Identity) ---

resource "google_service_account" "db_backup" {
  account_id   = "feedforge-db-backup"
  display_name = "FeedForge DB Backup Service Account"
  project      = var.project_id
}

resource "google_storage_bucket" "db_backup" {
  name     = "feedforge-db-backup-${var.project_id}"
  project  = var.project_id
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_storage_bucket_iam_member" "db_backup_writer" {
  bucket = google_storage_bucket.db_backup.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.db_backup.email}"
}

# --- Summarizer (Workload Identity) ---

resource "google_service_account" "summarizer" {
  account_id   = "feedforge-summarizer"
  display_name = "FeedForge Summarizer Service Account"
  project      = var.project_id
}

resource "google_project_iam_member" "summarizer_aiplatform" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.summarizer.email}"
}

