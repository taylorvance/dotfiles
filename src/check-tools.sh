#!/usr/bin/env bash
# Check status of installed tools

# Color codes (match symlink-manager.sh)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if command exists
command_exists() {
	command -v "$1" >/dev/null 2>&1
}

# Check tool status
check_tool() {
	local tool=$1
	local category=$2

	if command_exists "$tool"; then
		printf "  ${GREEN}✓${NC} ${tool}\n"
	else
		if [ "$category" = "required" ]; then
			printf "  ${RED}✗${NC} ${tool}\n"
		else
			printf "  ${YELLOW}⚠${NC} ${tool}\n"
		fi
	fi
}

# Main
printf "Tool installation status:\n\n"

printf "${BLUE}Required:${NC}\n"
check_tool nvim "required"
check_tool git "required"
check_tool tmux "required"
check_tool zsh "required"
check_tool fzf "required"
check_tool curl "required"
check_tool unzip "required"

if [[ "$OSTYPE" != "darwin"* ]]; then
	check_tool gcc "required"
	check_tool make "required"
fi

printf "\n${BLUE}Optional:${NC}\n"
check_tool bat "optional"
check_tool zoxide "optional"
check_tool eza "optional"
check_tool fd "optional"
check_tool rg "optional"
check_tool delta "optional"
check_tool atuin "optional"
check_tool starship "optional"
check_tool node "optional"
check_tool npm "optional"
check_tool python3 "optional"
check_tool ollama "optional"
check_tool dotnet "optional"
check_tool php "optional"

printf "\n"
printf "${YELLOW}Tip: Run 'make install-tools' to install missing tools${NC}\n"
