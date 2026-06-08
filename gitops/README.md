# GitOps layout

| Path | Purpose |
|------|---------|
| `bootstrap/` | Argo CD root app + platform/workloads child apps |
| `applicationsets/` | Matrix generator for env × service |
| `envs/<env>/values-<service>.yaml` | Digest-pinned overrides (CI updates) |
| `platform/` | Namespaces, Gateway, NetworkPolicies |
| `../platform/manifests/` | One-off manifests (e.g. Argo CD HTTPRoute) — apply manually |

Prod apps sync **manually** — `boutique-services-prod` ApplicationSet has no automated syncPolicy.
