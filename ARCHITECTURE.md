# Architecture

**Online Boutique on GCP** — one GKE cluster, three namespace-isolated environments, Terraform foundation, GitHub Actions CI, Argo CD GitOps (ApplicationSet), Gateway API ingress, Managed Prometheus, Cloud Logging.

Extended ADRs: [docs/architecture/design.md](docs/architecture/design.md).

## Goals

- Infrastructure as code (Terraform) with GCS remote state and GitHub OIDC → WIF.
- **Build once, promote by digest** across Artifact Registry repos `boutique-dev` → `boutique-stage` → `boutique-prod`.
- GitOps CD (Argo CD ApplicationSet); prod requires PR review and **manual** Argo sync.
- HTTPS via **Gateway API** (GKE L7 global external managed) + Certificate Manager.
- Supply chain: Trivy, syft SBOM, cosign, Binary Authorization attestations.
- Runtime policy: Kyverno, NetworkPolicy, Pod Security Admission, External Secrets → Secret Manager.

## Topology (cost-first)

| Layer | Resources |
|-------|-----------|
| Bootstrap | GCS state, WIF pool, CI service accounts |
| Foundation | VPC, private GKE, 3 AR repos, Cloud DNS, gateway static IP, KMS etcd encryption, Binary Auth attestor |
| Cluster | Namespaces `dev`, `stage`, `prod`, `platform`, `argocd` |

## Owned services (v1)

| Service | Public | Notes |
|---------|--------|-------|
| `frontend` | Yes (HTTPRoute) | Go — real microservices-demo source |
| `cartservice` | No | .NET gRPC |
| `currencyservice` | No | Node gRPC; internet egress for rates |
| `productcatalogservice` | No | Go gRPC |
| `redis-cart` | No | Redis cache |

## CI/CD flow

1. **CI** (`reusable-service-ci.yml`) — build → syft → Trivy → push dev AR → cosign → attest → GitOps PR.
2. **Promote** (`promote.yml`) — `gcloud artifacts docker images copy` + PR to stage/prod values.
3. **Deploy** — Argo CD syncs Helm charts + `gitops/envs/<env>/values-*.yaml`.

## Differences from sibling repos

| Topic | AWS sibling | Azure sibling | This repo |
|-------|-------------|---------------|-----------|
| CI | GitLab | Azure DevOps | GitHub Actions + reusable workflow |
| Ingress | ALB | NGINX | Gateway API |
| Metrics | kube-prometheus-stack | kube-prometheus-stack | Managed Prometheus |
| GitOps | Static apps + overlays | App-of-apps | ApplicationSet |
| App images | Upstream digests | Scaffold nginx | Real demo source in `apps/` |
