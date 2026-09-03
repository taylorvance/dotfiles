#!/usr/bin/env bats

# Unit tests for the `fcd` shell function (fzf-driven cd)
# @covers src/dotfiles/.zsh/functions.zsh
# @covers tests/helpers/fzf.bash

load ../helpers/fzf

setup() {
    # pwd -P: on macOS mktemp returns /var/... but the physical path is
    # /private/var/..., which breaks $PWD comparisons after a cd
    export TEST_DIR=$(cd "$(mktemp -d)" && pwd -P)

    mkdir -p "$TEST_DIR/picked-dir" "$TEST_DIR/other-dir"

    # Source only fcd; the rest of the file needs zsh-specific features
    FUNCTIONS_FILE="$BATS_TEST_DIRNAME/../../src/dotfiles/.zsh/functions.zsh"
    eval "$(sed -n '/^fcd()/,/^}/p' "$FUNCTIONS_FILE")"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# fd is not in the test image, so the directory source is stubbed too
stub_fd() {
    mkdir -p "$TEST_DIR/bin"
    {
        printf '#!/bin/sh\n'
        printf 'printf "%%s\\n" "%s/picked-dir" "%s/other-dir"\n' "$TEST_DIR" "$TEST_DIR"
    } > "$TEST_DIR/bin/fd"
    chmod +x "$TEST_DIR/bin/fd"
    export PATH="$TEST_DIR/bin:$PATH"
}

# ============================================================================
# DEPENDENCY GUARDS
# ============================================================================

@test "fcd: errors when neither fd nor fzf is installed" {
    mkdir -p "$TEST_DIR/empty-bin"
    local real_path="$PATH"
    export PATH="$TEST_DIR/empty-bin"

    run fcd

    export PATH="$real_path"

    [ "$status" -eq 1 ]
    [[ "$output" == *"requires 'fd' and 'fzf'"* ]]
}

@test "fcd: errors when fd is present but fzf is not" {
    stub_fd
    no_fzf
    local real_path="$PATH"
    export PATH="$NO_FZF_PATH"

    run fcd

    export PATH="$real_path"

    [ "$status" -eq 1 ]
    [[ "$output" == *"requires 'fd' and 'fzf'"* ]]
}

@test "fcd: errors when fzf is present but fd is not" {
    stub_fzf_match "picked-dir"
    local real_path="$PATH"
    # The stub dir holds fzf and nothing else, so fd is genuinely absent
    export PATH="$TEST_DIR/bin"

    run fcd

    export PATH="$real_path"

    [ "$status" -eq 1 ]
    [[ "$output" == *"requires 'fd' and 'fzf'"* ]]
}

# ============================================================================
# SELECTION
# ============================================================================

@test "fcd: cds to the directory picked with fzf" {
    stub_fd
    stub_fzf_match "picked-dir"

    cd "$TEST_DIR"
    # Called directly, not via run: a subshell would discard the cd
    fcd

    [ "$PWD" = "$TEST_DIR/picked-dir" ]
}

@test "fcd: offers the directories fd found" {
    stub_fd
    stub_fzf_none

    cd "$TEST_DIR"
    fcd

    offered=$(fzf_candidates)
    [[ "$offered" == *"picked-dir"* ]]
    [[ "$offered" == *"other-dir"* ]]
}

@test "fcd: stays put when nothing is selected" {
    stub_fd
    stub_fzf_none

    cd "$TEST_DIR"
    fcd

    [ "$PWD" = "$TEST_DIR" ]
}
