variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "cluster_name" {
  type    = string
  default = "gke-boutique"
}

variable "dns_zone_name" {
  type    = string
  default = "boutique-example-com"
}

variable "dns_domain" {
  type    = string
  default = "boutique.example.com."
}

variable "cert_map_name" {
  description = "Certificate Manager map name; must match gitops/platform/gateway.yaml networking.gke.io/certmap"
  type        = string
  default     = "boutique-cert-map"
}

variable "build_ci_sa_email" {
  description = "From bootstrap output"
  type        = string
}

variable "promote_ci_sa_email" {
  description = "From bootstrap output"
  type        = string
}

variable "master_authorized_networks" {
  description = "CIDR blocks allowed to reach the GKE control plane"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}
