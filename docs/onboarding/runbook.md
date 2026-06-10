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
| 7 — Teardown | [phase-07-teardown.md](../implementation/phase-07-teardown.md) |

## Local prerequisites

```bash
brew install google-cloud-sdk terraform kubectl helm jq
gcloud auth login
gcloud auth application-default login
```

## DNS zone (e.g. `boutique.example.com`)

Cloud DNS has **no zone until foundation Terraform runs** (Phase 1 §1.6). Set in `infra/terraform/envs/foundation/terraform.tfvars`:

```hcl
dns_zone_name = "boutique-example-com"
dns_domain    = "boutique.example.com."
```

After `terraform apply`: `terraform output dns_name_servers` → set those four NS records at your domain registrar. Full steps: [phase-01 §1.7](../implementation/phase-01-gcp-and-terraform.md#17-create-the-cloud-dns-zone-and-delegate-your-domain).

**App DNS (after Gateway live):** A records for `argocd`, `dev`, `stage`, and `@` → `gateway_ip`. Argo CD UI: **https://argocd.boutique.example.com** ([phase-04 §4.3](../implementation/phase-04-argocd-and-platform.md#43-expose-argo-cd-ui-at-httpsargocdboutiqueexamplecom)).

## One-page secret reference

| GitHub name | Type | From |
|-------------|------|------|
| `GCP_PROJECT_ID` | variable | GCP console |
| `GCP_REGION` | variable | e.g. `europe-west1` |
| `GCP_WIF_PROVIDER` | secret | bootstrap `terraform output wif_provider` |
| `GCP_TERRAFORM_SA` | secret | bootstrap `terraform output terraform_ci_sa_email` |
| `GCP_BUILD_SA` | secret | bootstrap `terraform output build_ci_sa_email` |
| `GCP_PROMOTE_SA` | secret | bootstrap `terraform output promote_ci_sa_email` |

## Stage / prod deploy order

Promote in this order (backing services **before** frontend). Full steps: [phase-06 §6.2](../implementation/phase-06-promotion.md#62-promote-to-stage) (stage) and [§6.3](../implementation/phase-06-promotion.md#63-promote-to-prod) (prod).

1. `redis-cart`
2. `productcatalogservice`
3. `currencyservice`
4. `cartservice`
5. `frontend`

**Verify stage** (after all five `*-stage` apps are Synced / Healthy):

```bash
kubectl get pods -n stage
bash scripts/smoke.sh https://stage.boutique.example.com
```

**Verify prod** (after manual Argo sync of all `*-prod` apps):

```bash
kubectl get pods -n prod
bash scripts/smoke.sh https://boutique.example.com
```

## Teardown

Full steps: [phase-07-teardown.md](../implementation/phase-07-teardown.md). Quick commands: [cost/teardown.md](../cost/teardown.md).
