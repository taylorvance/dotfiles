#!/usr/bin/env bash
# Install required tools for dotfiles
# Supports macOS (Homebrew) and Linux (apt/dnf/pacman)

set -e

# Parse command line flags
AUTO_YES=false
while [[ $# -gt 0 ]]; do
	case $1 in
		-y|--yes)
			AUTO_YES=true
			shift
			;;
		*)
			echo "Unknown option: $1"
			echo "Usage: $0 [-y|--yes]"
			echo "  -y, --yes    Automatically answer yes to all prompts"
			exit 1
			;;
	esac
done

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Status symbols
INSTALLED="✓"
PRESENT="○"
FAILED="✗"
SKIPPED="⊙"

# Track results
declare -a installed_tools
declare -a present_tools
declare -a failed_tools
declare -a failed_optional_tools
declare -a skipped_tools

# Print colored message
print_status() {
	local color=$1
	local symbol=$2
	local message=$3
	echo -e "${color}${symbol}${NC} ${message}"
}

# Check if command exists
command_exists() {
	command -v "$1" >/dev/null 2>&1
}

# Detect OS
detect_os() {
	if [[ "$OSTYPE" == "darwin"* ]]; then
		echo "macos"
	elif [[ -f /etc/os-release ]]; then
		. /etc/os-release
		echo "$ID"
	else
		echo "unknown"
	fi
}

# Detect package manager
detect_package_manager() {
	if command_exists brew; then
		echo "brew"
	elif command_exists apt; then
		echo "apt"
	elif command_exists dnf; then
		echo "dnf"
	elif command_exists pacman; then
		echo "pacman"
	else
		echo "none"
	fi
}

# Install tool with appropriate package manager
install_tool() {
	local tool=$1
	local pkg_name=${2:-$tool}  # Use tool name if package name not specified

	if command_exists "$tool"; then
		print_status "$YELLOW" "$PRESENT" "$tool (already installed)"
		present_tools+=("$tool")
		return 0
	fi

	print_status "$BLUE" "..." "Installing $tool..."

	case $PKG_MGR in
		brew)
			if brew install "$pkg_name" >/dev/null 2>&1; then
				print_status "$GREEN" "$INSTALLED" "$tool"
				installed_tools+=("$tool")
				return 0
			fi
			;;
		apt)
			if sudo apt install -y "$pkg_name" >/dev/null 2>&1; then
				print_status "$GREEN" "$INSTALLED" "$tool"
				installed_tools+=("$tool")
				return 0
			fi
			;;
		dnf)
			if sudo dnf install -y "$pkg_name" >/dev/null 2>&1; then
				print_status "$GREEN" "$INSTALLED" "$tool"
				installed_tools+=("$tool")
				return 0
			fi
			;;
		pacman)
			if sudo pacman -S --noconfirm "$pkg_name" >/dev/null 2>&1; then
				print_status "$GREEN" "$INSTALLED" "$tool"
				installed_tools+=("$tool")
				return 0
			fi
			;;
	esac

	print_status "$RED" "$FAILED" "$tool (installation failed)"
	failed_tools+=("$tool")
	return 1
}

# Install optional tool (non-critical, won't fail build)
install_optional_tool() {
	local tool=$1
	local pkg_name=${2:-$tool}  # Use tool name if package name not specified

	if command_exists "$tool"; then
		print_status "$YELLOW" "$PRESENT" "$tool (already installed)"
		present_tools+=("$tool")
		return 0
	fi

	print_status "$BLUE" "..." "Installing $tool..."

	case $PKG_MGR in
		brew)
			if brew install "$pkg_name" >/dev/null 2>&1; then
				print_status "$GREEN" "$INSTALLED" "$tool"
				installed_tools+=("$tool")
				return 0
			fi
			;;
		apt)
			if sudo apt install -y "$pkg_name" >/dev/null 2>&1; then
				print_status "$GREEN" "$INSTALLED" "$tool"
				installed_tools+=("$tool")
				return 0
			fi
			;;
		dnf)
			if sudo dnf install -y "$pkg_name" >/dev/null 2>&1; then
				print_status "$GREEN" "$INSTALLED" "$tool"
				installed_tools+=("$tool")
				return 0
			fi
			;;
		pacman)
			if sudo pacman -S --noconfirm "$pkg_name" >/dev/null 2>&1; then
				print_status "$GREEN" "$INSTALLED" "$tool"
				installed_tools+=("$tool")
				return 0
			fi
			;;
	esac

	print_status "$YELLOW" "$SKIPPED" "$tool (not available in repos)"
	failed_optional_tools+=("$tool")
	return 0
}

