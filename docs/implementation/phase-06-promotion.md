# Phase 6 — Promotion (dev → stage → prod)

Promote immutable images by digest across Artifact Registry repos and GitOps environments.

**Previous:** [phase-05-first-service.md](phase-05-first-service.md)

---

## 6.1 Promotion model

```text
CI builds once  →  boutique-dev AR
promote.yml     →  gcloud artifacts docker images copy (by digest)
GitOps PR       →  updates gitops/envs/<target>/values-<service>.yaml
Argo CD         →  syncs target namespace
```

- **No rebuild** on promote — same digest, different AR repo.
- **stage:** auto-sync after PR merge.
- **prod:** manual Argo Sync + GitHub `prod` environment approval on promote workflow.

---

## 6.2 Promote to stage

1. Note the digest from dev GitOps values, e.g. `sha256:abc123...` in `gitops/envs/dev/values-frontend.yaml`.
2. **Actions** → **Promote image** → Run workflow:
   - `service`: `frontend`
   - `source_env`: `dev`
   - `target_env`: `stage`
   - `digest`: `sha256:...`
3. Merge the promotion PR.
4. Argo syncs `frontend-stage` (automated).
5. Smoke test: `https://stage.boutique.example.com` (when DNS exists).

Repeat for other services.

---

## 6.3 Promote to prod

Same workflow with `target_env`: `prod`. Requires **prod** environment approval if configured.

**Before first prod deploy:**

- Binary Authorization is configured to require attestations (see [SECURITY.md](../../SECURITY.md)).
- Ensure CI created attestations (`gcloud beta container binauthz attestations ...` step in reusable CI).

After PR merge:

1. Open Argo CD UI.
2. Find `frontend-prod` (and other `*-prod` apps).
3. Click **Sync** manually (prod does not auto-sync).

---

## 6.4 Rollback

To roll back prod, either:

- Promote a known-good digest from stage to prod again, or
- Revert the GitOps PR and manual Sync in Argo.

Document known-good digests in your ops notes for rehearsed rollback.

---

## Phase 6 checklist

```text
□ Promote frontend dev → stage; PR merged; stage pods healthy
□ Promote frontend stage → prod; PR merged; manual Argo sync
□ prod frontend smoke test passes
□ Remaining services promoted on same path
□ Prod promotion required reviewer approval (if configured)
```

---

## Common issues

| Problem | Fix |
|---------|-----|
| `gcloud artifacts docker images copy` denied | `sa-promote-ci` IAM on source (reader) and target (writer) repos |
| Prod pod blocked by Binary Authorization | Image needs attestation from CI; check attestor name `boutique-cosign` |
| Prod sync automatic when it shouldn't | Check ApplicationSet `templatePatch` for `autoSync: "false"` on prod |
