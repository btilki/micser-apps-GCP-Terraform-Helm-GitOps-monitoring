variable "project_id" { type = string }
variable "zone_name" { type = string }
variable "dns_name" { type = string }

resource "google_dns_managed_zone" "zone" {
  name        = var.zone_name
  dns_name    = var.dns_name
  description = "Public DNS for Online Boutique on GCP"
}

output "zone_name" {
  value = google_dns_managed_zone.zone.name
}

output "name_servers" {
  value = google_dns_managed_zone.zone.name_servers
}
