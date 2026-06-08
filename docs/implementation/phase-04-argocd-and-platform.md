# Phase 4 — Argo CD and platform

Install Argo CD and sync platform resources (namespaces, Gateway, NetworkPolicies) and workloads (ApplicationSet).

**Previous:** [phase-03-github-actions.md](phase-03-github-actions.md)  
**Next:** [phase-05-first-service.md](phase-05-first-service.md)

---

## 4.1 Prerequisites

- Phase 1: GKE running, `kubectl get nodes` works
- Phase 2: `ORG` / `PROJECT_ID` / `REGION` replaced in GitOps manifests
- Phase 3: At least one GitOps values file merged (recommended: `frontend` dev digest)

If `kubectl` fails with `dial tcp …:443: i/o timeout`, your public IP is not in GKE `master_authorized_networks`. Check with `curl -4 ifconfig.me`, add the `/32` to `infra/terraform/envs/foundation/terraform.tfvars`, run `terraform apply`, then `make kubeconfig` (see [phase-01 §Common issues](phase-01-gcp-and-terraform.md#common-issues)).

---

## 4.2 Install Argo CD (one time)

```bash
kubectl create namespace argocd

kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
```

Get initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

Port-forward UI (optional):

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# https://localhost:8080  user: admin
```

---

## 4.3 Register repository (private repos only)

If the repo is **public**, skip this step.

For **private** repos, add a read-only deploy key or connect GitHub via Argo CD UI (**Settings → Repositories**).

---

## 4.4 Apply GitOps bootstrap

From repo root (manifests must already have correct `repoURL`):

```bash
kubectl apply -f gitops/bootstrap/project.yaml
kubectl apply -f gitops/bootstrap/root-app.yaml
```

The root app syncs child applications under `gitops/bootstrap/applications/`:

| Application | Syncs |
|-------------|-------|
| `boutique-platform` | `gitops/platform/` — namespaces, Gateway, NetworkPolicies |
| `boutique-workloads` | `gitops/applicationsets/` — service ApplicationSet |
| `boutique-kyverno-policies` | `policies/kyverno/` |

---

## 4.5 Verify platform

```bash
kubectl get applications -n argocd
kubectl get applicationsets -n argocd
kubectl get gateway -n platform
kubectl get namespaces | grep -E 'dev|stage|prod|platform'
```

In Argo CD UI, confirm apps are **Synced** / **Healthy** (may take a few minutes).

**Gateway external IP:** should match Terraform `gateway_ip`. Configure DNS A records when ready.

---

## 4.6 Kyverno (if not yet installed)

Cluster policies in `policies/kyverno/` require the **Kyverno admission controller**. Options:

1. Install Kyverno via Helm (see [platform/helm/README.md](../../platform/helm/README.md)), then let Argo sync policies.
2. Or apply policies manually after Kyverno is running:

```bash
kubectl apply -f policies/kyverno/   # after replacing REGION and PROJECT_ID
```

Until Kyverno is installed, policy Applications may show **OutOfSync** — expected.

---

## 4.7 Prod sync behavior

The ApplicationSet uses `templatePatch` so **prod** apps do **not** auto-sync. In Argo UI, prod applications require **manual Sync** after promotion (Phase 6).

---

## Phase 4 checklist

```text
□ Argo CD server running
□ gitops/bootstrap/project.yaml applied
□ gitops/bootstrap/root-app.yaml applied
□ boutique-platform application synced
□ boutique-workloads ApplicationSet created
□ Gateway resource exists in platform namespace
□ dev / stage / prod namespaces exist
```

---

## Common issues

| Problem | Fix |
|---------|-----|
| `kubectl` connection timeout | `curl -4 ifconfig.me` → add `/32` to `master_authorized_networks`, `terraform apply`, `make kubeconfig` |
| Application **Unknown** revision | Wrong `repoURL` or private repo not registered |
| ImagePullBackOff | Image not in AR yet — run CI (Phase 3) |
| Gateway no address | GKE Gateway controller may need a few minutes; check GKE Gateway add-on |
| Kyverno rejects pods | Ensure digest in values file matches `image@sha256:...` pattern |