# Install optional tool (prompt before installing)
install_optional() {
	local tool=$1
	local pkg_name=${2:-$tool}

	if command_exists "$tool"; then
		print_status "$YELLOW" "$PRESENT" "$tool (already installed)"
		present_tools+=("$tool")
		return 0
	fi

	# Auto-yes if flag is set
	if [ "$AUTO_YES" = true ]; then
		# Just continue to installation
		:
	else
		# Prompt user
		echo -ne "${YELLOW}Install ${tool}? (y/N): ${NC}"
		read -r response
		if [[ ! "$response" =~ ^[Yy]$ ]]; then
			print_status "$YELLOW" "$SKIPPED" "$tool (skipped)"
			skipped_tools+=("$tool")
			return 0
		fi
	fi

	print_status "$BLUE" "..." "Installing $tool..."

	case $PKG_MGR in
		brew)
			if brew install "$pkg_name" >/dev/null 2>&1; then
				print_status "$GREEN" "$INSTALLED" "$tool"
				installed_tools+=("$tool")
				return 0
			fi
			;;
		apt)
			if sudo apt install -y "$pkg_name" >/dev/null 2>&1; then
				print_status "$GREEN" "$INSTALLED" "$tool"
				installed_tools+=("$tool")
				return 0
			fi
			;;
		dnf)
			if sudo dnf install -y "$pkg_name" >/dev/null 2>&1; then
				print_status "$GREEN" "$INSTALLED" "$tool"
				installed_tools+=("$tool")
				return 0
			fi
			;;
		pacman)
			if sudo pacman -S --noconfirm "$pkg_name" >/dev/null 2>&1; then
				print_status "$GREEN" "$INSTALLED" "$tool"
				installed_tools+=("$tool")
				return 0
			fi
			;;
	esac

	print_status "$RED" "$FAILED" "$tool (installation failed)"
	failed_tools+=("$tool")
	return 0
}

