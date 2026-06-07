variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Primary GCP region"
  type        = string
  default     = "europe-west1"
}

variable "tfstate_bucket_name" {
  description = "Globally unique GCS bucket for Terraform state"
  type        = string
}

variable "github_org" {
  description = "GitHub organization or user that owns the repository"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "Microservices-Google"
}

variable "billing_account_id" {
  description = "Optional billing account for budget alerts"
  type        = string
  default     = ""
}

variable "monthly_budget_usd" {
  description = "Monthly budget alert threshold in USD (0 disables)"
  type        = number
  default     = 250
}
