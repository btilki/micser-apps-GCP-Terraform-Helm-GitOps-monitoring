variable "project_id" { type = string }

resource "google_container_analysis_note" "cosign" {
  project = var.project_id
  name    = "boutique-cosign-note"

  attestation_authority {
    hint {
      human_readable_name = "cosign"
    }
  }
}

resource "google_binary_authorization_attestor" "cosign" {
  project     = var.project_id
  name        = "boutique-cosign"
  description = "cosign attestations from GitHub Actions"

  attestation_authority_note {
    note_reference = google_container_analysis_note.cosign.name
  }
}

resource "google_binary_authorization_policy" "policy" {
  project = var.project_id

  admission_whitelist_patterns {
    name_pattern = "gcr.io/google-containers/*"
  }

  default_admission_rule {
    evaluation_mode  = "ALWAYS_ALLOW"
    enforcement_mode = "DRYRUN_AUDIT_LOG_ONLY"
  }
}

output "attestor_id" {
  value = google_binary_authorization_attestor.cosign.id
}

output "attestor_name" {
  value = google_binary_authorization_attestor.cosign.name
}
