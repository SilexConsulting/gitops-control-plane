# Project Setup
PROJECT_NAME := gitops-control-plane
# Read the version from the VERSION file
RELEASE_VERSION ?= $(shell cat VERSION)
GIT_HASH ?= $(shell git log --format="%h" -n 1)

# Setting SHELL to bash allows bash commands to be executed by recipes.
# Options are set to exit when a recipe line exits non-zero or a piped command fails.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

all: help

.PHONY: help
##@ General
help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage: \033[36m\033[0m\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-26s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

release: ## Show release version
	@echo $(RELEASE_VERSION)-$(GIT_HASH)

clean-infra:  ## Clean all infrastructure
	@$(MAKE) kind-delete-all-clusters
	WHAT=all $(MAKE) terraform-rm-state

hub-cluster:
	@cd terraform/hub-spoke/hub && \
	terraform init && \
	terraform apply -auto-approve

dev-cluster:
	@cd terraform/hub-spoke/spokes && \
	terraform init && \
	./deploy.sh dev

make-prod-cluster:
	@cd terraform/hub-spoke/spokes && \
	terraform init && \
	./deploy.sh prod

##@ Terraform
terraform-rm-state: ## remove terraform states: 'all' for all states, 'spokes' for spoke states, or specify workspace name
	@if [ -z "$(WHAT)" ]; then \
		echo "Please specify: 'all', 'hub',  'spokes', or workspace name"; \
		exit 1; \
	fi
	@if [ "$(WHAT)" = "all" ]; then \
		echo "Removing all terraform state files..."; \
		find . -name terraform.tfstate* -exec rm -rf {} +; \
	elif [ "$(WHAT)" = "spokes" ]; then \
		echo "Removing spoke terraform state files..."; \
		find ./terraform/hub-spoke/spokes -name terraform.tfstate* -exec rm -rf {} +; \
	elif [ "$(WHAT)" = "hub" ]; then \
		echo "Removing hub terraform state files..."; \
		find ./terraform/hub-spoke/hub -name terraform.tfstate* -exec rm -rf {} +; \
	else \
		echo "Removing terraform state files for workspace: $(WHAT)"; \
		find ./terraform/hub-spoke/spokes -name "terraform.tfstate.d/$(WHAT)" -exec rm -rf {} +; \
	fi
	@echo "Terraform state files removed."

%: ;

terraform-all-rm-state: ## remove all terraform states
	@echo "Removing terraform state files..."
	@find . -name terraform.tfstate* -exec rm -rf {} +

##@ KinD
kind-delete: ## Delete kind cluster: 'hub' for hub cluster, 'spokes' for all spoke clusters, or specify spoke name
	@if [ -z "$(WHAT)" ]; then \
		echo "Please specify: 'hub', 'spokes', or spoke name"; \
		exit 1; \
	fi
	@if [ "$(WHAT)" = "hub" ]; then \
		echo "Deleting hub cluster..."; \
		kind delete cluster --name=hub-control || true; \
	elif [ "$(WHAT)" = "spokes" ]; then \
		echo "Deleting all spoke clusters..."; \
		kind get clusters | grep -E 'spoke-(dev|uat|prod)' | xargs -r -I {} kind delete cluster --name {}; \
	else \
		echo "Deleting spoke cluster: spoke-$(WHAT)"; \
		kind delete cluster --name=spoke-$(WHAT) || true; \
	fi

kind-delete-all-clusters: ## Delete all kind clusters
	@echo "Deleting all KinD clusters..."
	@kind get clusters | xargs -r -I {} kind delete cluster --name {}
	@echo "All KinD clusters deleted."

kind-list-clusters: ## list kind clusters
	@kind get clusters


##@ Kubectl
kubectl-current-context: ## Get current kubectl context
	@kubectl config current-context

kubectl-get-contexts: ## List kubectl contexts
	@kubectl config get-contexts -o name

##@ Argo
argocd-install: ## Install argocd
	@kubectl create namespace argocd || true
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

argocd-bootstrap:
	sops -d bootstrap/argocd/secrets.enc.yaml | kubectl apply -f -

argocd-ui: ## Access argocd ui
	@kubectl port-forward svc/argo-cd-argocd-server -n argocd 8088:443

argocd-login: ## Login to argocd
	@argocd login --insecure localhost:8088 --username admin --password $(shell kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

argocd-cluster-list: ## List argocd clusters
	@argocd cluster list

argocd-password: ## Get argocd password
	@kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
