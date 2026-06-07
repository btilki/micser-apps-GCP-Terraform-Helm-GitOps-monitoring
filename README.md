# Microservices-Google

Senior-level GCP DevOps platform for [Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo) — five owned services on **GKE**, with **Terraform**, **GitHub Actions**, **Artifact Registry**, **Argo CD**, **Gateway API**, **Managed Prometheus**, **Cloud Logging**, and supply-chain controls (**Trivy**, **cosign**, **Binary Authorization**, **Kyverno**).

## Quick links

| Doc | Purpose |
|-----|---------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | System design |
| [SECURITY.md](SECURITY.md) | Threat model and controls |
| [docs/implementation/README.md](docs/implementation/README.md) | **Start here** — full implementation guide |
| [docs/onboarding/runbook.md](docs/onboarding/runbook.md) | Quick reference + phase index |

## Repository layout

```
apps/                 # Real microservices-demo source (5 services)
charts/               # Helm library chart + per-service charts
gitops/               # Argo CD bootstrap, ApplicationSets, env values
platform/helm/        # Platform component Helm values
policies/kyverno/     # Admission policies
infra/terraform/      # Bootstrap + foundation IaC
.github/workflows/    # CI, Terraform, promotion
```

## Prerequisites

- GCP project with billing enabled
- `gcloud`, `terraform` >= 1.5, `kubectl`, `helm` >= 3.12
- Domain (or lab DNS) for HTTPS on Gateway API
- GitHub repo with Environments: `build`, `terraform`, `prod`

## Getting started

Follow the implementation guide in order:

1. [docs/implementation/README.md](docs/implementation/README.md) — overview, checklist, how GitHub + GCP connect
2. [Phase 1 — GCP & Terraform](docs/implementation/phase-01-gcp-and-terraform.md)
3. [Phase 2 — GitHub setup](docs/implementation/phase-02-github-setup.md)
4. [Phase 3 — GitHub Actions](docs/implementation/phase-03-github-actions.md)
5. [Phase 4 — Argo CD](docs/implementation/phase-04-argocd-and-platform.md)
6. [Phase 5 — First service](docs/implementation/phase-05-first-service.md)
7. [Phase 6 — Promotion](docs/implementation/phase-06-promotion.md)

## Sibling projects

| Repo | Cloud | CI | Notes |
|------|-------|-----|-------|
| Microservices-AWS | EKS | GitLab | Single Helm chart, upstream images |
| Microservices-Azure | AKS | Azure DevOps | Per-service charts, scaffold images |
| **Microservices-Google** | GKE | GitHub Actions | GCP-native ingress/observability, real app source |

## Cost

Roughly **$110–235/month** for a single private GKE cluster. Run `make tf-destroy-foundation` when idle — see [docs/cost/teardown.md](docs/cost/teardown.md).
