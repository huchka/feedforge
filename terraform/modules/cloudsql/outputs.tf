output "instance_name" {
  value = google_sql_database_instance.main.name
}

output "instance_connection_name" {
  value = google_sql_database_instance.main.connection_name
}

output "private_ip_address" {
  value = google_sql_database_instance.main.private_ip_address
}

output "database_name" {
  value = google_sql_database.feedforge.name
}

output "user_name" {
  value = google_sql_user.app.name
}

output "user_password" {
  value     = random_password.db_password.result
  sensitive = true
}
