# Pulse platform — top-level targets.
# Each module extends this file; keep targets self-documenting.

SHELL := /bin/bash
API   := platform/services/pulse-api
WORKER:= platform/services/pulse-worker

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

.PHONY: build
build: ## Build both services
	cd $(API) && go build -o ../../../bin/pulse-api .
	cd $(WORKER) && go build -o ../../../bin/pulse-worker .

.PHONY: test
test: ## Run unit tests
	cd $(API) && go test ./...
	cd $(WORKER) && go test ./...

.PHONY: vet
vet: ## Static analysis
	cd $(API) && go vet ./...
	cd $(WORKER) && go vet ./...

.PHONY: lint
lint: ## Shellcheck every script in the repo
	@find . -name '*.sh' -not -path './archive/*' -print0 \
	  | xargs -0 -r shellcheck

.PHONY: verify
verify: ## Run the platform verification harness
	./platform/scripts/verify.sh

.PHONY: clean
clean: ## Remove build artifacts
	rm -rf bin/
