# Cost teardown

Destroy order (reverse of create):

```bash
terraform -chdir=infra/terraform/envs/foundation destroy
terraform -chdir=infra/terraform/envs/bootstrap destroy   # optional — keeps state bucket/WIF
```

Delete lingering L4/L7 load balancers if any remain after GKE delete.

Estimated running cost while idle with cluster up: see [README.md](../../README.md).
