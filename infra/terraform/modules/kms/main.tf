variable "project_id" { type = string }
variable "region" { type = string }
variable "key_ring" { type = string }
variable "crypto_key" { type = string }

resource "google_kms_key_ring" "ring" {
  name     = var.key_ring
  location = var.region
}

resource "google_kms_crypto_key" "key" {
  name     = var.crypto_key
  key_ring = google_kms_key_ring.ring.id

  rotation_period = "7776000s"
}

output "crypto_key_id" {
  value = google_kms_crypto_key.key.id
}
