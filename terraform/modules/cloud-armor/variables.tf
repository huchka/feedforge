variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "policy_name" {
  type    = string
  default = "feedforge-allow-ip"
}

variable "allowed_ips" {
  type        = list(string)
  description = "List of CIDR ranges to allow (e.g. [\"1.2.3.4/32\"])"
}
