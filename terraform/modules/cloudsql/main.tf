# --- Private IP allocation for Cloud SQL ---

resource "google_compute_global_address" "cloudsql_private_ip" {
  name          = "feedforge-cloudsql-private-ip"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.network_id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.cloudsql_private_ip.name]
}

# --- Cloud SQL Instance ---

resource "google_sql_database_instance" "main" {
  name                = "feedforge-${var.environment}"
  project             = var.project_id
  region              = var.region
  database_version    = var.database_version
  deletion_protection = var.deletion_protection

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier              = var.tier
    availability_type = var.availability_type
    disk_size         = var.disk_size_gb
    disk_autoresize   = var.disk_autoresize
    disk_type         = "PD_SSD"

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.network_id
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled                        = var.backup_enabled
      point_in_time_recovery_enabled = var.point_in_time_recovery_enabled
      start_time                     = "04:00"
      location                       = var.region

      backup_retention_settings {
        retained_backups = 7
        retention_unit   = "COUNT"
      }
    }

    maintenance_window {
      day          = var.maintenance_window_day
      hour         = var.maintenance_window_hour
      update_track = "stable"
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    insights_config {
      query_insights_enabled  = true
      query_plans_per_minute  = 5
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = false
    }
  }
}

# --- Database ---

resource "google_sql_database" "feedforge" {
  name     = var.database_name
  instance = google_sql_database_instance.main.name
  project  = var.project_id
}

# --- Database User ---

resource "random_password" "db_password" {
  length  = 32
  special = false
}

resource "google_sql_user" "app" {
  name     = var.user_name
  instance = google_sql_database_instance.main.name
  project  = var.project_id
  password = random_password.db_password.result
}
