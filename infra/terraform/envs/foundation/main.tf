locals {
  name_prefix = "boutique"
  labels = {
    platform = "microservices-google"
    managed  = "terraform"
  }
  ar_repos = ["boutique-dev", "boutique-stage", "boutique-prod"]
}

module "network" {
  source = "../../modules/network"

  project_id   = var.project_id
  region       = var.region
  network_name = "${local.name_prefix}-vpc"
  subnet_name  = "${local.name_prefix}-gke"
}

module "kms" {
  source = "../../modules/kms"

  project_id = var.project_id
  region     = var.region
  key_ring   = "${local.name_prefix}-gke"
  crypto_key = "etcd-secrets"
}

data "google_project" "current" {
  project_id = var.project_id
}

module "gke" {
  source = "../../modules/gke"

  project_id                 = var.project_id
  region                     = var.region
  cluster_name               = var.cluster_name
  network                    = module.network.network_name
  subnetwork                 = module.network.subnetwork_name
  pods_range_name            = module.network.pods_range_name
  services_range_name        = module.network.services_range_name
  master_authorized_networks = var.master_authorized_networks
  kms_key_id                 = module.kms.crypto_key_id
}

resource "google_kms_crypto_key_iam_member" "gke_etcd_encryption" {
  crypto_key_id = module.kms.crypto_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@container-engine-robot.iam.gserviceaccount.com"
}

module "dns" {
  source = "../../modules/dns"

  project_id = var.project_id
  zone_name  = var.dns_zone_name
  dns_name   = var.dns_domain
}

resource "google_compute_global_address" "gateway" {
  name         = "${local.name_prefix}-gateway-ip"
  address_type = "EXTERNAL"
  labels       = local.labels
}

module "artifact_registry" {
  source = "../../modules/artifact_registry"

  project_id = var.project_id
  region     = var.region
  repos      = local.ar_repos
}

module "binary_auth" {
  source = "../../modules/binary_auth"

  project_id = var.project_id
}

resource "google_artifact_registry_repository_iam_member" "build_ci_writer_dev" {
  project    = var.project_id
  location   = var.region
  repository = "boutique-dev"
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.build_ci_sa_email}"
}

resource "google_artifact_registry_repository_iam_member" "promote_ci_reader_dev" {
  project    = var.project_id
  location   = var.region
  repository = "boutique-dev"
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.promote_ci_sa_email}"
}

resource "google_artifact_registry_repository_iam_member" "promote_ci_writer_stage" {
  project    = var.project_id
  location   = var.region
  repository = "boutique-stage"
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.promote_ci_sa_email}"
}

resource "google_artifact_registry_repository_iam_member" "promote_ci_reader_stage" {
  project    = var.project_id
  location   = var.region
  repository = "boutique-stage"
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.promote_ci_sa_email}"
}

resource "google_artifact_registry_repository_iam_member" "promote_ci_writer_prod" {
  project    = var.project_id
  location   = var.region
  repository = "boutique-prod"
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.promote_ci_sa_email}"
}

resource "google_binary_authorization_attestor_iam_member" "build_ci_attestor" {
  project  = var.project_id
  attestor = module.binary_auth.attestor_name
  role     = "roles/binaryauthorization.attestorsEditor"
  member   = "serviceAccount:${var.build_ci_sa_email}"
}
