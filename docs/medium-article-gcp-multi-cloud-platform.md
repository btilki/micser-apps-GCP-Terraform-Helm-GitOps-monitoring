# I Built the Same Microservices Platform Three Times. GCP Was the Weird One.

*GitHub Actions **does not** `kubectl apply` workloads — Argo CD does. OIDC → Workload Identity Federation replaces long-lived GCP keys.*

---

If you have ever tried to prove you can run a production-style platform on more than one cloud, you hit the same wall: the **patterns** transfer (IaC, CI, GitOps, observability), but the **products** do not. Load balancers, identity, registries, and ingress controllers all have different names, different defaults, and different sharp edges.

Over the past year I built three sibling repositories around the same idea — run [Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo) on Kubernetes with Terraform, GitOps, and digest-based promotion — once on each hyperscaler:

| Project | Repository |
|---------|------------|
| **GCP (this repo)** | [micser-apps-GCP-Terraform-Helm-GitOps-monitoring](https://github.com/btilki/micser-apps-GCP-Terraform-Helm-GitOps-monitoring) |
| **AWS** | [micser-apps-AWS-Terraform-Helm-GitOps-monitoring](https://github.com/btilki/micser-apps-AWS-Terraform-Helm-GitOps-monitoring) |
| **Azure** | [micser-apps-Azure-Terraform-Helm-GitOps-monitoring](https://github.com/btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring) |

This article focuses on the **GCP** implementation and compares it to the AWS and Azure versions in my GitHub repos — same reference architecture, three different product choices.

> *The patterns transfer. The products do not.*

---

## The problem I was solving

Online Boutique is a useful reference app: gRPC backends, a web frontend, Redis, and enough cross-service traffic to stress networking and deployment order. It is not enough to `kubectl apply` a YAML bundle and call it a day.

I wanted each repo to demonstrate:

1. **Infrastructure as code** with remote state and CI-friendly credentials — no long-lived keys in Git.
2. **Immutable deployments** — images pinned by digest, promoted across environments without rebuilding.
3. **GitOps** — cluster state driven from Git, with prod gated behind review and manual sync.
4. **Edge HTTPS** on a real hostname.
5. **Supply-chain and runtime guardrails** appropriate for a portfolio lab that still reads like senior platform engineering work.

The GCP repo is the most recent iteration. It benefits from lessons learned on AWS and Azure, and it leans into services that only exist (or work best) on Google Cloud.

On AWS I pinned upstream demo images at v0.10.4 in a single Helm chart. On GCP I vendored the full microservices-demo source into `apps/` and wired per-service GitHub Actions. The AWS repo deploys a chart; the GCP repo builds, scans, signs, and opens GitOps PRs for the services it owns.

---

## GCP architecture in one picture

The GCP platform is **cost-first**: one project, one **private GKE** cluster, three workload namespaces (`dev`, `stage`, `prod`), plus platform namespaces for Argo CD and shared ingress.

```text
GitHub Actions (OIDC → Workload Identity Federation)
        │
        ▼
  Artifact Registry (boutique-dev, boutique-stage, boutique-prod)
        │
        ▼
  Argo CD ApplicationSets → Helm charts → GKE namespaces
        │
        ▼
  Gateway API (global L7) + Certificate Manager → https://*.biroltilki.art
        │
        ▼
  Managed Prometheus + Cloud Logging
```

**Bootstrap Terraform** creates the GCS state bucket, WIF pool, and service accounts (`sa-terraform-ci`, `sa-build-ci`, `sa-promote-ci`). **Foundation Terraform** creates the VPC, Cloud NAT, private GKE, three Artifact Registry repos, Cloud DNS, a static gateway IP, KMS encryption for etcd, and a Binary Authorization attestor.

That split mirrors the AWS and Azure repos: bootstrap trust and state first, then the cluster and shared platform.

**Auth model:** GitHub Actions uses **OIDC → Workload Identity Federation**. `sa-build-ci` pushes to `boutique-dev` only; `sa-promote-ci` copies digests between registries; `sa-terraform-ci` owns foundation. GitHub Actions builds and scans images, pushes to Artifact Registry, and opens PRs to update digests. It **does not** `kubectl apply` workloads — Argo CD does. No long-lived GCP JSON keys in GitHub.

> *Bootstrap trust and state first. Then the cluster.*

---

## What makes the GCP repo different

### 1. Real application source, not placeholder images

On AWS I pinned **upstream demo images** in a single Helm chart. On Azure I started from **scaffold build contexts** and per-service charts.

On GCP I vendored the actual microservices-demo source into `apps/` — Go frontend and catalog, .NET cart, Node currency, Redis — and wired **one reusable GitHub Actions workflow** per service. A push to `apps/frontend/` runs the reusable workflow: build, syft SBOM, Trivy scan, push to `boutique-dev`, cosign sign, Binary Authorization attestation, then opens a GitOps PR updating `gitops/envs/dev/values-frontend.yaml`. Argo CD syncs `frontend-dev` after the merge.

### 2. GitHub Actions + Workload Identity Federation

| Cloud | CI system | Cloud auth |
|-------|-----------|------------|
| AWS | GitLab CI | OIDC → IAM role |
| Azure | Azure DevOps | Service connection / federated creds |
| **GCP** | **GitHub Actions** | **OIDC → WIF → GCP SA** |

Short-lived credentials only. `sa-build-ci` can push to `boutique-dev`; `sa-promote-ci` can copy images between registries; `sa-terraform-ci` owns foundation. No JSON keys in GitHub secrets.

### 3. Gateway API instead of NGINX or ALB

Azure uses **NGINX Ingress**, cert-manager, and external-dns on Azure DNS — a familiar pattern, but you operate the ingress controller yourself.

AWS uses **ALB + ACM** via the AWS Load Balancer Controller — solid, but AWS-specific manifest glue.

On GCP I chose **GKE Gateway API** (`gke-l7-global-external-managed`) with a Certificate Manager **cert map** on the Gateway. HTTPRoutes attach per environment (`dev.biroltilki.art`, `stage.biroltilki.art`, apex `biroltilki.art`). One global IP, TLS managed in GCP-native services. **Rejected:** NGINX Ingress (the Azure pattern) — not the GCP-native default. **Trade-off:** you learn Gateway API and cert maps, not Ingress annotations.

**Promote and merge backing services before the frontend**, or the storefront returns HTTP 500/503 when gRPC upstreams are missing. I hit this in the stage environment: frontend pods were Running, but `lookup currencyservice` timed out because currency and catalog had not been promoted yet. Deploy order: redis → catalog → currency → cart → frontend.

### 4. Managed observability vs self-hosted Prometheus

Both AWS and Azure deploy **kube-prometheus-stack** (Prometheus, Grafana, Alertmanager) through Argo CD or Helm bootstrap.

On GCP I enabled **GKE Managed Prometheus** and configured **Cloud Logging** for log search. That removes a heavy in-cluster monitoring stack and fits the cost-first design — at the expense of Grafana dashboards you must build yourself in Cloud Console or downstream tools. **Rejected:** self-hosted kube-prometheus-stack on the cluster (the AWS/Azure pattern).

### 5. GitOps shape: ApplicationSet matrix

| Repo | GitOps pattern |
|------|----------------|
| AWS | Argo CD apps + **overlays** (`deploy/argocd/`) |
| Azure | **App-of-apps** under `gitops/bootstrap/` |
| **GCP** | **Two ApplicationSets** — auto-sync for dev/stage, manual sync for prod |

The ApplicationSet generates `frontend-dev`, `cartservice-stage`, and so on from an env × service matrix. Prod apps intentionally **do not** auto-sync; you merge a promotion PR, then sync in the Argo CD UI.

### 6. Promotion without rebuilding

All three repos share the same promotion model:

```text
Build once in dev → copy image by digest → update GitOps values → Argo syncs
```

| Cloud | Copy mechanism |
|-------|----------------|
| AWS | ECR / image promotion patterns in GitLab pipeline |
| Azure | `az acr import` between dev/stage/prod ACRs |
| **GCP** | **`gcrane cp`** between Artifact Registry repos (`promote.yml`) |

On GCP, `gcloud artifacts docker images copy` is not available in recent gcloud SDK releases; `gcrane` is the registry-to-registry path that works. The workflow opens a PR; stage auto-syncs; prod waits for manual Argo sync and optional GitHub Environment approval.

- **No rebuild on promote** — same digest, different Artifact Registry repo.
- **`stage`:** auto-sync after PR merge.
- **`prod`:** manual Argo Sync + GitHub `prod` environment approval on the promote workflow.

A promotion copies `frontend` at digest `sha256:abc123…` from `boutique-dev` to `boutique-stage`. The Git diff is a one-line digest change in YAML.

### 7. Supply chain on GCP

The reusable CI workflow runs **syft** (SBOM), **Trivy** (fail on HIGH/CRITICAL), **cosign** sign, and creates **Binary Authorization** attestations. **Kyverno** enforces digest-only images and registry allowlists at admission time. Of the three siblings, this repo has the deepest supply-chain stack — aligned with GCP’s Binary Authorization model.

> *No rebuild on promote — same digest, different Artifact Registry repo.*

---

## Side-by-side comparison

| Topic | [AWS](https://github.com/btilki/micser-apps-AWS-Terraform-Helm-GitOps-monitoring) | [Azure](https://github.com/btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring) | [GCP](https://github.com/btilki/micser-apps-GCP-Terraform-Helm-GitOps-monitoring) |
|-------|-----|-------|-----|
| **Kubernetes** | EKS | AKS | Private GKE |
| **CI** | GitLab | Azure DevOps | GitHub Actions |
| **Registry** | ECR (pattern in repo) | 3× ACR per env | 3× Artifact Registry |
| **Ingress / TLS** | ALB + ACM | NGINX + cert-manager + external-dns | Gateway API + Certificate Manager |
| **Metrics** | kube-prometheus-stack | kube-prometheus-stack | Managed Prometheus |
| **Logs** | CloudWatch / cluster | Log Analytics | Cloud Logging |
| **Helm layout** | Single `online-boutique` chart | Per-service charts | Library chart + per-service charts |
| **App images** | Upstream demo digests | Scaffold / build contexts | Full demo source in `apps/` |
| **GitOps** | Static apps + overlays | App-of-apps | ApplicationSet (env × service) |
| **Prod deploy** | Manual / gated | Manual Argo sync | Manual Argo sync + GitHub `prod` env |
| **Notable extras** | IRSA, LBC bootstrap | Key Vault CSI, Helm-first platform | WIF, Binary Auth, Kyverno, gcrane promote |

I also maintain lighter **multi-env IaC** repos ([aws-multi-env-iac](https://github.com/btilki/aws-multi-env-iac), [azure-multi-env-iac](https://github.com/btilki/azure-multi-env-iac)) for Terraform-only foundations. The three `micser-apps-*` repos are the full application + GitOps + observability stacks.

The ingress/TLS row alone shows the point: ALB + ACM on AWS, NGINX + cert-manager on Azure, Gateway API + Certificate Manager on GCP — same user-facing requirement, three operational models.

---

## War stories that only showed up on GCP

| Problem | Fix |
|---------|-----|
| **ImagePullBackOff** | GKE node service accounts need `roles/artifactregistry.reader`. Terraform had granted CI write access; the node pool still could not pull. |
| **CreateContainerConfigError** | Pod Security `runAsNonRoot: true` without `runAsUser` breaks distroless and Redis images. Dev values needed explicit UIDs (`runAsUser: 65532` on frontend); stage and prod inherited the same overrides. |
| **Stage 503 / frontend HTTP 500** | Promote backing services before the frontend. Check frontend logs for `lookup currencyservice` DNS errors. Order: redis → catalog → currency → cart → frontend. |
| **Apex HTTPS 404** | Wildcard listener `*.biroltilki.art` does not match apex `biroltilki.art`. Add a second Gateway listener (`https-apex`) and wait for cert propagation. |
| **Smoke test fails in promote workflow** | `smoke.sh` in `promote.yml` runs before the PR merges and Argo syncs. Run smoke after deploy instead; keep `run_smoke_test: false` in the workflow until all target apps are synced. |

These are documented in the phased implementation guide under `docs/implementation/` — seven phases from Terraform through teardown. Run Phase 7 when the lab is finished; see `docs/cost/teardown.md` for cost notes (roughly **$110–235/month** for one private GKE cluster).

> *Wildcard `*.biroltilki.art` does not match the apex.*

---

## Who is this for?

- **Platform engineers** comparing cloud-native ingress and identity models.
- **DevOps practitioners** building a portfolio repo with real CI/CD and GitOps, not a tutorial that stops at `docker run`.
- **Hiring managers / reviewers** who want to see the same problem solved three ways with explicit trade-offs.

---

## Try it yourself

1. Clone [micser-apps-GCP-Terraform-Helm-GitOps-monitoring](https://github.com/btilki/micser-apps-GCP-Terraform-Helm-GitOps-monitoring).
2. Start at [docs/implementation/README.md](https://github.com/btilki/micser-apps-GCP-Terraform-Helm-GitOps-monitoring/blob/main/docs/implementation/README.md) — follow the phases in order, from GCP project creation through prod promotion.
3. Compare with the [AWS](https://github.com/btilki/micser-apps-AWS-Terraform-Helm-GitOps-monitoring) and [Azure](https://github.com/btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring) READMEs and architecture docs.

The goal was never three identical repos. It was one **reference architecture** — build once, promote by digest, GitOps to prod — expressed in the idioms of each cloud. GCP is the most Google-native of the three; AWS and Azure remain the counterpoints that make the design choices visible.

---

*License: [Apache 2.0](https://github.com/btilki/micser-apps-GCP-Terraform-Helm-GitOps-monitoring/blob/main/LICENSE). Application code under `apps/` retains Google LLC copyright from the upstream microservices-demo project.*

*Author: [Birol Tilki](https://github.com/btilki)*
