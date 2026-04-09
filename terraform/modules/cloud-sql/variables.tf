variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
  default     = "us-central1"
}

variable "instance_name" {
  type    = string
  default = "feedforge-postgres"
}

variable "network_id" {
  type        = string
  description = "VPC network ID for private IP"
}

variable "db_password" {
  type        = string
  description = "Password for the feedforge database user"
  sensitive   = true
}
