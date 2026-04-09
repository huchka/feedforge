variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
}

variable "network_id" {
  type        = string
  description = "VPC network ID for private IP peering"
}

variable "database_version" {
  type    = string
  default = "POSTGRES_16"
}

variable "tier" {
  type        = string
  default     = "db-f1-micro"
  description = "Cloud SQL machine tier (db-f1-micro for dev, db-custom-1-3840 for prod)"
}

variable "disk_size_gb" {
  type    = number
  default = 10
}

variable "disk_autoresize" {
  type    = bool
  default = true
}

variable "database_name" {
  type    = string
  default = "feedforge"
}

variable "user_name" {
  type    = string
  default = "feedforge"
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "availability_type" {
  type        = string
  default     = "ZONAL"
  description = "ZONAL for dev (single zone), REGIONAL for prod (HA)"
}

variable "backup_enabled" {
  type    = bool
  default = true
}

variable "point_in_time_recovery_enabled" {
  type    = bool
  default = true
}

variable "maintenance_window_day" {
  type        = number
  default     = 7
  description = "Day of week for maintenance (1=Mon, 7=Sun)"
}

variable "maintenance_window_hour" {
  type        = number
  default     = 3
  description = "Hour of day (UTC) for maintenance window"
}

variable "environment" {
  type    = string
  default = "dev"
}
