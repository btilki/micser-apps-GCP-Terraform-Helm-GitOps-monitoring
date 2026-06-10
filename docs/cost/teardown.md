# Cost teardown

Stop ongoing charges by destroying cloud resources in **reverse create order**.

## Quick commands

```bash
# After cluster workloads are removed (see Phase 7 §7.3)
terraform -chdir=infra/terraform/envs/foundation destroy

# Optional — also removes state bucket and GitHub WIF
gcloud storage rm -r gs://YOUR_TFSTATE_BUCKET/** --project=YOUR_PROJECT_ID
terraform -chdir=infra/terraform/envs/bootstrap destroy
```

## Full guide

Step-by-step teardown (Argo CD, Gateway API, KMS, DNS, registrar, billing verification):

**[Phase 7 — Teardown](../implementation/phase-07-teardown.md)**

## Cost while running

With the cluster up but idle, you still pay for:

- GKE control plane and node VMs
- Cloud NAT gateway and egress
- Global static IP (`boutique-gateway-ip`) while allocated
- Artifact Registry storage
- Cloud DNS managed zone

Scaling node pools to zero reduces compute cost but not the control plane, NAT, or static IP. For a full stop, run Phase 7 foundation destroy.
