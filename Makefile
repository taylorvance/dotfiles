.PHONY: help setup teardown status restore

# Default target
.DEFAULT_GOAL := help

help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup: ## Install dotfiles by creating symlinks
	@bin/symlink-manager.sh install

teardown: ## Remove all dotfile symlinks
	@bin/symlink-manager.sh uninstall

status: ## Show installation status of all dotfiles
	@bin/symlink-manager.sh status

restore: ## Restore files from a backup directory
	@bin/symlink-manager.sh restore
