# Phase 3 — GitHub Actions

Understand workflows, verify GCP authentication, and run your first CI and Terraform jobs.

**Previous:** [phase-02-github-setup.md](phase-02-github-setup.md)  
**Next:** [phase-04-argocd-and-platform.md](phase-04-argocd-and-platform.md)

---

## 3.1 Workflows in this repo

| File | Trigger | Purpose |
|------|---------|---------|
| [`.github/workflows/terraform.yml`](../../.github/workflows/terraform.yml) | Push to `infra/terraform/**`, or **manual** | fmt, validate, tfsec, checkov, trivy config; plan/apply |
| [`.github/workflows/reusable-service-ci.yml`](../../.github/workflows/reusable-service-ci.yml) | Called by service workflows | Build → syft → Trivy → push → cosign → GitOps PR |
| [`.github/workflows/ci-frontend.yml`](../../.github/workflows/ci-frontend.yml) | Push to `apps/frontend/**`, or manual | Runs reusable CI for `frontend` |
| `ci-cartservice.yml`, `ci-currencyservice.yml`, etc. | Same pattern | One workflow per owned service |
| [`.github/workflows/promote.yml`](../../.github/workflows/promote.yml) | **Manual only** | Copy image between AR repos; GitOps PR |

Service build paths are defined in [`scripts/services.json`](../../scripts/services.json).

---

## 3.2 How Actions authenticates to GCP (no JSON keys)

```text
GitHub Actions job starts
  → permissions: id-token: write
  → google-github-actions/auth exchanges OIDC token with GCP WIF
  → GCP returns short-lived credentials for the target service account
  → job runs gcloud / docker push / terraform
```

| Workflow | Service account secret | Can do |
|----------|------------------------|--------|
| `terraform.yml` | `GCP_TERRAFORM_SA` | Terraform plan/apply, GCS state |
| `reusable-service-ci.yml` | `GCP_BUILD_SA` | Push images to `boutique-dev` only |
| `promote.yml` | `GCP_PROMOTE_SA` | Copy images dev→stage→prod |

WIF trust is scoped to your repository by bootstrap Terraform (`attribute_condition` on `github_org/github_repo`).

---

## 3.3 Run Terraform workflow (verify wiring)

1. GitHub → **Actions** → **Terraform**.
2. **Run workflow** → branch `main`:
   - `stack`: `foundation`
   - `action`: `plan`
3. Confirm the job completes and shows a plan (or no changes if you already applied locally).

To apply from CI (optional):

- `action`: `apply`
- Requires approval if `terraform` environment has protection rules.

You can manage infrastructure entirely from your laptop (`terraform apply`) and use this workflow only for validation — both are valid.

---

## 3.4 Enable PR creation from Actions (one-time)

Service CI opens a GitOps pull request at the end of each run (`peter-evans/create-pull-request`). By default, the `GITHUB_TOKEN` cannot create PRs until you enable this at the repository level.

**Settings → Actions → General** → scroll to **Workflow permissions**:

1. Select **Read and write permissions**
2. Check **Allow GitHub Actions to create and approve pull requests**
3. Click **Save**

The workflows already declare `contents: write` and `pull-requests: write`; this repo setting is still required or the **Open GitOps PR** step fails with:

`GitHub Actions is not permitted to create or approve pull requests`

---

## 3.5 Run first service CI (`frontend`)

**Prerequisites:**

- Phase 1 foundation applied (Artifact Registry `boutique-dev` exists)
- [§3.4](#34-enable-pr-creation-from-actions-one-time) workflow PR setting enabled

1. **Actions** → **CI frontend** → **Run workflow**.
2. Watch the job steps:
   - Authenticate to GCP
   - `docker build` from `apps/frontend/`
   - syft SBOM (artifact upload)
   - Trivy scan (fails on HIGH/CRITICAL)
   - Push to `REGION-docker.pkg.dev/PROJECT_ID/boutique-dev/frontend:SHA`
   - Patch `gitops/envs/dev/values-frontend.yaml` with digest
   - Open a pull request

3. **Review and merge the PR** — this is the GitOps change for dev.

Repeat for other services when ready (`CI cartservice`, etc.).

---

## 3.6 What CI does *not* do

- CI does **not** `kubectl apply` to the cluster.
- CI does **not** deploy to stage/prod directly — use [phase-06-promotion.md](phase-06-promotion.md).
- Argo CD reads merged GitOps files and syncs Helm releases (Phase 4+).

---

## Phase 3 checklist

```text
□ Terraform workflow plan succeeds on GitHub
□ Workflow permissions: read/write + allow Actions to create PRs (§3.4)
□ CI frontend workflow completes (or Trivy issues understood/fixed)
□ GitOps PR for dev/values-frontend.yaml merged
□ Image visible in Artifact Registry console (boutique-dev/frontend)
```

---

## Common issues

| Problem | Fix |
|---------|-----|
| `google-github-actions/auth` failed | Check `GCP_WIF_PROVIDER` and SA email secrets; repo name matches bootstrap |
| `denied: Permission "artifactregistry.repositories.uploadArtifacts"` | `sa-build-ci` needs writer on `boutique-dev` (foundation IAM) |
| Trivy blocks build | Fix CVEs in base image or Dockerfile; or temporarily adjust severity while learning |
| No PR created / `not permitted to create or approve pull requests` | Enable [§3.4](#34-enable-pr-creation-from-actions-one-time); workflows already set `contents: write` and `pull-requests: write` |
| `docker build` timeout | .NET/Go builds can be slow on free runners — re-run or use larger runner |
