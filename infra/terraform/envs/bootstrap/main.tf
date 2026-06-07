locals {
  name_prefix = "boutique"
  labels = {
    platform = "microservices-google"
    managed  = "terraform"
  }
}

resource "google_storage_bucket" "tfstate" {
  name                        = var.tfstate_bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
  lifecycle_rule {
    condition {
      num_newer_versions = 10
    }
    action {
      type = "Delete"
    }
  }
  labels = local.labels
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "${local.name_prefix}-github"
  display_name              = "GitHub Actions"
  description               = "OIDC federation for GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub OIDC"
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }
  attribute_condition = "assertion.repository == '${var.github_org}/${var.github_repo}'"
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "terraform_ci" {
  account_id   = "sa-terraform-ci"
  display_name = "Terraform CI (GitHub Actions)"
}

resource "google_service_account" "build_ci" {
  account_id   = "sa-build-ci"
  display_name = "Build and push images (dev AR only)"
}

resource "google_service_account" "promote_ci" {
  account_id   = "sa-promote-ci"
  display_name = "Promote images between AR repos"
}

locals {
  github_wif_member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org}/${var.github_repo}"
}

resource "google_service_account_iam_member" "terraform_ci_wif" {
  service_account_id = google_service_account.terraform_ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.github_wif_member
}

resource "google_service_account_iam_member" "build_ci_wif" {
  service_account_id = google_service_account.build_ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.github_wif_member
}

resource "google_service_account_iam_member" "promote_ci_wif" {
  service_account_id = google_service_account.promote_ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.github_wif_member
}

resource "google_project_iam_member" "terraform_ci_editor" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.terraform_ci.email}"
}

resource "google_storage_bucket_iam_member" "terraform_ci_state" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.terraform_ci.email}"
}

resource "google_billing_budget" "platform" {
  count            = var.billing_account_id != "" && var.monthly_budget_usd > 0 ? 1 : 0
  billing_account  = var.billing_account_id
  display_name     = "${local.name_prefix}-monthly-budget"

  budget_filter {
    projects = ["projects/${var.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.monthly_budget_usd)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
  }
}
