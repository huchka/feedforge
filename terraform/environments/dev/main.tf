provider "google" {
  project = var.project_id
  region  = var.region
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

module "cloud_build" {
  source                = "../../modules/cloud-build"
  project_id            = var.project_id
  region                = var.region
  connection_name       = "github"
  repository_name       = "huchka-feedforge"
  service_account_email = module.iam.cloud_build_sa_email

  depends_on = [module.iam]
}
