terraform {
  required_version = ">= 1.5.0"

  # Uncomment after first `terraform apply` (bucket must exist), then: terraform init -migrate-state
   backend "gcs" {
     bucket = "tfstate-msgb-bt-7-2026"
     prefix = "bootstrap"
   }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}
