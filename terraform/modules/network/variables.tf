variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
}

variable "network_name" {
  type    = string
  default = "feedforge-vpc"
}

variable "subnet_name" {
  type    = string
  default = "feedforge-subnet"
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.0.0/24"
}

variable "pods_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "pods_range_name" {
  type    = string
  default = "pods"
}

variable "services_cidr" {
  type    = string
  default = "10.2.0.0/20"
}

variable "services_range_name" {
  type    = string
  default = "services"
}
