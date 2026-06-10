# Phase 2 — GitHub repository setup

Create the GitHub repo, push code, replace placeholders, and configure environments, variables, and secrets.

**Previous:** [phase-01-gcp-and-terraform.md](phase-01-gcp-and-terraform.md)  
**Next:** [phase-03-github-actions.md](phase-03-github-actions.md)

---

## 2.1 Create the repository

1. GitHub → **New repository**.
2. Name it `Microservices-Google` (or update `github_repo` in bootstrap `terraform.tfvars` if different).
3. Do **not** add README/license if you already have local code.

Push from your machine:

```bash
cd /path/to/Microservices-Google
git remote add origin https://github.com/YOUR_ORG/Microservices-Google.git
git branch -M main
git add .
git commit -m "Initial platform scaffold"
git push -u origin main
```

---

## 2.2 Replace placeholders in the repo

Argo CD and Kyverno need real values before cluster sync.

| Placeholder | Replace with | Example |
|-------------|--------------|---------|
| `YOUR_GITHUB_ORG` | GitHub user or org | `acme-corp` |
| `YOUR_PROJECT_ID` | GCP project ID | `boutique-dev-123456` |
| `YOUR_REGION` | GCP region in AR image URLs | `europe-west1` |
| `YOUR_TFSTATE_BUCKET` | GCS bucket for Terraform state | `tfstate-boutique-123456` |
| `boutique.example.com` | Your public domain | `shop.acme.com` |
| `boutique-example-com` | Cloud DNS managed zone name | `shop-acme-com` |

**Hostnames:** `argocd.boutique.example.com` (Argo CD), `dev.boutique.example.com`, `stage.boutique.example.com`, `boutique.example.com` (prod).

**Files to update:**

| Path | What to fix |
|------|-------------|
| `gitops/bootstrap/**/*.yaml` | `repoURL: https://github.com/YOUR_GITHUB_ORG/...` |
| `infra/terraform/envs/*/versions.tf` | `backend "gcs"` bucket name |
| `gitops/applicationsets/boutique-services-*.yaml` | `repoURL` |
| `gitops/envs/**/values-*.yaml` | `image.repository` AR URLs |
| `policies/kyverno/restrict-image-registries.yaml` | registry pattern |
| `gitops/platform/gateway.yaml` | hostnames, cert map |
| `charts/*/values.yaml` | default image repository paths (optional) |

Quick search from repo root:

```bash
rg "YOUR_GITHUB_ORG|YOUR_PROJECT_ID|YOUR_TFSTATE_BUCKET|boutique.example.com" --glob '!*.lock'
```

Commit and push:

```bash
git add -A
git commit -m "chore: replace GCP and GitHub placeholders"
git push
```

---

## 2.3 Create GitHub Environments

**Settings → Environments → New environment**

| Environment | Purpose | Suggested rules |
|-------------|---------|-----------------|
| `build` | Docker build, Trivy, push to dev AR | None initially |
| `terraform` | Terraform plan/apply from CI | Required reviewers for deployments |
| `prod` | Promotion to prod AR + GitOps | Required reviewers |

---

## 2.4 Repository variables (non-secret)

**Settings → Secrets and variables → Actions → Variables → New repository variable**

| Name | Value |
|------|-------|
| `GCP_PROJECT_ID` | your GCP project ID |
| `GCP_REGION` | e.g. `europe-west1` |

These are used by CI workflows (`vars.GCP_PROJECT_ID`).

---

## 2.5 Repository secrets

**Settings → Secrets and variables → Actions → Secrets → New repository secret**

Use values from Phase 1 bootstrap `terraform output`:

| Secret | Source |
|--------|--------|
| `GCP_WIF_PROVIDER` | `terraform output wif_provider` |
| `GCP_TERRAFORM_SA` | `terraform output terraform_ci_sa_email` |
| `GCP_BUILD_SA` | `terraform output build_ci_sa_email` |
| `GCP_PROMOTE_SA` | `terraform output promote_ci_sa_email` |

**Optional** (Environment `build` only, for cosign):

| Secret | Purpose |
|--------|---------|
| `COSIGN_PRIVATE_KEY` | Image signing |
| `COSIGN_PASSWORD` | Key password if set |

---

## 2.6 Branch protection (recommended)

**Settings → Branches → Add branch protection rule** for `main`:

- Require a pull request before merging
- Require status checks to pass (enable after first workflow runs)
- Include administrators (optional)

Update [CODEOWNERS](../../CODEOWNERS): replace `@platform-owners` with your GitHub username for prod paths.

---

## Phase 2 checklist

```text
□ Repository created on GitHub
□ Code pushed to main
□ ORG, PROJECT_ID, REGION replaced and pushed
□ Environments build, terraform, prod created
□ Variables GCP_PROJECT_ID, GCP_REGION set
□ All four GCP_* secrets set
□ Branch protection configured (recommended)
```

---

## Common issues

| Problem | Fix |
|---------|-----|
| WIF auth fails later in Actions | `github_org` / `github_repo` in bootstrap must match this repo exactly |
| Private repo + Argo can't clone | Add deploy key or connect GitHub App in Argo CD (Phase 4) |
