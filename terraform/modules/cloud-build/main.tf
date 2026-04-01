resource "google_cloudbuild_trigger" "deploy" {
  name     = var.trigger_name
  project  = var.project_id
  location = var.region

  repository_event_config {
    repository = "projects/${var.project_id}/locations/${var.region}/connections/${var.connection_name}/repositories/${var.repository_name}"

    push {
      branch = "^main$"
    }
  }

  service_account = "projects/${var.project_id}/serviceAccounts/${var.service_account_email}"
  filename        = "cloudbuild.yaml"
}
