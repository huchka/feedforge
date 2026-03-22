variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
}

variable "zone" {
  type    = string
  default = "asia-northeast1-a"
}

variable "cluster_name" {
  type    = string
  default = "feedforge-cluster"
}

variable "network_name" {
  type        = string
  description = "VPC network name"
}

variable "subnet_name" {
  type        = string
  description = "Subnet name"
}

variable "pods_range_name" {
  type        = string
  description = "Secondary range name for pods"
}

variable "services_range_name" {
  type        = string
  description = "Secondary range name for services"
}

variable "machine_type" {
  type    = string
  default = "e2-medium"
}

variable "disk_size_gb" {
  type    = number
  default = 30
}

variable "disk_type" {
  type    = string
  default = "pd-standard"
}

variable "node_count" {
  type    = number
  default = 2
}

variable "min_node_count" {
  type    = number
  default = 1
}

variable "max_node_count" {
  type    = number
  default = 3
}

variable "node_service_account" {
  type        = string
  description = "Service account email for GKE nodes"
}
