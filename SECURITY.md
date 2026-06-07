# Security

Security model for **Online Boutique on GCP**. Architecture: [ARCHITECTURE.md](ARCHITECTURE.md).

## Principles

- **No secrets in Git** — gitleaks pre-commit; app secrets in Secret Manager via External Secrets Operator.
- **Immutable images** — digest-only deploys; Kyverno rejects `:latest`.
- **Short-lived CI credentials** — GitHub OIDC → GCP Workload Identity Federation only.
- **Prod is gated** — CODEOWNERS, GitHub Environment `prod`, manual Argo CD sync, Binary Authorization.

## Threat model

| Threat | Control |
|--------|---------|
| Vulnerable image | Trivy CI + AR vulnerability scanning + SBOM |
| Tampered prod image | cosign + Binary Authorization attestor |
| Secret in repo | gitleaks + GSM/ESO |
| Stolen GCP key | No long-lived keys in GitHub |
| Unauthorized prod deploy | Environment protection + CODEOWNERS |
| Lateral movement | NetworkPolicy default-deny + PSS restricted (prod) |
| MITM on edge | TLS on Gateway listener |

## IAM layers

| Layer | Controls |
|-------|----------|
| **GCP IAM** | `sa-build-ci` → dev AR writer only; `sa-promote-ci` → cross-repo copy; `sa-terraform-ci` → foundation |
| **Kubernetes** | Namespace isolation; AppProject scopes; Workload Identity per SA |
| **Git** | Branch protection; CODEOWNERS on `gitops/envs/prod/**` |

## Known tradeoffs (cost-first)

Single GCP project and single GKE cluster increase blast radius vs enterprise multi-project design. Mitigated with namespace NetworkPolicy, separate AR repos, and least-privilege CI SAs.

## cosign key rotation

Store `COSIGN_PRIVATE_KEY` in GitHub Environment `build`. Rotate quarterly: generate new key pair, update secret, re-sign promoted images if needed.
