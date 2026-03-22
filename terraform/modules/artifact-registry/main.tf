resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  project       = var.project_id
  repository_id = var.repository_id
  description   = "Docker images for FeedForge"
  format        = "DOCKER"

  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = 5
    }
  }
}
