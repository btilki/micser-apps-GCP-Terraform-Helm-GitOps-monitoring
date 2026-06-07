# Operator runbook (quick reference)

Full step-by-step instructions: **[docs/implementation/README.md](../implementation/README.md)**.

## Phase index

| Phase | Document |
|-------|----------|
| Overview + checklist | [implementation/README.md](../implementation/README.md) |
| 1 — GCP & Terraform | [phase-01-gcp-and-terraform.md](../implementation/phase-01-gcp-and-terraform.md) |
| 2 — GitHub setup | [phase-02-github-setup.md](../implementation/phase-02-github-setup.md) |
| 3 — GitHub Actions | [phase-03-github-actions.md](../implementation/phase-03-github-actions.md) |
| 4 — Argo CD & platform | [phase-04-argocd-and-platform.md](../implementation/phase-04-argocd-and-platform.md) |
| 5 — First service | [phase-05-first-service.md](../implementation/phase-05-first-service.md) |
| 6 — Promotion | [phase-06-promotion.md](../implementation/phase-06-promotion.md) |

## Local prerequisites

```bash
brew install google-cloud-sdk terraform kubectl helm jq
gcloud auth login
gcloud auth application-default login
```

## DNS zone (e.g. `biroltilki.art`)

Cloud DNS has **no zone until foundation Terraform runs** (Phase 1 §1.6). Set in `infra/terraform/envs/foundation/terraform.tfvars`:

```hcl
dns_zone_name = "biroltilki-art"
dns_domain    = "biroltilki.art."
```

After `terraform apply`: `terraform output dns_name_servers` → set those four NS records at your domain registrar. Full steps: [phase-01 §1.7](../implementation/phase-01-gcp-and-terraform.md#17-create-the-cloud-dns-zone-and-delegate-your-domain).

## One-page secret reference

| GitHub name | Type | From |
|-------------|------|------|
| `GCP_PROJECT_ID` | variable | GCP console |
| `GCP_REGION` | variable | e.g. `europe-west1` |
| `GCP_WIF_PROVIDER` | secret | bootstrap `terraform output wif_provider` |
| `GCP_TERRAFORM_SA` | secret | bootstrap `terraform output terraform_ci_sa_email` |
| `GCP_BUILD_SA` | secret | bootstrap `terraform output build_ci_sa_email` |
| `GCP_PROMOTE_SA` | secret | bootstrap `terraform output promote_ci_sa_email` |

## Teardown

[docs/cost/teardown.md](../cost/teardown.md)
