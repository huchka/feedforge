resource "google_compute_security_policy" "policy" {
  name        = var.policy_name
  project     = var.project_id
  description = "Allow only whitelisted IPs to access FeedForge"

  rule {
    action   = "deny(403)"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default deny"
  }

  rule {
    action   = "allow"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = var.allowed_ips
      }
    }
    description = "Allow whitelisted IPs"
  }
}
