#!/usr/bin/env bats

# Unit tests for macos.sh
# The script is macOS-only; in the Linux test container the platform guard
# must exit 0 without touching anything.

setup() {
    export TEST_DIR=$(mktemp -d)
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "macos: has valid bash syntax" {
    run bash -n "$BATS_TEST_DIRNAME/../../src/macos.sh"
    [ "$status" -eq 0 ]
}

@test "macos: is executable" {
    [ -x "$BATS_TEST_DIRNAME/../../src/macos.sh" ]
}

@test "macos: exits cleanly on non-macOS" {
    if [[ "$OSTYPE" == darwin* ]]; then
        skip "host is macOS (run inside the test container)"
    fi
    run bash "$BATS_TEST_DIRNAME/../../src/macos.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "skipping" ]]
}
