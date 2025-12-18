#!/bin/bash

# Safety audit for unit tests AND the scripts they execute
# Ensures tests don't write outside isolated temp directories
# Run before `make test-local` to catch unsafe patterns

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UNIT_TESTS="$SCRIPT_DIR/unit"
SRC_SCRIPTS="$PROJECT_ROOT/src"
BIN_SCRIPTS="$PROJECT_ROOT/src/dotfiles/.local/bin"

echo "═══════════════════════════════════════"
echo "  Safety Audit for Local Test Execution"
echo "═══════════════════════════════════════"
echo ""

UNSAFE=false

# ============================================================================
# PART 1: Audit source scripts for hardcoded dangerous paths
# ============================================================================
echo "PART 1: Auditing source scripts..."
echo ""

echo "Checking: No hardcoded user paths in scripts..."
for f in "$SRC_SCRIPTS"/*.sh "$BIN_SCRIPTS"/*; do
    [ -f "$f" ] || continue
    # Look for /Users/, /home/, or /tmp/ followed by non-variable
    dangerous=$(grep -nE '(/Users/|/home/[a-z]|/tmp/[a-z])' "$f" 2>/dev/null | grep -v '^ *#' || true)
    if [ -n "$dangerous" ]; then
        echo -e "  ${RED}✗${NC} $(basename "$f"): Hardcoded path found:"
        echo "$dangerous" | while read line; do echo "      $line"; done
        UNSAFE=true
    fi
done

echo "Checking: Scripts use \$HOME not ~/..."
for f in "$SRC_SCRIPTS"/*.sh "$BIN_SCRIPTS"/*; do
    [ -f "$f" ] || continue
    # tilde in executable scripts is risky - may not respect HOME override
    tilde_usage=$(grep -nE '~/[a-zA-Z]' "$f" 2>/dev/null | grep -v '^ *#' | grep -v 'echo\|print\|#' || true)
    if [ -n "$tilde_usage" ]; then
        echo -e "  ${YELLOW}⚠${NC} $(basename "$f"): Uses ~/ (may not respect HOME override):"
        echo "$tilde_usage" | head -3 | while read line; do echo "      $line"; done
    fi
done

echo ""

# ============================================================================
# PART 2: Audit test files for isolation
# ============================================================================
echo "PART 2: Auditing unit tests..."
echo ""

# Check 1: All tests must have setup() with mktemp -d
echo "Checking: All tests create isolated TEST_DIR..."
for f in "$UNIT_TESTS"/*.bats; do
    if ! grep -q 'TEST_DIR=\$(mktemp -d)' "$f"; then
        echo -e "  ${RED}✗${NC} $(basename "$f"): Missing TEST_DIR=\$(mktemp -d) in setup()"
        UNSAFE=true
    fi
done

# Check 2: All tests must have teardown() with rm -rf "$TEST_DIR"
echo "Checking: All tests clean up TEST_DIR..."
for f in "$UNIT_TESTS"/*.bats; do
    if ! grep -q 'rm -rf "\$TEST_DIR"' "$f"; then
        echo -e "  ${RED}✗${NC} $(basename "$f"): Missing rm -rf \"\$TEST_DIR\" in teardown()"
        UNSAFE=true
    fi
done

# Check 3: No writes to absolute paths outside variables
echo "Checking: No writes to absolute paths..."
for f in "$UNIT_TESTS"/*.bats; do
    # Look for dangerous patterns: rm -rf /path, > /path, mkdir /path
    # Exclude: /dev/null, variable references ($), comments (#)
    dangerous=$(grep -nE '(rm -rf|mkdir -p?|> *)/[^$\s]' "$f" 2>/dev/null | grep -v '/dev/null' | grep -v '^ *#' || true)
    if [ -n "$dangerous" ]; then
        echo -e "  ${RED}✗${NC} $(basename "$f"): Potential unsafe absolute path:"
        echo "$dangerous" | while read line; do
            echo "      $line"
        done
        UNSAFE=true
    fi
done

# Check 4: Scripts that use HOME must override it
echo "Checking: HOME is overridden when needed..."
for f in "$UNIT_TESTS"/*.bats; do
    # If test references $HOME in test body (not setup), check if HOME is overridden
    if grep -q '\$HOME' "$f"; then
        if ! grep -q 'export HOME="\$TEST' "$f" && ! grep -q "HOME=.*TEST" "$f"; then
            # Check if it's just referencing HOME in a safe way (like checking a variable)
            uses_home_dangerously=$(grep -n '\$HOME' "$f" | grep -v 'export HOME' | grep -v '# ' | grep -v 'TEST_HOME' || true)
            if [ -n "$uses_home_dangerously" ]; then
                echo -e "  ${YELLOW}⚠${NC} $(basename "$f"): Uses \$HOME - verify it's overridden in setup()"
            fi
        fi
    fi
done

# Check 5: No dangerous system-wide commands
echo "Checking: No dangerous system commands..."
for f in "$UNIT_TESTS"/*.bats; do
    # tmux kill-server kills ALL tmux sessions - catastrophic locally
    # Exclude comments (lines starting with # or containing # before the command)
    if grep -v '^ *#' "$f" | grep -q 'tmux kill-server'; then
        echo -e "  ${RED}✗${NC} $(basename "$f"): Contains 'tmux kill-server' - KILLS ALL USER TMUX SESSIONS!"
        UNSAFE=true
    fi
    # killall can kill user processes
    if grep -E 'killall [a-zA-Z]' "$f" 2>/dev/null | grep -qv '^ *#'; then
        echo -e "  ${RED}✗${NC} $(basename "$f"): Contains 'killall' - may kill user processes"
        UNSAFE=true
    fi
    # pkill can kill user processes
    if grep -E 'pkill ' "$f" 2>/dev/null | grep -qv '^ *#'; then
        echo -e "  ${RED}✗${NC} $(basename "$f"): Contains 'pkill' - may kill user processes"
        UNSAFE=true
    fi
    # reboot/shutdown - just in case
    if grep -qE '(reboot|shutdown|halt|poweroff)' "$f" 2>/dev/null; then
        echo -e "  ${RED}✗${NC} $(basename "$f"): Contains system control command!"
        UNSAFE=true
    fi
done

echo ""

if $UNSAFE; then
    echo -e "${RED}═══════════════════════════════════════${NC}"
    echo -e "${RED}  ✗ Safety check FAILED${NC}"
    echo -e "${RED}  Do NOT run tests locally until fixed${NC}"
    echo -e "${RED}═══════════════════════════════════════${NC}"
    exit 1
else
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}  ✓ All unit tests are safely isolated${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    exit 0
fi
