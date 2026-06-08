# Phase 7 — Teardown

Remove the running platform and cloud infrastructure. Follow steps **in order** — teardown is the reverse of Phases 1–6.

**Previous:** [phase-06-promotion.md](phase-06-promotion.md)

> **Warning:** This permanently deletes workloads, cluster data, Artifact Registry images, DNS records managed by Terraform, and (optionally) Terraform state. Take snapshots or export anything you need before starting.

---

## 7.1 Decide scope

| Goal | Stop at |
|------|---------|
| Pause spend but keep Terraform state & WIF | Scale GKE node pool to 0, or delete workloads only (§7.2–7.3) |
| Remove cluster and networking, keep GitHub + state bucket | Foundation `destroy` only (§7.5) |
| Full lab cleanup | Foundation + bootstrap `destroy` (§7.5–7.6) |
| Delete everything including GCP project | §7.7 after Terraform destroy |

Estimated time: 20–60 minutes (GKE and Gateway API load balancers can take 10–15 minutes to release).

---

## 7.2 Stop user traffic (optional)

1. At your domain registrar or Cloud DNS, remove **A records** pointing at the gateway IP (`argocd`, `dev`, `stage`, apex `@`).
2. Confirm traffic has stopped:

```bash
curl -sI https://dev.biroltilki.art || true
curl -sI https://stage.biroltilki.art || true
```

---

## 7.3 Remove cluster workloads

### 7.3.1 Delete Argo CD applications

