# Cloud SQL Security

To comply with GCP Security Command Center recommendations and best practices, the `feedforge-postgres` instance is configured with several security controls:

## SSL Enforcement
Direct connections to the Cloud SQL instance require SSL (`ssl_mode = "ENCRYPTED_ONLY"`). This prevents any unencrypted direct connections from reaching the database. Note that the Cloud SQL Auth Proxy sidecar automatically handles the encrypted tunnel when connecting via Workload Identity.

## Audit Logging (pgAudit)
Database audit logging is enabled via the `cloudsql.enable_pgaudit` database flag. This allows tracking of detailed database activities, which are sent to Cloud Logging.

## Password Policy
The database instance enforces a password validation policy for all database users:
- **Minimum Length**: 12 characters
- **Complexity**: Default complexity rules
- **Reuse Interval**: Previous 2 passwords cannot be reused
- **Username Substring**: Passwords cannot contain the username (Note: `disallow_username_substring = true` will reject any password containing the string `feedforge`. Ensure `var.db_password` does not contain this substring or future rotations will fail).

These settings are managed via Terraform in `terraform/modules/cloud-sql/main.tf`.
