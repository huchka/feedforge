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

# Workload Identity binding — must run after GKE (creates the WI pool)
resource "google_service_account_iam_member" "db_backup_workload_identity" {
  service_account_id = module.iam.db_backup_sa_name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[feedforge/db-backup]"

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
