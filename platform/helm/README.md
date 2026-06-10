# Platform Helm values

Upstream chart values for components installed via Argo CD Applications (phase 2):

- `external-dns/` — Cloud DNS integration
- `cert-manager/` — optional if not using Certificate Manager only
- `kyverno/` — admission controller
- `external-secrets/` — GSM → Kubernetes

Add Argo CD Application manifests under `gitops/bootstrap/applications/` referencing these values.
