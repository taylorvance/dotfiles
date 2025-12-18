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

.PHONY: test test-unit test-integration test-configs test-shell test-clean test-local test-local-yolo
test: ## Run all tests in Docker (unit + integration + config)
	@tests/test-runner.sh all
test-unit: ## Run only unit tests (fast)
	@tests/test-runner.sh unit
test-integration: ## Run integration tests
	@tests/test-runner.sh integration
test-configs: ## Run config verification tests (nvim, tmux, zsh)
	@tests/test-runner.sh configs
test-shell: ## Drop into test container for debugging
	@tests/test-runner.sh shell
test-local-dryrun: ## Verify tests are safe by running in container first
	@tests/test-local-dryrun.sh
test-local: ## Run unit tests locally on macOS (no Docker, faster)
	@tests/check-test-safety.sh
	@echo ""
	@echo "\033[1;33m════════════════════════════════════════════════════════════════\033[0m"
	@echo "\033[1;33m  ⚠  WARNING: About to run tests directly on your system\033[0m"
	@echo "\033[1;33m════════════════════════════════════════════════════════════════\033[0m"
	@echo ""
	@echo "  Tests passed static safety checks, but if tests have changed"
	@echo "  since last verified, run '\033[36mmake test-local-dryrun\033[0m' first."
	@echo ""
	@printf "  Type 'yes' to continue: " && read ans && [ "$$ans" = "yes" ]
	@echo ""
	@echo "Running unit tests locally..."
	@command -v bats >/dev/null || (echo "Installing bats via brew..." && brew install bats-core)
	@bats tests/unit/*.bats
test-local-yolo: ## Run local tests without confirmation (use after dryrun)
	@tests/check-test-safety.sh
	@echo ""
	@command -v bats >/dev/null || (echo "Installing bats via brew..." && brew install bats-core)
	@bats tests/unit/*.bats
test-clean: ## Remove test Docker images and containers
	@docker ps -a | grep dotfiles-test | awk '{print $$1}' | xargs -r docker rm 2>/dev/null || true
	@docker images | grep dotfiles-test | awk '{print $$3}' | xargs -r docker rmi 2>/dev/null || true
	@echo "✓ Test containers and images removed"

.PHONY: dev-shell dev-shell-fresh
dev-shell: ## Interactive shell with dotfiles pre-installed (Ubuntu)
	@tests/test-runner.sh dev
dev-shell-fresh: ## Interactive shell with fresh Ubuntu (test installation manually)
	@tests/test-runner.sh dev-fresh
