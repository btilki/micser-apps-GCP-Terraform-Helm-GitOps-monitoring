# Platform shortcuts — Online Boutique on GCP
# Requires: gcloud, terraform, kubectl, helm (see docs/onboarding/runbook.md)

TF_BOOTSTRAP  := infra/terraform/envs/bootstrap
TF_FOUNDATION := infra/terraform/envs/foundation
CHARTS        := charts/frontend charts/cartservice charts/currencyservice charts/productcatalogservice charts/redis-cart
GCP_REGION    ?= europe-west1

.PHONY: help fmt validate helm-lint tf-bootstrap-init tf-bootstrap-plan tf-foundation-init tf-foundation-plan kubeconfig

help:
	@echo "Targets:"
	@echo "  fmt                  - terraform fmt -recursive"
	@echo "  validate             - terraform validate (bootstrap + foundation, no backend)"
	@echo "  helm-lint            - helm lint all service charts"
	@echo "  tf-bootstrap-init    - init bootstrap stack"
	@echo "  tf-bootstrap-plan    - plan bootstrap"
	@echo "  tf-foundation-init   - init foundation stack"
	@echo "  tf-foundation-plan   - plan foundation"
	@echo "  kubeconfig           - gcloud get-credentials from foundation outputs"

fmt:
	terraform -chdir=$(TF_BOOTSTRAP) fmt -recursive
	terraform -chdir=$(TF_FOUNDATION) fmt -recursive
	terraform -chdir=infra/terraform/modules fmt -recursive 2>/dev/null || true

validate:
	terraform -chdir=$(TF_BOOTSTRAP) init -backend=false -input=false
	terraform -chdir=$(TF_BOOTSTRAP) validate
	terraform -chdir=$(TF_FOUNDATION) init -backend=false -input=false
	terraform -chdir=$(TF_FOUNDATION) validate

helm-lint:
	@for c in $(CHARTS); do echo "==> $$c"; helm lint $$c; done

tf-bootstrap-init:
	terraform -chdir=$(TF_BOOTSTRAP) init

tf-bootstrap-plan:
	terraform -chdir=$(TF_BOOTSTRAP) plan

tf-foundation-init:
	terraform -chdir=$(TF_FOUNDATION) init

tf-foundation-plan:
	terraform -chdir=$(TF_FOUNDATION) plan

kubeconfig:
	gcloud container clusters get-credentials \
		"$$(terraform -chdir=$(TF_FOUNDATION) output -raw cluster_name)" \
		--region "$(GCP_REGION)" \
		--project "$$(terraform -chdir=$(TF_FOUNDATION) output -raw project_id)"
