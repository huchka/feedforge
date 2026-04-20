provider "google" {
  project = var.project_id
  region  = var.region
}

# --- Project APIs ---

resource "google_project_service" "secretmanager" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

module "iam" {
  source     = "../../modules/iam"
  project_id = var.project_id
  region     = var.region
}

module "network" {
  source     = "../../modules/network"
  project_id = var.project_id
  region     = var.region
}

module "gke" {
  source               = "../../modules/gke"
  project_id           = var.project_id
  region               = var.region
  zone                 = var.zone
  network_name         = module.network.network_name
  subnet_name          = module.network.subnet_name
  pods_range_name      = module.network.pods_range_name
  services_range_name  = module.network.services_range_name
  node_service_account = module.iam.gke_node_sa_email
  environment          = "dev"

  depends_on = [module.network, module.iam]
}

module "artifact_registry" {
  source     = "../../modules/artifact-registry"
  project_id = var.project_id
  region     = var.region
}

module "cloud_armor" {
  source      = "../../modules/cloud-armor"
  project_id  = var.project_id
  allowed_ips = var.allowed_ips
}

module "cloud_sql" {
  source      = "../../modules/cloud-sql"
  project_id  = var.project_id
  region      = var.region
  network_id  = module.network.network_id
  db_password = var.db_password

  depends_on = [module.network]
}

# Workload Identity bindings — must run after GKE (creates the WI pool)

# Backend, fetcher, digest → cloudsql-proxy GCP SA
resource "google_service_account_iam_member" "cloudsql_proxy_workload_identity" {
  for_each = toset([
    "serviceAccount:${var.project_id}.svc.id.goog[feedforge/backend]",
    "serviceAccount:${var.project_id}.svc.id.goog[feedforge/feed-fetcher]",
    "serviceAccount:${var.project_id}.svc.id.goog[feedforge/daily-digest]",
  ])

  service_account_id = module.iam.cloudsql_proxy_sa_name
  role               = "roles/iam.workloadIdentityUser"
  member             = each.value

  depends_on = [module.gke]
}

# Summarizer → summarizer GCP SA (has both aiplatform.user + cloudsql.client)
resource "google_service_account_iam_member" "summarizer_workload_identity" {
  service_account_id = module.iam.summarizer_sa_name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[feedforge/summarizer]"

  depends_on = [module.gke]
}

# DB Backup → db-backup GCP SA (has cloudsql.client + storage.objectCreator)
resource "google_service_account_iam_member" "db_backup_workload_identity" {
  service_account_id = module.iam.db_backup_sa_name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[feedforge/db-backup]"

  depends_on = [module.gke]
}

# --- Secret Manager IAM grants ---
# Grant secretAccessor to each GSA for the secrets it needs.

locals {
  # Postgres secrets accessed by cloudsql-proxy, summarizer, and db-backup GSAs
  postgres_secret_names = [
    "feedforge-postgres-user",
    "feedforge-postgres-password",
  ]

  postgres_secret_accessors = {
    cloudsql_proxy = module.iam.cloudsql_proxy_sa_email
    summarizer     = module.iam.summarizer_sa_email
    db_backup      = module.iam.db_backup_sa_email
  }

  postgres_secret_bindings = flatten([
    for secret in local.postgres_secret_names : [
      for sa_key, sa_email in local.postgres_secret_accessors : {
        secret   = secret
        sa_key   = sa_key
        sa_email = sa_email
      }
    ]
  ])

  # Notification secrets accessed only by cloudsql-proxy GSA (used by digest)
  notification_secret_names = [
    "feedforge-notification-webhook-url",
    "feedforge-line-channel-token",
    "feedforge-line-user-id",
  ]
}

resource "google_secret_manager_secret_iam_member" "postgres_secret_access" {
  for_each = {
    for b in local.postgres_secret_bindings : "${b.secret}_${b.sa_key}" => b
  }

  project   = var.project_id
  secret_id = each.value.secret
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${each.value.sa_email}"
}

resource "google_secret_manager_secret_iam_member" "notification_secret_access" {
  for_each = toset(local.notification_secret_names)

  project   = var.project_id
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.iam.cloudsql_proxy_sa_email}"
}

module "cloud_build" {
  source                = "../../modules/cloud-build"
  project_id            = var.project_id
  region                = var.region
  connection_name       = "github"
  repository_name       = "huchka-feedforge"
  service_account_email = module.iam.cloud_build_sa_email

  depends_on = [module.iam]
}
