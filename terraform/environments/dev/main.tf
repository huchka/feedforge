provider "google" {
  project = var.project_id
  region  = var.region
}

module "iam" {
  source     = "../../modules/iam"
  project_id = var.project_id
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
  source     = "../../modules/cloud-armor"
  project_id = var.project_id
  allowed_ips = var.allowed_ips
}
