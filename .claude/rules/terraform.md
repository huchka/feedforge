# Terraform — generation rules for feedforge

These rules cover patterns that `terraform validate` does NOT catch. Apply to any `*.tf` file in this project.

## Module structure

- Files per module: `versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`. Don't dump everything in `main.tf`.
- `versions.tf` MUST pin the `terraform` block and every `required_providers` entry with `~>` (e.g. `version = "~> 5.10"`). Exact pins (`= "5.10.0"`) are too brittle; floating major (`>= 5`) too loose.
- `variables.tf`: every `variable` block has `type` AND `description`. No untyped variables.
- `outputs.tf`: every `output` block has `description`. Mark sensitive values with `sensitive = true` (e.g. service-account keys, DB passwords).

## Resource patterns

- **Use `for_each` over `count`** when items are named (maps, sets of strings). `count` reorders state on insertion/removal and corrupts plans. Reserve `count` for purely numeric replication.
- **Use `templatefile()`**, not the deprecated `template_file` data source.
- **Use `moved` blocks** for refactors instead of `terraform state mv`. Moved blocks are reproducible; state mv is not.
- **`lifecycle { prevent_destroy = true }`** on Cloud SQL, GCS state buckets, KMS keys — anything where accidental destroy = data loss.

## Conventions specific to feedforge

- **Never hardcode `project_id`, region, or zone.** Always reference `var.project_id`, `var.region`, `var.zone`. The state bucket is in `asia-northeast1` (legacy), but new resources are `us-central1`.
- **Service accounts**: name format `<component>-sa@<project>.iam.gserviceaccount.com`. Roles: prefer predefined `roles/*` over custom; document any custom role with a comment explaining why predefined wasn't sufficient.
- **Workload Identity** is the auth pattern — never create JSON keys for service accounts. The CI uses Workload Identity Federation (no keys).
- **Network**: VPC + subnet are in module `network`. New workloads attach to the existing subnet via data source, not a new subnet.

## Output ordering inside a file

Consistent order improves diff readability:
1. `terraform { ... }` (versions.tf only)
2. `provider { ... }` (only in root modules; sub-modules don't declare providers)
3. `locals { ... }`
4. `data "..." { ... }` blocks
5. `resource "..." { ... }` blocks (group by logical concern, not alphabetically)
6. `output "..." { ... }` (outputs.tf only)

## Things NOT to do

- Don't write `provider` blocks inside child modules — pass providers from the root.
- Don't use `null_resource` + `local-exec` to run side-effectful scripts. If you need orchestration, that's an operational concern, not IaC.
- Don't rely on `depends_on` to fix race conditions when implicit references would work — implicit references are clearer.