In the Argo CD UI (**https://argocd.biroltilki.art**) or via CLI:

```bash
# Delete workload apps (dev / stage / prod)
kubectl delete applications -n argocd -l app.kubernetes.io/part-of=online-boutique --ignore-not-found
kubectl delete applications -n argocd boutique-workloads boutique-platform boutique-kyverno-policies --ignore-not-found

# Or delete all ApplicationSets first, then remaining apps
kubectl delete applicationsets -n argocd --all --ignore-not-found
kubectl delete applications -n argocd --all --ignore-not-found
```

Wait until application namespaces are empty:

```bash
kubectl get pods -A | grep -E 'dev|stage|prod|platform|kyverno' || true
```

### 7.3.2 Release Gateway API load balancers

Gateway-backed HTTPRoutes create Google Cloud L7 resources. Delete them **before** destroying the cluster to avoid orphaned forwarding rules.

```bash
kubectl delete httproute --all -A --ignore-not-found
kubectl delete gateway boutique-gateway -n platform --ignore-not-found
kubectl delete namespace dev stage prod platform --ignore-not-found --wait=false
```

Verify no lingering forwarding rules (may take a few minutes):

```bash
gcloud compute forwarding-rules list --global --project=YOUR_PROJECT_ID
gcloud compute url-maps list --project=YOUR_PROJECT_ID
```

Delete any remaining rules whose names reference `k8s` or `boutique` if Terraform destroy later hangs.

### 7.3.3 Remove Helm / manual installs

```bash
# Kyverno (if installed in Phase 4)
helm uninstall kyverno -n kyverno --ignore-not-found
kubectl delete namespace kyverno --ignore-not-found

# Argo CD
kubectl delete namespace argocd --ignore-not-found --wait=false
```

---

## 7.4 Disable GitHub automation (optional)

Prevents CI from pushing images or opening PRs while you tear down GCP:

1. **Settings → Actions → General** — disable workflows, or
2. Delete / rotate secrets: `GCP_WIF_PROVIDER`, `GCP_BUILD_SA`, `GCP_PROMOTE_SA`, `GCP_TERRAFORM_SA`
3. Optionally archive the repository

You can skip this if you plan to delete the GCP project immediately after Terraform destroy.

---

## 7.5 Destroy foundation (GKE, VPC, AR, DNS, Gateway IP, …)

### Prerequisites

```bash
gcloud config set project YOUR_PROJECT_ID
gcloud auth application-default login   # if needed

cd infra/terraform/envs/foundation
terraform init
```

Ensure `kubectl` still works (your IP in `master_authorized_networks`). If not, update `terraform.tfvars` and run `terraform apply` once to refresh access, or run destroy from **GitHub Actions → Terraform workflow** (destroy job) if configured.

### KMS `prevent_destroy`

The etcd encryption key in `infra/terraform/modules/kms/main.tf` has `lifecycle { prevent_destroy = true }`. For a full teardown, temporarily set it to `false`, commit (or edit locally), then destroy:

```bash
# After editing prevent_destroy → false
terraform plan -destroy
terraform destroy
```

If destroy fails on KMS because the key is still in use, ensure the GKE cluster is fully deleted first (`gcloud container clusters list`).

### Destroy command

```bash
terraform -chdir=infra/terraform/envs/foundation destroy
```

**Resources removed include:**

- GKE cluster `gke-boutique`
- VPC, subnets, Cloud NAT, firewall rules
- Artifact Registry repos (`boutique-dev`, `boutique-stage`, `boutique-prod`)
- Cloud DNS managed zone and records
- Global gateway IP `boutique-gateway-ip`
- Certificate Manager map and certificates
- Binary Authorization policy
- KMS key ring (after `prevent_destroy` lifted)

### If destroy fails

| Symptom | Action |
|---------|--------|
| GKE cluster stuck deleting | Check for remaining LoadBalancer / Gateway services: `kubectl get svc -A` |
| Forwarding rule in use | Delete URL maps / target proxies / forwarding rules in Console or `gcloud` |
| DNS zone not empty | Remove remaining record sets not managed by Terraform |
| KMS key prevent destroy | Set `prevent_destroy = false` in KMS module and re-run |
| Quota / dependency timeout | Wait 15 minutes and retry `terraform destroy` |

---

## 7.6 Destroy bootstrap (optional)

Removes the Terraform state bucket, Workload Identity Federation pool, and CI service accounts.

**Before destroy:** empty the state bucket (all versions):

```bash
BUCKET=YOUR_TFSTATE_BUCKET   # e.g. tfstate-msgb-bt-7-2026
gcloud storage rm -r "gs://${BUCKET}/*" --project=YOUR_PROJECT_ID
```

Then:

```bash
terraform -chdir=infra/terraform/envs/bootstrap destroy
```

Keep bootstrap if you plan to reprovision the same project later — only foundation needs repeating.

---

## 7.7 Delete GCP project (optional)

When Terraform completes and you want zero ongoing cost:

```bash
gcloud projects delete YOUR_PROJECT_ID
```

Or in Console: **IAM & Admin → Settings → Shut down**.

This removes billing for the project after the 30-day pending deletion window.

---

## 7.8 Registrar cleanup

If you delegated the domain to Cloud DNS in Phase 1:

1. Remove the **four NS records** at your registrar (or point the domain elsewhere).
2. The Cloud DNS zone is already gone if foundation destroy succeeded.

---

## 7.9 Verify nothing is left billing

```bash
gcloud compute instances list --project=YOUR_PROJECT_ID
gcloud container clusters list --project=YOUR_PROJECT_ID
gcloud compute forwarding-rules list --global --project=YOUR_PROJECT_ID
gcloud artifacts repositories list --project=YOUR_PROJECT_ID --location=YOUR_REGION
gcloud dns managed-zones list --project=YOUR_PROJECT_ID
```

All should return empty (or only unrelated resources).

Check [Cloud Billing → Reports](https://console.cloud.google.com/billing) after 24–48 hours to confirm spend dropped to zero.

---

## Phase 7 checklist

```text
□ Argo CD applications and Gateway/HTTPRoutes deleted
□ Kyverno and argocd namespaces removed (optional but recommended)
□ DNS A records removed at registrar (optional)
□ KMS prevent_destroy lifted (if destroying foundation)
□ terraform destroy — foundation
□ Orphan forwarding rules / URL maps cleaned up (if any)
□ State bucket emptied
□ terraform destroy — bootstrap (optional)
□ GCP project deleted (optional)
□ Billing report shows no cluster/LB charges after 48h
```

---

## Common issues

| Problem | Fix |
|---------|-----|
| `terraform destroy` hangs on GKE | Delete Gateway HTTPRoutes first (§7.3.2); wait for Google L7 cleanup |
| KMS destroy blocked | Temporarily disable `prevent_destroy` in `infra/terraform/modules/kms/main.tf` |
| State bucket not empty | `gcloud storage rm -r gs://BUCKET/**` including old versions |
| Still charged for static IP | `gcloud compute addresses list --global`; release `boutique-gateway-ip` if orphaned |
| Want to rebuild later | Keep bootstrap + state bucket; only run foundation `apply` again from Phase 1 |

---

## Related

- Short cost summary: [../cost/teardown.md](../cost/teardown.md)
- Create order reference: [README.md](README.md) (Phases 0–6)
