#!/bin/bash

# Test runner script for dotfiles test suite
# Handles Docker build, BATS installation, and test execution

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BATS_VERSION="1.11.0"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Determine if running inside Docker
IS_DOCKER=false
if [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    IS_DOCKER=true
fi

usage() {
    echo "Usage: $0 [MODE]"
    echo ""
    echo "Test Modes:"
    echo "  all            Run all tests (unit + integration)"
    echo "  shell          Drop into interactive shell in test container (Alpine)"
    echo ""
    echo "Development Modes:"
    echo "  dev            Interactive shell with dotfiles pre-installed (Ubuntu)"
    echo ""
    echo "Examples:"
    echo "  make test              # Run all tests"
    echo "  make test-shell        # Interactive debugging"
    echo "  make dev-shell         # Try your dotfiles (pre-installed)"
    exit 1
}

install_bats() {
    if command -v bats &> /dev/null; then
        echo -e "${GREEN}✓${NC} BATS already installed"
        return 0
    fi

    echo -e "${BLUE}→${NC} Installing BATS ${BATS_VERSION}..."

    local tmpdir=$(mktemp -d)
    local tarball="$tmpdir/bats.tar.gz"

    # Download tarball with retries
    local max_attempts=3
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if curl -fsSL "https://github.com/bats-core/bats-core/archive/refs/tags/v${BATS_VERSION}.tar.gz" -o "$tarball"; then
            break
        fi
        echo -e "${YELLOW}Download attempt $attempt failed, retrying...${NC}"
        attempt=$((attempt + 1))
        sleep 2
    done

    if [ ! -f "$tarball" ] || [ ! -s "$tarball" ]; then
        echo -e "${RED}✗${NC} Failed to download BATS"
        rm -rf "$tmpdir"
        return 1
    fi

    # Extract (Alpine uses busybox tar, need -z flag)
    cd "$tmpdir"
    if ! tar -xzf "$tarball" 2>/dev/null; then
        echo -e "${RED}✗${NC} Failed to extract BATS tarball"
        rm -rf "$tmpdir"
        return 1
    fi

    cd "bats-core-${BATS_VERSION}"

    # Install to user directory (no root needed)
    ./install.sh "$HOME/.local"

    # Add to PATH for current session
    export PATH="$HOME/.local/bin:$PATH"

    cd - > /dev/null
    rm -rf "$tmpdir"

    if command -v bats &> /dev/null; then
        echo -e "${GREEN}✓${NC} BATS installed successfully"
    else
        echo -e "${RED}✗${NC} BATS installation failed"
        return 1
    fi
}

run_docker_tests() {
    local mode=$1
    local dockerfile=${2:-Dockerfile.alpine}

    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}  Dotfiles Test Suite (Docker)${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    # Build Docker image
    echo -e "${BLUE}→${NC} Building test container..."
    docker build -f "$PROJECT_ROOT/tests/docker/$dockerfile" -t dotfiles-test:latest "$PROJECT_ROOT" -q

    if [ "$mode" = "shell" ]; then
        echo -e "${BLUE}→${NC} Starting interactive shell..."
        echo -e "${YELLOW}Tip: Run 'tests/test-runner.sh all' inside the container to run tests${NC}"
        docker run --rm -it dotfiles-test:latest /bin/bash
    else
        echo -e "${BLUE}→${NC} Running tests in container..."
        echo ""
        docker run --rm dotfiles-test:latest tests/test-runner.sh "$mode"
    fi
}

run_dev_shell() {
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}  Dotfiles Development Environment${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    # Use dev Dockerfile with pre-installed dotfiles
    echo -e "${BLUE}→${NC} Building dev container with pre-installed dotfiles..."
    echo -e "${YELLOW}This may take a few minutes on first build...${NC}"
    docker build -f "$PROJECT_ROOT/tests/docker/Dockerfile.dev" -t dotfiles-dev:latest "$PROJECT_ROOT"
    echo -e "${BLUE}→${NC} Starting pre-configured environment..."
    echo -e "${GREEN}Dotfiles are already installed and configured!${NC}"
    echo -e "${YELLOW}Try: ls -la ~ or run 'sysinfo'${NC}"
    docker run --rm -it dotfiles-dev:latest
}

run_tests() {
    local mode=$1

    # Install BATS if not present
    install_bats

    # Ensure BATS is in PATH
    export PATH="$HOME/.local/bin:$PATH"

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}  Dotfiles Test Suite${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""

    cd "$PROJECT_ROOT"

    case $mode in
        all)
            echo -e "${YELLOW}Running all tests...${NC}"
            echo ""
            bats tests/unit/*.bats tests/integration/*.bats
            ;;
        *)
            echo -e "${RED}✗${NC} Unknown mode: $mode"
            usage
            ;;
    esac

    local exit_code=$?

    echo ""
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}═══════════════════════════════════════${NC}"
        echo -e "${GREEN}  ✓ All tests passed!${NC}"
        echo -e "${GREEN}═══════════════════════════════════════${NC}"
    else
        echo -e "${RED}═══════════════════════════════════════${NC}"
        echo -e "${RED}  ✗ Some tests failed${NC}"
        echo -e "${RED}═══════════════════════════════════════${NC}"
    fi

    return $exit_code
}

# Main execution
MODE="${1:-all}"

if [ "$MODE" = "help" ] || [ "$MODE" = "-h" ] || [ "$MODE" = "--help" ]; then
    usage
fi

if $IS_DOCKER; then
    # Already inside Docker, run tests directly
    run_tests "$MODE"
else
    # Outside Docker, build and run container
    case "$MODE" in
        dev)
            run_dev_shell
            ;;
        *)
            run_docker_tests "$MODE"
            ;;
    esac
fi
