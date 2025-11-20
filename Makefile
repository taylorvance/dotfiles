.PHONY: help setup link unlink status restore install-tools test test-unit test-integration test-configs test-shell test-clean

# Default target
.DEFAULT_GOAL := help

help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup: ## Complete setup: install tools + create symlinks (fresh machine)
	@src/install-tools.sh
	@echo ""
	@echo "Tools installed! Now creating symlinks..."
	@echo ""
	@src/symlink-manager.sh install

install-tools: ## Install required CLI tools (brew/apt/dnf/pacman)
	@src/install-tools.sh

link: ## Create symlinks for dotfiles
	@src/symlink-manager.sh install

unlink: ## Remove all dotfile symlinks
	@src/symlink-manager.sh uninstall

status: ## Show installation status of tools and dotfiles
	@src/check-tools.sh || true
	@echo ""
	@echo ""
	@src/symlink-manager.sh status || true

restore: ## Restore files from a backup directory
	@src/symlink-manager.sh restore

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

test-clean: ## Remove test Docker images and containers
	@docker ps -a | grep dotfiles-test | awk '{print $$1}' | xargs -r docker rm 2>/dev/null || true
	@docker images | grep dotfiles-test | awk '{print $$3}' | xargs -r docker rmi 2>/dev/null || true
	@echo "✓ Test containers and images removed"

# Legacy aliases (deprecated but kept for compatibility)
teardown: unlink ## (deprecated: use 'unlink' instead)
