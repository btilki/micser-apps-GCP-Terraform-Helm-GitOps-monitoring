variable "project_id" { type = string }
variable "region" { type = string }
variable "cluster_name" { type = string }
variable "network" { type = string }
variable "subnetwork" { type = string }
variable "pods_range_name" { type = string }
variable "services_range_name" { type = string }
variable "kms_key_id" { type = string }

variable "master_authorized_networks" {
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version = "~> 35.0"

  project_id = var.project_id
  name       = var.cluster_name
  region     = var.region

  network           = var.network
  subnetwork        = var.subnetwork
  ip_range_pods     = var.pods_range_name
  ip_range_services = var.services_range_name

  http_load_balancing        = true
  network_policy             = true
  horizontal_pod_autoscaling = true
  enable_private_nodes       = true
  enable_private_endpoint    = false
  master_ipv4_cidr_block     = "172.16.0.0/28"

  master_authorized_networks = var.master_authorized_networks
  node_metadata              = "GKE_METADATA"

  gateway_api_channel                  = "CHANNEL_STANDARD"
  monitoring_enable_managed_prometheus = true
  logging_enabled_components           = ["SYSTEM_COMPONENTS", "WORKLOADS"]

  database_encryption = [{
    state    = "ENCRYPTED"
    key_name = var.kms_key_id
  }]

  node_pools = [{
    name         = "default"
    machine_type = "e2-standard-4"
    min_count    = 1
    max_count    = 3
    auto_upgrade = true
  }]
}

output "cluster_name" {
  value = module.gke.name
}

output "cluster_endpoint" {
  value     = module.gke.endpoint
  sensitive = true
}
