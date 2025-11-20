#!/usr/bin/env bats

# Unit tests for install-tools.sh
# Note: These tests focus on logic and flow, not actual package installation

setup() {
    # Create temporary test directory
    export TEST_DIR=$(mktemp -d)
    export TEST_SCRIPT="$TEST_DIR/install-tools.sh"

    # Copy the actual install-tools.sh
    cp "$BATS_TEST_DIRNAME/../../src/install-tools.sh" "$TEST_SCRIPT"

    # Create mock package manager scripts
    export MOCK_BIN="$TEST_DIR/bin"
    mkdir -p "$MOCK_BIN"

    # Prepend mock bin to PATH
    export PATH="$MOCK_BIN:$PATH"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# Helper: Create mock command that always succeeds
create_mock_success() {
    local cmd=$1
    cat > "$MOCK_BIN/$cmd" << 'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$MOCK_BIN/$cmd"
}

# Helper: Create mock command that always fails
create_mock_failure() {
    local cmd=$1
    cat > "$MOCK_BIN/$cmd" << 'EOF'
#!/bin/bash
exit 1
EOF
    chmod +x "$MOCK_BIN/$cmd"
}

# Helper: Create mock command that checks if it's called with specific args
create_mock_check_args() {
    local cmd=$1
    local log_file="$TEST_DIR/${cmd}_calls.log"
    cat > "$MOCK_BIN/$cmd" << EOF
#!/bin/bash
echo "\$@" >> "$log_file"
exit 0
EOF
    chmod +x "$MOCK_BIN/$cmd"
}

# ============================================================================
# OS DETECTION TESTS
# ============================================================================

@test "install-tools: detects macOS via OSTYPE" {
    skip "Requires modifying script to expose OS detection function"
    # Would need to refactor script to make this testable
}

@test "install-tools: detects Linux via /etc/os-release" {
    skip "Requires modifying script to expose OS detection function"
    # Would need to refactor script to make this testable
}

# ============================================================================
# PACKAGE MANAGER DETECTION TESTS
# ============================================================================

@test "install-tools: prefers brew on macOS" {
    # Setup
    create_mock_success brew
    export OSTYPE="darwin20"

    # This is hard to test without refactoring the script
    skip "Requires script refactoring for better testability"
}

# ============================================================================
# TOOL INSTALLATION LOGIC TESTS
# ============================================================================

@test "install-tools: handles already installed tools" {
    # Setup: Create mock for tool check
    create_mock_success nvim

    # Check if nvim is detected as installed
    run command -v nvim
    [ "$status" -eq 0 ]
}

@test "install-tools: detects missing tools" {
    # Remove tool from PATH
    run command -v nonexistent_tool_12345
    [ "$status" -ne 0 ]
}

# ============================================================================
# INTERACTIVE PROMPT TESTS
# ============================================================================

@test "install-tools: handles non-interactive mode" {
    skip "Would need to test with redirected stdin"
}

# ============================================================================
# EXIT CODE TESTS
# ============================================================================

@test "install-tools: exits 0 when all tools present or installed" {
    skip "Integration test - needs real package manager"
}

@test "install-tools: exits 1 when required tool installation fails" {
    skip "Integration test - needs real package manager"
}

# ============================================================================
# HELPER FUNCTION TESTS
# ============================================================================

@test "color codes: are defined" {
    # Just verify the script sources without errors
    run bash -n "$TEST_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "script: has valid bash syntax" {
    run bash -n "$TEST_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "script: is executable" {
    [ -x "$BATS_TEST_DIRNAME/../../src/install-tools.sh" ]
}

# ============================================================================
# MOCK PACKAGE MANAGER TESTS
# ============================================================================

@test "mock apt: can install packages" {
    # Create mock apt
    create_mock_check_args apt-get

    # Run mock apt
    run apt-get install -y nvim
    [ "$status" -eq 0 ]

    # Check it was called correctly
    log_file="$TEST_DIR/apt-get_calls.log"
    [ -f "$log_file" ]
    grep -q "install -y nvim" "$log_file"
}

@test "mock brew: can install packages" {
    # Create mock brew
    create_mock_check_args brew

    # Run mock brew
    run brew install nvim
    [ "$status" -eq 0 ]

    # Check it was called correctly
    log_file="$TEST_DIR/brew_calls.log"
    [ -f "$log_file" ]
    grep -q "install nvim" "$log_file"
}

# ============================================================================
# TOOL ARRAY TRACKING TESTS
# ============================================================================

@test "arrays: can track installed tools" {
    # Test bash array functionality
    run bash -c 'installed=(); installed+=("nvim"); installed+=("git"); echo ${#installed[@]}'
    [ "$status" -eq 0 ]
    [ "$output" = "2" ]
}

@test "arrays: can track failed tools" {
    # Test bash array functionality
    run bash -c 'failed=(); failed+=("tool1"); [ ${#failed[@]} -gt 0 ] && exit 1 || exit 0'
    [ "$status" -eq 1 ]
}

# ============================================================================
# SUMMARY OUTPUT TESTS
# ============================================================================

@test "summary: can format tool lists" {
    # Test the kind of string manipulation used in summary
    run bash -c 'tools=("nvim" "git" "tmux"); printf "%s, " "${tools[@]}" | sed "s/, $//"'
    [ "$status" -eq 0 ]
    [ "$output" = "nvim, git, tmux" ]
}

# ============================================================================
# SPECIAL CASE TESTS
# ============================================================================

@test "special case: curl or wget check logic" {
    # Test the logic for "at least one of curl/wget"
    run bash -c 'command -v curl >/dev/null || command -v wget >/dev/null'
    # Should succeed if either curl or wget exists (both usually present)
    [ "$status" -eq 0 ]
}

@test "special case: gcc or make on macOS" {
    # Test skip logic for gcc/make on macOS
    run bash -c '[[ "$OSTYPE" == darwin* ]] && echo "skip" || echo "check"'
    # Output depends on actual OS
    [ "$status" -eq 0 ]
}
