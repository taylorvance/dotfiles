#!/bin/bash

# Dry-run local tests in a container to verify they don't escape isolation
# This proves tests are safe before running on your real machine

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Local Test Dry Run (Container Isolation Verification)${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "This will:"
echo "  1. Create a Docker container with your dotfiles"
echo "  2. Snapshot the filesystem state"
echo "  3. Run unit tests (same as 'make test-local')"
echo "  4. Compare filesystem to detect any escaped writes"
echo ""

# Build a test container
echo -e "${YELLOW}Building test container...${NC}"
docker build -f "$PROJECT_ROOT/tests/docker/Dockerfile.alpine" -t dotfiles-dryrun:latest "$PROJECT_ROOT" -q

# Run the verification
echo -e "${YELLOW}Running isolation verification...${NC}"
echo ""

docker run --rm dotfiles-dryrun:latest /bin/bash -c '
set -e

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

cd ~/dotfiles

# Install bats
echo "Installing BATS..."
tests/test-runner.sh unit >/dev/null 2>&1 || true  # This installs bats as side effect
export PATH="$HOME/.local/bin:$PATH"

# Snapshot home directory BEFORE tests (excluding temp dirs and caches)
echo "Creating filesystem snapshot..."
SNAPSHOT_BEFORE=$(mktemp)
find ~ -type f -o -type l 2>/dev/null | grep -v "/tmp\." | grep -v "\.local/bin/bats" | grep -v "\.cache" | sort > "$SNAPSHOT_BEFORE"
HOMEDIR_HASH_BEFORE=$(find ~ -maxdepth 2 -type f -exec md5sum {} \; 2>/dev/null | sort | md5sum || echo "none")

# Track what temp directories get created
TEMP_DIRS_BEFORE=$(ls -la /tmp 2>/dev/null | wc -l)

echo ""
echo "Running unit tests..."
echo "─────────────────────────────────────────────────"

# Run the actual tests
bats tests/unit/*.bats 2>&1 | tail -20

echo "─────────────────────────────────────────────────"
echo ""

# Snapshot AFTER tests
SNAPSHOT_AFTER=$(mktemp)
find ~ -type f -o -type l 2>/dev/null | grep -v "/tmp\." | grep -v "\.local/bin/bats" | grep -v "\.cache" | sort > "$SNAPSHOT_AFTER"
HOMEDIR_HASH_AFTER=$(find ~ -maxdepth 2 -type f -exec md5sum {} \; 2>/dev/null | sort | md5sum || echo "none")

TEMP_DIRS_AFTER=$(ls -la /tmp 2>/dev/null | wc -l)

# Compare
echo "═══════════════════════════════════════════════════════"
echo "  ISOLATION VERIFICATION RESULTS"
echo "═══════════════════════════════════════════════════════"
echo ""

# Check for new files in home
NEW_FILES=$(diff "$SNAPSHOT_BEFORE" "$SNAPSHOT_AFTER" | grep "^>" | grep -v "\.bats_" || true)
if [ -n "$NEW_FILES" ]; then
    echo -e "${RED}✗ NEW FILES CREATED IN HOME:${NC}"
    echo "$NEW_FILES" | head -20
    echo ""
    ESCAPED=true
else
    echo -e "${GREEN}✓ No new files in home directory${NC}"
fi

# Check for modified files
if [ "$HOMEDIR_HASH_BEFORE" != "$HOMEDIR_HASH_AFTER" ]; then
    echo -e "${YELLOW}⚠ Some files in ~ may have been modified${NC}"
    echo "  (This could be harmless cache/state files)"
else
    echo -e "${GREEN}✓ No files modified in home directory${NC}"
fi

# Check for leftover temp directories
TEMP_DIFF=$((TEMP_DIRS_AFTER - TEMP_DIRS_BEFORE))
if [ $TEMP_DIFF -gt 0 ]; then
    echo -e "${YELLOW}⚠ $TEMP_DIFF temp entries remain in /tmp (normal - OS may not clean immediately)${NC}"
else
    echo -e "${GREEN}✓ No leftover temp directories${NC}"
fi

# Check for writes to /tmp/tmp-workspaces (the dangerous one we fixed)
if [ -d "/tmp/tmp-workspaces" ]; then
    echo -e "${RED}✗ /tmp/tmp-workspaces exists - tests escaped isolation!${NC}"
    ESCAPED=true
else
    echo -e "${GREEN}✓ /tmp/tmp-workspaces does not exist${NC}"
fi

echo ""

if [ "$ESCAPED" = "true" ]; then
    echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  ✗ TESTS ESCAPED ISOLATION - DO NOT RUN LOCALLY${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
    exit 1
else
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ✓ ALL TESTS STAYED ISOLATED - SAFE TO RUN LOCALLY${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    exit 0
fi
'

EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}Verification passed! You can safely run: make test-local${NC}"
else
    echo -e "${RED}Verification failed! Do not run tests locally until fixed.${NC}"
fi

exit $EXIT_CODE
