variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "gke_sa_name" {
  type    = string
  default = "feedforge-gke-nodes"
}
