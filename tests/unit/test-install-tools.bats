#!/usr/bin/env bats

# Unit tests for install-tools.sh
# Runs the real script against mock package managers on an isolated PATH/HOME.

setup() {
    export TEST_DIR=$(mktemp -d)
    export TEST_SCRIPT="$TEST_DIR/install-tools.sh"
    cp "$BATS_TEST_DIRNAME/../../src/install-tools.sh" "$TEST_SCRIPT"

    # Mocks take precedence over real binaries
    export MOCK_BIN="$TEST_DIR/bin"
    mkdir -p "$MOCK_BIN"
    export PATH="$MOCK_BIN:$PATH"

    # Isolate HOME so antigen/bat-theme detection doesn't see real files
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"

    # Keep tests offline: downloads fail fast and deterministically
    create_mock failure curl
    create_mock failure wget
}

teardown() {
    rm -rf "$TEST_DIR"
}

# create_mock {success|failure} NAME
create_mock() {
    local result=$1
    local cmd=$2
    if [ "$result" = "success" ]; then
        printf '#!/bin/bash\nexit 0\n' > "$MOCK_BIN/$cmd"
    else
        printf '#!/bin/bash\nexit 1\n' > "$MOCK_BIN/$cmd"
    fi
    chmod +x "$MOCK_BIN/$cmd"
}

# Mock brew that fails only for the given package names
create_brew_failing_for() {
    {
        printf '#!/bin/bash\n'
        printf 'case "$2" in\n'
        local pkg
        for pkg in "$@"; do
            printf '    %s) exit 1 ;;\n' "$pkg"
        done
        printf '    *) exit 0 ;;\nesac\n'
    } > "$MOCK_BIN/brew"
    chmod +x "$MOCK_BIN/brew"
}

# ============================================================================
# PACKAGE MANAGER DETECTION
# ============================================================================

@test "install-tools: prefers brew when available" {
    create_mock success brew
    run bash "$TEST_SCRIPT" -y
    [[ "$output" =~ "Package manager: brew" ]]
}

@test "install-tools: errors helpfully with no package manager" {
    if command -v brew >/dev/null 2>&1 || command -v apt-get >/dev/null 2>&1 \
        || command -v dnf >/dev/null 2>&1 || command -v pacman >/dev/null 2>&1; then
        skip "host has a real package manager (run inside the test container)"
    fi
    run bash "$TEST_SCRIPT" -y
    [ "$status" -eq 1 ]
    [[ "$output" =~ "No package manager found" ]]
}

# ============================================================================
# FAILURE HANDLING (set -e must not eat the summary)
# ============================================================================

@test "install-tools: successful run prints summary and exits 0" {
    create_mock success brew
    run bash "$TEST_SCRIPT" -y
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Installation Summary" ]]
    [[ "$output" =~ "Installation complete" ]]
}

@test "install-tools: core tool failure still reaches summary and exits 1" {
    # unzip is not preinstalled in the test container, so it must go
    # through the (failing) mock package manager
    create_mock failure brew
    run bash "$TEST_SCRIPT" -y
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Critical tools failed" ]]
    [[ "$output" =~ "unzip" ]]
    [[ "$output" =~ "Installation Summary" ]]
}

@test "install-tools: optional tool failure is not critical" {
    create_brew_failing_for fzf
    run bash "$TEST_SCRIPT" -y
    [ "$status" -eq 0 ]
    [[ "$output" =~ "fzf (not available in repos)" ]]
    [[ "$output" =~ "aren't critical" ]]
}

@test "install-tools: failed optional language tools do not abort setup" {
    create_brew_failing_for ollama dotnet php
    run bash -c "printf 'y\ny\ny\n' | bash '$TEST_SCRIPT'"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Optional tools not available" ]]
    [[ ! "$output" =~ "Critical tools failed" ]]
    [[ "$output" =~ "Installation complete" ]]
}

# ============================================================================
# INTERACTIVE PROMPTS
# ============================================================================

@test "install-tools: declining a prompt skips the tool" {
    create_mock success brew
    run bash -c "printf 'n\nn\nn\n' | bash '$TEST_SCRIPT'"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "ollama (skipped)" ]]
}

@test "install-tools: EOF at a prompt declines instead of crashing" {
    create_mock success brew
    run bash -c "bash '$TEST_SCRIPT' < /dev/null"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Installation complete" ]]
}

@test "install-tools: -y skips language tool prompts entirely" {
    create_mock success brew
    run bash "$TEST_SCRIPT" -y
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Skipping optional language tools" ]]
}

# ============================================================================
# TOOL DETECTION
# ============================================================================

@test "install-tools: reports preinstalled tools as already present" {
    create_mock success brew
    create_mock success git
    run bash "$TEST_SCRIPT" -y
    [ "$status" -eq 0 ]
    [[ "$output" =~ "git (already installed)" ]]
}

@test "install-tools: antigen detected via antigen.zsh file, not a command" {
    create_mock success brew
    mkdir -p "$HOME/.zsh"
    echo "# antigen" > "$HOME/.zsh/antigen.zsh"
    run bash "$TEST_SCRIPT" -y
    [ "$status" -eq 0 ]
    [[ "$output" =~ "antigen (already installed)" ]]
}

@test "install-tools: antigen download failure is non-critical" {
    create_brew_failing_for antigen
    run bash "$TEST_SCRIPT" -y
    [ "$status" -eq 0 ]
    [[ "$output" =~ "antigen (download failed)" ]]
}

# ============================================================================
# MISE / NODE
# ============================================================================

@test "install-tools: mise install failure is non-critical" {
    create_brew_failing_for mise
    run bash "$TEST_SCRIPT" -y
    [ "$status" -eq 0 ]
    [[ "$output" =~ "mise (install failed" ]]
    [[ ! "$output" =~ "Critical tools failed" ]]
}

@test "install-tools: mise detected at ~/.local/bin/mise" {
    create_mock success brew
    mkdir -p "$HOME/.local/bin"
    printf '#!/bin/bash\nexit 0\n' > "$HOME/.local/bin/mise"
    chmod +x "$HOME/.local/bin/mise"
    run bash "$TEST_SCRIPT" -y
    [ "$status" -eq 0 ]
    [[ "$output" =~ "mise (already installed)" ]]
}

@test "install-tools: node defers to mise when mise is present" {
    if command -v node >/dev/null 2>&1; then
        skip "host has node installed (run inside the test container)"
    fi
    create_mock success brew
    create_mock success mise
    run bash "$TEST_SCRIPT" -y
    [ "$status" -eq 0 ]
    [[ "$output" =~ "node (run 'mise install' after 'make link')" ]]
}

# ============================================================================
# BASICS
# ============================================================================

@test "install-tools: has valid bash syntax" {
    run bash -n "$TEST_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "install-tools: is executable" {
    [ -x "$BATS_TEST_DIRNAME/../../src/install-tools.sh" ]
}

@test "install-tools: rejects unknown options" {
    run bash "$TEST_SCRIPT" --bogus
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Usage" ]]
}
