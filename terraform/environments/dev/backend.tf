terraform {
  backend "gcs" {
    bucket = "feedforge-tfstate-dev"
    prefix = "terraform/state"
  }
}
