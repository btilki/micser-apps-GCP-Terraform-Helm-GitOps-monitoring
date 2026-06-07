variable "project_id" { type = string }
variable "region" { type = string }
variable "network_name" { type = string }
variable "subnet_name" { type = string }

locals {
  pods_range     = "${var.subnet_name}-pods"
  services_range = "${var.subnet_name}-services"
}

resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "gke" {
  name          = var.subnet_name
  ip_cidr_range = "10.10.0.0/20"
  region        = var.region
  network       = google_compute_network.vpc.id

  private_ip_google_access = true

  secondary_ip_range {
    range_name    = local.pods_range
    ip_cidr_range = "10.20.0.0/16"
  }

  secondary_ip_range {
    range_name    = local.services_range
    ip_cidr_range = "10.30.0.0/20"
  }
}

output "network_name" {
  value = google_compute_network.vpc.name
}

output "subnetwork_name" {
  value = google_compute_subnetwork.gke.name
}

output "pods_range_name" {
  value = local.pods_range
}

output "services_range_name" {
  value = local.services_range
}
