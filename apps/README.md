# Application source (Online Boutique)

Real [microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo) source for **five owned services**. CI builds from these directories and pushes to Artifact Registry `boutique-dev`.

## Services

| Service | Path | Dockerfile | Build context |
|---------|------|------------|---------------|
| `frontend` | `apps/frontend/` | `Dockerfile` | `apps/frontend` |
| `cartservice` | `apps/cartservice/` | `src/Dockerfile` | `apps/cartservice/src` |
| `currencyservice` | `apps/currencyservice/` | `Dockerfile` | `apps/currencyservice` |
| `productcatalogservice` | `apps/productcatalogservice/` | `Dockerfile` | `apps/productcatalogservice` |
| `redis-cart` | `apps/redis-cart/` | `Dockerfile` | `apps/redis-cart` |

## Refresh upstream source

```bash
git remote add microservices-demo https://github.com/GoogleCloudPlatform/microservices-demo.git 2>/dev/null || true
git fetch microservices-demo main
git subtree pull --prefix=apps/frontend microservices-demo main --squash  # repeat per service path
```

Or sparse-clone and copy `src/<service>` as documented in [phase-00-scaffold.md](../docs/implementation/phase-00-scaffold.md).
