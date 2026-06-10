# Phase 0 — Scaffold

**Status:** Complete in this repository.

## What is already in the repo

- Real microservices-demo source in `apps/` (5 services)
- Helm library chart + per-service charts
- GitOps bootstrap, ApplicationSet, env value files
- Kyverno policy skeletons
- Terraform bootstrap + foundation modules
- GitHub Actions: reusable CI, per-service callers, Terraform, promote
- ADRs, [ARCHITECTURE.md](../../ARCHITECTURE.md), [SECURITY.md](../../SECURITY.md)

## What you do next

Start the hands-on implementation guide:

1. Read the overview: [README.md](README.md) (master checklist + how GitHub/GCP connect)
2. Begin **Phase 1:** [phase-01-gcp-and-terraform.md](phase-01-gcp-and-terraform.md)
