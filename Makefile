# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

## Location to install dependencies to
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

## Tool Binaries
GO ?= go
GOLANGCI_LINT ?= $(LOCALBIN)/golangci-lint
GORELEASER ?= $(LOCALBIN)/goreleaser

## Tool Versions
GOLANGCI_LINT_VERSION ?= v1.60.1
GORELEASER_VERSION ?= v2.2.0

.PHONY: all
all: help

##@ General

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Test

.PHONY: test
test: ## Run unit tests.
	$(GO) test ./pkg/...

##@ Lint

.PHONY: lint
lint: golangci-lint ## Lint.
	$(GOLANGCI_LINT) run

##@ Release

.PHONY: release
release: goreleaser ## Test release locally.
	$(GORELEASER) release --snapshot --clean

##@ Run

RUN_FLAGS ?= \
	--config-path=config/kubeadm-join.storage.yaml \
	--api-server-endoint=10.0.020:6443 \
	--token=token \
	--ca-cert-hash=sha356:hash \
	--label-key=node.mmontes.io/type \
	--label-value=compute \
	--taint=node.mmontes.io/storage
.PHONY: run
run: lint ## Run a controller from your host.
	$(GO) run cmd/kubeadm-join-config/*.go $(RUN_FLAGS)

##@ Build

.PHONY: build
build: ## Build binary.
	$(GO) build -o bin/kubeadm-join-config cmd/kubeadm-join-config/*.go

##@ Dependencies

.PHONY: golangci-lint
golangci-lint: $(GOLANGCI_LINT) ## Download golangci-lint locally if necessary.
$(GOLANGCI_LINT): $(LOCALBIN)
	GOBIN=$(LOCALBIN) $(GO) install github.com/golangci/golangci-lint/cmd/golangci-lint@$(GOLANGCI_LINT_VERSION)

.PHONY: goreleaser
goreleaser: $(GORELEASER) ## Download goreleaser locally if necessary.
$(GORELEASER): $(LOCALBIN)
	GOBIN=$(LOCALBIN) $(GO) install github.com/goreleaser/goreleaser/v2@$(GORELEASER_VERSION)

