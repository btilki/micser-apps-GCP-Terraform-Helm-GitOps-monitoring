# GitOps layout

| Path | Purpose |
|------|---------|
| `bootstrap/` | Argo CD root app + platform/workloads child apps |
| `applicationsets/` | Matrix generator for env × service |
| `envs/<env>/values-<service>.yaml` | Digest-pinned overrides (CI updates) |
| `platform/` | Namespaces, Gateway, NetworkPolicies |

Prod apps sync **manually** — ApplicationSet `templatePatch` disables automation for `prod`.
