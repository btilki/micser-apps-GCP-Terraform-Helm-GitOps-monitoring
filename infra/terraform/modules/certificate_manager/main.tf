variable "project_id" { type = string }
variable "dns_zone_name" { type = string }
variable "domain" {
  description = "Apex domain without trailing dot (e.g. biroltilki.art)"
  type        = string
}
variable "cert_map_name" {
  description = "Must match gitops/platform/gateway.yaml networking.gke.io/certmap"
  type        = string
  default     = "boutique-cert-map"
}

locals {
  wildcard_hostname = "*.${var.domain}"
}

resource "google_certificate_manager_dns_authorization" "apex" {
  name    = "${replace(var.domain, ".", "-")}-dns-auth"
  domain  = var.domain
  project = var.project_id
}

resource "google_dns_record_set" "dns_auth" {
  managed_zone = var.dns_zone_name
  name         = google_certificate_manager_dns_authorization.apex.dns_resource_record[0].name
  type         = google_certificate_manager_dns_authorization.apex.dns_resource_record[0].type
  ttl          = 300
  rrdatas      = [google_certificate_manager_dns_authorization.apex.dns_resource_record[0].data]
}

resource "google_certificate_manager_certificate" "wildcard" {
  name    = "${replace(var.domain, ".", "-")}-wildcard"
  project = var.project_id

  managed {
    domains = [local.wildcard_hostname, var.domain]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.apex.id,
    ]
  }

  depends_on = [google_dns_record_set.dns_auth]
}

resource "google_certificate_manager_certificate_map" "gateway" {
  name        = var.cert_map_name
  description = "TLS for GKE Gateway (${local.wildcard_hostname})"
  project     = var.project_id
}

resource "google_certificate_manager_certificate_map_entry" "wildcard" {
  name         = "wildcard"
  map          = google_certificate_manager_certificate_map.gateway.name
  certificates = [google_certificate_manager_certificate.wildcard.id]
  hostname     = local.wildcard_hostname
  project      = var.project_id
}

resource "google_certificate_manager_certificate_map_entry" "apex" {
  name         = "apex"
  map          = google_certificate_manager_certificate_map.gateway.name
  certificates = [google_certificate_manager_certificate.wildcard.id]
  hostname     = var.domain
  project      = var.project_id
}

output "cert_map_name" {
  value = google_certificate_manager_certificate_map.gateway.name
}

output "certificate_name" {
  value = google_certificate_manager_certificate.wildcard.name
}
