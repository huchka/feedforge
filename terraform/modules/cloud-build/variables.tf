variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "trigger_name" {
  type    = string
  default = "feedforge-deploy"
}

variable "connection_name" {
  type        = string
  description = "Cloud Build v2 connection name"
}

variable "repository_name" {
  type        = string
  description = "Cloud Build v2 linked repository name"
}
