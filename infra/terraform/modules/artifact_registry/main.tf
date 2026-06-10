variable "project_id" { type = string }
variable "region" { type = string }
variable "repos" { type = list(string) }

resource "google_artifact_registry_repository" "repos" {
  for_each = toset(var.repos)

  project       = var.project_id
  location      = var.region
  repository_id = each.value
  format        = "DOCKER"
  description   = "Online Boutique images (${each.value})"

  vulnerability_scanning_config {
    enablement_config = "INHERITED"
  }
}

output "repository_urls" {
  value = {
    for k, r in google_artifact_registry_repository.repos :
    k => "${var.region}-docker.pkg.dev/${var.project_id}/${r.repository_id}"
  }
}
