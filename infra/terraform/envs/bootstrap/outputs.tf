output "tfstate_bucket" {
  value = google_storage_bucket.tfstate.name
}

output "wif_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}

output "terraform_ci_sa_email" {
  value = google_service_account.terraform_ci.email
}

output "build_ci_sa_email" {
  value = google_service_account.build_ci.email
}

output "promote_ci_sa_email" {
  value = google_service_account.promote_ci.email
}
