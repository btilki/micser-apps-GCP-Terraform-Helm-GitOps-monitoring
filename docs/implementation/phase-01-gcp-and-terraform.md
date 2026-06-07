# Phase 1 — GCP and Terraform

Create cloud infrastructure: state bucket, GitHub→GCP trust (WIF), VPC, private GKE, Artifact Registry, DNS, gateway IP, KMS, Binary Authorization.

**Previous:** [phase-00-scaffold.md](phase-00-scaffold.md)  
**Next:** [phase-02-github-setup.md](phase-02-github-setup.md)

---

## 1.1 Create or choose a GCP project

1. Open [Google Cloud Console](https://console.cloud.google.com/).
2. Create a project (or use an existing one).
3. Note the **Project ID** (e.g. `msgb-bt-7-2026`) — not the display name.
4. Link a **billing account** to the project.
5. **Choose a domain** for HTTPS later (e.g. `biroltilki.art`). Register it at your registrar if you do not own it yet.

> **Cloud DNS shows no zone yet?** That is expected until **§1.6 foundation Terraform** runs. This repo creates the managed zone automatically — you do not create it manually in the Console first.

---

## 1.2 Install local tools

```bash
# macOS
brew install google-cloud-sdk terraform kubectl helm jq

gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

Verify:

```bash
terraform version   # >= 1.5
kubectl version --client
helm version
```

---

## 1.3 Enable GCP APIs

Run once per project:

```bash
gcloud services enable \
  compute.googleapis.com \
  container.googleapis.com \
  artifactregistry.googleapis.com \
  dns.googleapis.com \
  cloudkms.googleapis.com \
  binaryauthorization.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com \
  serviceusage.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com \
  --project=YOUR_PROJECT_ID
```

---

## 1.4 Bootstrap Terraform

**Creates:** Google Cloud Storage (GCS) state bucket, Workload Identity Federation pool/provider, service accounts (`sa-terraform-ci`, `sa-build-ci`, `sa-promote-ci`).

```bash
cd infra/terraform/envs/bootstrap
cp terraform.tfvars.example terraform.tfvars   # never commit this file
```

Edit `terraform.tfvars`:

| Variable | Description |
|----------|-------------|
| `project_id` | Your GCP project ID |
| `region` | e.g. `europe-west1` |
| `tfstate_bucket_name` | Globally unique bucket name |
| `github_org` | GitHub username or organization |
| `github_repo` | Repository name (default `Microservices-Google`) |

```bash
terraform init
terraform plan
terraform apply
```

**Save outputs** (needed in Phase 2):

```bash
terraform output tfstate_bucket
terraform output wif_provider
terraform output terraform_ci_sa_email
terraform output build_ci_sa_email
terraform output promote_ci_sa_email
```

---

## 1.5 Migrate state to Google Cloud Storage (GCS) — recommended

Edit `infra/terraform/envs/bootstrap/versions.tf` — uncomment and set the backend block:

```hcl
backend "gcs" {
  bucket = "YOUR_TFSTATE_BUCKET_NAME"
  prefix = "bootstrap"
}
```

```bash
terraform init -migrate-state
```

Repeat for foundation after Phase 1.6 (`prefix = "foundation"` in `infra/terraform/envs/foundation/versions.tf`).

---

## 1.6 Foundation Terraform

**Creates:** VPC, private GKE (Gateway API + Managed Prometheus), 3 Artifact Registry repos (`boutique-dev`, `boutique-stage`, `boutique-prod`), Cloud DNS zone, gateway static IP, KMS etcd encryption, Binary Authorization attestor.

```bash
cd ../foundation
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
project_id = "your-project-id"
region     = "europe-west1"

build_ci_sa_email   = "sa-build-ci@your-project-id.iam.gserviceaccount.com"
promote_ci_sa_email = "sa-promote-ci@your-project-id.iam.gserviceaccount.com"

# Cloud DNS managed zone (created by this apply)
dns_zone_name = "biroltilki-art"   # GCP resource name (lowercase, hyphens OK)
dns_domain    = "biroltilki.art."  # your domain — trailing dot required
```

| Variable | Example | Meaning |
|----------|---------|---------|
| `dns_domain` | `biroltilki.art.` | Public DNS name served by Cloud DNS |
| `dns_zone_name` | `biroltilki-art` | Internal GCP name for the managed zone (not visible to users) |

App hostnames used later in GitOps (Phase 2): `dev.biroltilki.art`, `stage.biroltilki.art`, `biroltilki.art` (prod).

**Recommended:** restrict GKE control plane to your IP:

```bash
curl -s ifconfig.me   # note your public IP
```

```hcl
master_authorized_networks = [
  { cidr_block = "YOUR.PUBLIC.IP/32", display_name = "home" }
]
```

```bash
terraform init
terraform plan    # review carefully — creates billable resources
terraform apply     # ~15–20 minutes (GKE is slow)
```

**Save outputs:**

```bash
terraform output gateway_ip
terraform output dns_zone_name
terraform output dns_name_servers
terraform output cluster_name
terraform output -json artifact_registry_urls
```

Validate locally anytime:

```bash
make validate
make tf-bootstrap-plan
make tf-foundation-plan
```

---

## 1.7 Create the Cloud DNS zone and delegate your domain

Foundation Terraform (§1.6) creates a **Cloud DNS managed zone** for your domain. Until that `terraform apply` finishes, **Network Services → Cloud DNS** in the Console will show no zones — that is normal.

### After foundation apply — verify the zone

**Console:** [Cloud DNS](https://console.cloud.google.com/net-services/dns/zones) → you should see a zone named `biroltilki-art` (or your `dns_zone_name`) for DNS name `biroltilki.art.`

**CLI:**

```bash
gcloud dns managed-zones list --project=YOUR_PROJECT_ID
terraform output dns_name_servers
```

Copy the four **Cloud DNS name servers** (e.g. `ns-cloud-a1.googledomains.com.` …).

### Delegate at your registrar

At whoever hosts **`biroltilki.art`** (Google Domains, Cloudflare, Namecheap, etc.):

1. Open **DNS** / **Name servers** for the domain.
2. Switch to **custom name servers** (not the registrar’s default DNS).
3. Paste all four Cloud DNS name servers from the step above.
4. Save. Propagation can take from a few minutes up to 48 hours.

You are delegating the **apex** domain (`biroltilki.art`), so all subdomains (`dev.`, `stage.`, …) are managed in Cloud DNS once delegation works.

### App records (after Phase 4 — Gateway live)

Create **A records** in the Cloud DNS zone pointing to `gateway_ip` from Terraform:

| Record name | Type | Value |
|-------------|------|--------|
| `dev` | A | `terraform output -raw gateway_ip` |
| `stage` | A | same gateway IP |
| `@` (apex) | A | same gateway IP |

In the Console: open the managed zone → **Add record set**. Or use `gcloud dns record-sets create`.

**No domain yet?** Leave `dns_domain` at the default in `terraform.tfvars.example`, or skip delegation and continue through Phase 4 — add DNS/TLS when you have a domain.

---

## 1.8 Connect kubectl to GKE

```bash
gcloud container clusters get-credentials gke-boutique \
  --region YOUR_REGION \
  --project YOUR_PROJECT_ID

kubectl get nodes
```

Or from repo root after foundation apply:

```bash
make kubeconfig GCP_REGION=your-region
```

---

## Phase 1 checklist

```text
□ GCP project + billing
□ Local tools installed and authenticated
□ APIs enabled
□ bootstrap terraform apply — outputs saved
□ Google Cloud Storage (GCS) backend configured (bootstrap)
□ foundation terraform apply — outputs saved
□ kubectl get nodes succeeds
□ Cloud DNS managed zone exists (foundation apply)
□ Registrar name servers point to Cloud DNS (if using custom domain)
```

---

## Common issues

| Problem | Fix |
|---------|-----|
| `terraform apply` API not enabled | Re-run `gcloud services enable` from §1.3 |
| GKE create fails | Check billing, quotas, and `master_authorized_networks` includes your IP |
| `kubectl` connection timeout | Your IP changed or is not in `master_authorized_networks` |
| Bucket name taken | Choose another globally unique `tfstate_bucket_name` |
