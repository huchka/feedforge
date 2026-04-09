variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-f"
}

variable "allowed_ips" {
  type        = list(string)
  description = "CIDR ranges allowed through Cloud Armor"
}

variable "db_password" {
  type        = string
  description = "Password for the Cloud SQL feedforge database user"
  sensitive   = true
}
