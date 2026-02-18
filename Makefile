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

.PHONY: test test-shell test-clean
test: ## Run tests in Docker (all, or F=path/to/test.bats for single file)
	@tests/test-runner.sh $(if $(F),$(F),all)
test-shell: ## Drop into test container for debugging
	@tests/test-runner.sh shell
test-clean: ## Remove test Docker images and containers
	@docker ps -a | grep dotfiles-test | awk '{print $$1}' | xargs -r docker rm 2>/dev/null || true
	@docker images | grep dotfiles-test | awk '{print $$3}' | xargs -r docker rmi 2>/dev/null || true
	@echo "✓ Test containers and images removed"

.PHONY: dev-shell
dev-shell: ## Interactive shell with dotfiles pre-installed (Ubuntu)
	@tests/test-runner.sh dev
