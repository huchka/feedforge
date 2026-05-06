# Workload Identity Federation for GitHub Actions.
#
# Lets GitHub Actions workflows in var.github_repository authenticate to GCP
# (Artifact Registry push, GKE deploy) without long-lived service account keys.

data "google_project" "current" {
  project_id = var.project_id
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = "GitHub Actions"
  description               = "OIDC federation for GitHub Actions workflows"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = "GitHub Provider"
  description                        = "OIDC provider for token.actions.githubusercontent.com"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Lock the provider to a single repo so a token issued for any other
  # GitHub repo cannot be used to impersonate the service account.
  attribute_condition = "assertion.repository == \"${var.github_repository}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "github_actions" {
  project      = var.project_id
  account_id   = var.service_account_id
  display_name = "FeedForge GitHub Actions Service Account"
  description  = "Impersonated by GitHub Actions via Workload Identity Federation"
}

locals {
  # CI no longer talks to the cluster — Argo CD owns deploys (Phase 3 of #32).
  # The SA only needs to push images; it pushes commits back to the repo via
  # the workflow's GITHUB_TOKEN, not via GCP IAM.
  github_actions_roles = [
    "roles/artifactregistry.writer", # push images
  ]
}

resource "google_project_iam_member" "github_actions_roles" {
  for_each = toset(local.github_actions_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

# Allow GitHub Actions workflows in the configured repo to impersonate the SA.
resource "google_service_account_iam_member" "github_actions_workload_identity_user" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}/attribute.repository/${var.github_repository}"
}
