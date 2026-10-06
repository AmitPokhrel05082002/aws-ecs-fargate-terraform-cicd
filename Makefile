# Usage: make <target> [ENV=staging|production]
ENV     ?= staging
PROJECT ?= sample-saas
REGION  ?= ap-southeast-1

ACCOUNT_ID   = $(shell aws sts get-caller-identity --query Account --output text)
STATE_BUCKET = $(PROJECT)-tfstate-$(ACCOUNT_ID)
REGISTRY     = $(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com
TF_DIR       = infra/envs/$(ENV)

.PHONY: help bootstrap first-image init plan apply outputs test fmt destroy

help: ## Show available targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-12s %s\n", $$1, $$2}'

bootstrap: ## One time: state bucket, ECR, GitHub OIDC roles (pass GITHUB_REPO=owner/name)
	terraform -chdir=infra/bootstrap init
	terraform -chdir=infra/bootstrap apply -var="github_repo=$(GITHUB_REPO)" -var="project=$(PROJECT)" -var="region=$(REGION)"

first-image: ## One time: push the "initial" image the ECS service starts with
	aws ecr get-login-password --region $(REGION) | docker login --username AWS --password-stdin $(REGISTRY)
	docker build --build-arg GIT_SHA=initial -t $(REGISTRY)/$(PROJECT):initial app
	docker push $(REGISTRY)/$(PROJECT):initial

init: ## Initialise Terraform for ENV
	terraform -chdir=$(TF_DIR) init -reconfigure \
		-backend-config="bucket=$(STATE_BUCKET)" \
		-backend-config="key=$(ENV)/terraform.tfstate" \
		-backend-config="region=$(REGION)"

plan: init ## Plan infrastructure changes for ENV
	terraform -chdir=$(TF_DIR) plan -out=tfplan

apply: ## Apply the saved plan for ENV
	terraform -chdir=$(TF_DIR) apply tfplan

outputs: ## Show URL and resource names for ENV
	terraform -chdir=$(TF_DIR) output

test: ## Run app tests
	cd app && npm test

fmt: ## Format Terraform code
	terraform fmt -recursive infra

destroy: init ## Destroy ENV (production: set protect_data = false and apply first)
	terraform -chdir=$(TF_DIR) destroy