# Main installation
main() {
	echo -e "${BLUE}=== Dotfiles Tool Installation ===${NC}\n"

	# Detect OS
	OS=$(detect_os)
	echo "Detected OS: $OS"

	# Detect package manager
	PKG_MGR=$(detect_package_manager)
	echo "Package manager: $PKG_MGR"
	echo ""

	if [[ "$PKG_MGR" == "none" ]]; then
		echo -e "${RED}No package manager found!${NC}"
		echo ""
		echo "Please install a package manager first:"
		if [[ "$OS" == "macos" ]]; then
			echo "  Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
		elif [[ "$OS" == "ubuntu" ]] || [[ "$OS" == "debian" ]]; then
			echo "  apt should be pre-installed on Debian/Ubuntu"
		elif [[ "$OS" == "fedora" ]]; then
			echo "  dnf should be pre-installed on Fedora"
		elif [[ "$OS" == "arch" ]]; then
			echo "  pacman should be pre-installed on Arch"
		fi
		exit 1
	fi

	echo -e "${BLUE}Installing core tools...${NC}"

	# Core tools
	install_tool nvim neovim
	install_tool git
	install_tool tmux
	install_tool zsh

	# Build tools (needed for nvim plugins)
	if [[ "$OS" == "macos" ]]; then
		# On macOS, gcc/make come with Xcode Command Line Tools
		if ! command_exists gcc; then
			print_status "$BLUE" "..." "Installing Xcode Command Line Tools..."
			xcode-select --install 2>/dev/null || true
			print_status "$YELLOW" "$SKIPPED" "gcc/make (install Xcode CLI Tools manually if needed)"
			skipped_tools+=("gcc")
		else
			print_status "$YELLOW" "$PRESENT" "gcc (already installed)"
			present_tools+=("gcc")
		fi
	else
		install_tool gcc
		install_tool make
	fi

	install_tool unzip

	# Download tools
	if ! command_exists curl && ! command_exists wget; then
		install_tool curl
	else
		if command_exists curl; then
			print_status "$YELLOW" "$PRESENT" "curl (already installed)"
			present_tools+=("curl")
		fi
		if command_exists wget; then
			print_status "$YELLOW" "$PRESENT" "wget (already installed)"
			present_tools+=("wget")
		fi
	fi

	echo ""
	echo -e "${BLUE}Installing modern CLI tools...${NC}"
	echo "(These enhance the shell experience but aren't critical)"
	echo ""

	# Modern CLI replacements (all have fallbacks in .zshrc)
	install_optional_tool fzf
	install_optional_tool bat
	install_optional_tool zoxide
	install_optional_tool eza
	install_optional_tool fd
	install_optional_tool rg ripgrep
	install_optional_tool delta git-delta
	install_optional_tool atuin
	install_optional_tool starship

	echo ""
	echo -e "${BLUE}Installing development tools...${NC}"

	# Development dependencies
	if [[ "$OS" == "macos" ]]; then
		# Node via brew
		if ! command_exists node; then
			install_tool node
		else
			print_status "$YELLOW" "$PRESENT" "node (already installed)"
			present_tools+=("node")
		fi
	else
		# On Linux, recommend nvm for node
		if ! command_exists node; then
			print_status "$YELLOW" "$SKIPPED" "node (install via nvm: https://github.com/nvm-sh/nvm)"
			skipped_tools+=("node")
		else
			print_status "$YELLOW" "$PRESENT" "node (already installed)"
			present_tools+=("node")
		fi
	fi

	# Python (usually pre-installed on Linux)
	if ! command_exists python3; then
		install_tool python3 python3
	else
		print_status "$YELLOW" "$PRESENT" "python3 (already installed)"
		present_tools+=("python3")
	fi

	# Only prompt for language-specific tools in interactive mode
	if [ "$AUTO_YES" = false ]; then
		echo ""
		echo -e "${BLUE}Installing optional language tools...${NC}"
		echo "(These are only needed if you work with specific languages)"
		echo ""

		# Optional language-specific tools
		install_optional ollama
		install_optional dotnet
		install_optional php
	else
		echo ""
		echo -e "${YELLOW}Skipping optional language tools (ollama, dotnet, php) in non-interactive mode${NC}"
		echo -e "${YELLOW}Install these manually if needed after setup${NC}"
	fi

	# Print summary
	echo ""
	echo -e "${BLUE}=== Installation Summary ===${NC}"
	echo ""

	if [ ${#installed_tools[@]} -gt 0 ]; then
		echo -e "${GREEN}Newly installed (${#installed_tools[@]}):${NC}"
		printf "  %s\n" "${installed_tools[@]}"
		echo ""
	fi

	if [ ${#present_tools[@]} -gt 0 ]; then
		echo -e "${YELLOW}Already present (${#present_tools[@]}):${NC}"
		printf "  %s\n" "${present_tools[@]}"
		echo ""
	fi

	if [ ${#skipped_tools[@]} -gt 0 ]; then
		echo -e "${YELLOW}Skipped/Optional (${#skipped_tools[@]}):${NC}"
		printf "  %s\n" "${skipped_tools[@]}"
		echo ""
	fi

	if [ ${#failed_optional_tools[@]} -gt 0 ]; then
		echo -e "${YELLOW}Optional tools not available (${#failed_optional_tools[@]}):${NC}"
		printf "  %s\n" "${failed_optional_tools[@]}"
		echo -e "${YELLOW}(These aren't critical - your dotfiles will work fine with fallbacks)${NC}"
		echo ""
	fi

	if [ ${#failed_tools[@]} -gt 0 ]; then
		echo -e "${RED}Critical tools failed (${#failed_tools[@]}):${NC}"
		printf "  %s\n" "${failed_tools[@]}"
		echo ""
		echo -e "${RED}ERROR: Core tools are required for dotfiles to function properly.${NC}"
		echo "Please install these manually and try again."
		exit 1
	fi

	echo -e "${GREEN}Installation complete!${NC}"
	echo ""
	echo "Next steps:"
	echo "  1. Run 'make link' to create dotfile symlinks"
	echo "  2. Restart your shell or run 'source ~/.zshrc'"
	echo "  3. For node packages via nvm: install nvm and run 'nvm install --lts'"
}

main "$@"
