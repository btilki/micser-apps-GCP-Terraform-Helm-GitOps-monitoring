# Architecture design & ADRs

![GCP platform architecture — Online Boutique on GKE](../diagrams/infrastructure-diagram.png)

## ADR-001: Cost-first topology

**Decision:** One GCP project, one private GKE cluster, environments as namespaces (`dev`, `stage`, `prod`).

**Rationale:** Minimize cost for portfolio/solo operation while keeping logical separation via AR repos and Argo CD.

## ADR-002: Platform via Argo CD sync waves

**Decision:** Platform manifests under `gitops/platform/`; upstream components (Kyverno, ESO) referenced from `platform/helm/` values via Argo Applications.

**Exception:** Initial Argo CD install from upstream manifest once.

## ADR-003: Gateway API ingress

**Decision:** GKE L7 global external managed Gateway + HTTPRoute; Certificate Manager cert map annotation.

**Rejected:** NGINX Ingress (Azure pattern) — not GCP-native default.

## ADR-004: Managed Prometheus + Cloud Logging

**Decision:** Enable GKE Managed Prometheus; use Cloud Logging for logs.

**Rejected:** Self-hosted kube-prometheus-stack and ELK on cluster.

## ADR-005: Helm library chart

**Decision:** `charts/lib` provides shared labels, image helper, pod security defaults.

## ADR-006: Supply chain

**Decision:** Reusable GitHub workflow with syft, Trivy, cosign, Binary Authorization attestation.

## ADR-007: ApplicationSet GitOps

**Decision:** Two ApplicationSets (autosync for dev/stage, manual for prod) generated from env × service matrix.

## ADR-008: Real application source

**Decision:** Vend microservices-demo `src/*` into `apps/` — no placeholder images.
