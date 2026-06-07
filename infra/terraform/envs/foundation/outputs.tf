output "project_id" {
  value = var.project_id
}

output "region" {
  value = var.region
}

output "cluster_name" {
  value = module.gke.cluster_name
}

output "cluster_endpoint" {
  value     = module.gke.cluster_endpoint
  sensitive = true
}

output "gateway_ip" {
  value = google_compute_global_address.gateway.address
}

output "dns_zone_name" {
  value = module.dns.zone_name
}

output "dns_name_servers" {
  value = module.dns.name_servers
}

output "artifact_registry_urls" {
  value = module.artifact_registry.repository_urls
}

output "binary_auth_attestor" {
  value = module.binary_auth.attestor_id
}
