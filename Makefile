# Default target
.DEFAULT_GOAL := help
.PHONY: help
help: ## Show this help message
	@echo "Available targets:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""

.PHONY: setup teardown
setup: ## Complete setup: install tools + create symlinks (fresh machine)
	@src/install-tools.sh
	@echo ""
	@echo "Tools installed! Now creating symlinks..."
	@echo ""
	@src/symlink-manager.sh install
teardown: unlink ## (alias for `unlink`)

.PHONY: status
status: ## Show installation status of tools and dotfiles
	@src/check-tools.sh || true
	@echo ""
	@echo ""
	@src/symlink-manager.sh status || true

.PHONY: install
install: ## Install required CLI tools (via pkg mgr)
	@src/install-tools.sh

.PHONY: link unlink
link: ## Create symlinks for dotfiles
	@src/symlink-manager.sh install
unlink: ## Remove all dotfile symlinks
	@src/symlink-manager.sh uninstall

.PHONY: restore
restore: ## Restore files from a backup directory
	@src/symlink-manager.sh restore

.PHONY: test test-shell test-clean test-local test-file
test: ## Run all tests in Docker (unit + integration + config)
	@tests/test-runner.sh all
test-shell: ## Drop into test container for debugging
	@tests/test-runner.sh shell
test-local: ## Run unit tests locally (no Docker, faster)
	@tests/check-test-safety.sh
	@echo ""
	@echo "\033[1;33m════════════════════════════════════════════════════════════════\033[0m"
	@echo "\033[1;33m  ⚠  WARNING: About to run tests directly on your system\033[0m"
	@echo "\033[1;33m════════════════════════════════════════════════════════════════\033[0m"
	@echo ""
	@echo "  Tests passed static safety checks."
	@echo ""
	@printf "  Type 'yes' to continue: " && read ans && [ "$$ans" = "yes" ]
	@echo ""
	@echo "Running unit tests locally..."
	@command -v bats >/dev/null || (echo "Installing bats via brew..." && brew install bats-core)
	@bats tests/unit/*.bats
test-file: ## Run single test file locally: make test-file F=tests/unit/test-clean-script.bats
	@tests/check-test-safety.sh
	@echo ""
	@command -v bats >/dev/null || (echo "Installing bats via brew..." && brew install bats-core)
	@if [ -z "$(F)" ]; then echo "Usage: make test-file F=path/to/test.bats"; exit 1; fi
	@bats $(F)
test-clean: ## Remove test Docker images and containers
	@docker ps -a | grep dotfiles-test | awk '{print $$1}' | xargs -r docker rm 2>/dev/null || true
	@docker images | grep dotfiles-test | awk '{print $$3}' | xargs -r docker rmi 2>/dev/null || true
	@echo "✓ Test containers and images removed"

.PHONY: dev-shell
dev-shell: ## Interactive shell with dotfiles pre-installed (Ubuntu)
	@tests/test-runner.sh dev
