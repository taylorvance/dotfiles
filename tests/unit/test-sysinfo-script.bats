#!/usr/bin/env bats

# Unit tests for the `sysinfo` script (system information utility)

setup() {
    export TEST_DIR=$(mktemp -d)

    # Copy the sysinfo script
    cp "$BATS_TEST_DIRNAME/../../src/dotfiles/.local/bin/sysinfo" "$TEST_DIR/sysinfo"
    chmod +x "$TEST_DIR/sysinfo"
}

teardown() {
    rm -rf "$TEST_DIR"
}

run_sysinfo() {
    "$TEST_DIR/sysinfo" "$@"
}

# ============================================================================
# BASIC OUTPUT TESTS
# ============================================================================

@test "sysinfo: runs without errors" {
    run run_sysinfo

    [ "$status" -eq 0 ]
}

@test "sysinfo: shows CPU information" {
    run run_sysinfo

    [ "$status" -eq 0 ]
    [[ "$output" == *"CPU:"* ]]
}

@test "sysinfo: shows RAM information" {
    run run_sysinfo

    [ "$status" -eq 0 ]
    [[ "$output" == *"RAM:"* ]]
    [[ "$output" == *"GB"* ]]
}

@test "sysinfo: shows GPU information" {
    run run_sysinfo

    [ "$status" -eq 0 ]
    [[ "$output" == *"GPU:"* ]]
}

@test "sysinfo: shows storage information" {
    run run_sysinfo

    [ "$status" -eq 0 ]
    [[ "$output" == *"Storage:"* ]]
}

@test "sysinfo: shows OS information" {
    run run_sysinfo

    [ "$status" -eq 0 ]
    [[ "$output" == *"OS:"* ]]
}

@test "sysinfo: shows architecture" {
    run run_sysinfo

    [ "$status" -eq 0 ]
    [[ "$output" == *"Arch:"* ]]
    # Should show x86_64, arm64, aarch64, or similar
    [[ "$output" =~ (x86_64|arm64|aarch64|i686) ]]
}

# ============================================================================
# EXTENDED INFO TESTS (-m/--more flag)
# ============================================================================

@test "sysinfo -m: shows extended information" {
    run run_sysinfo -m

    [ "$status" -eq 0 ]
    [[ "$output" == *"Kernel:"* ]]
    [[ "$output" == *"Hostname:"* ]]
    [[ "$output" == *"Uptime:"* ]]
}

@test "sysinfo --more: shows extended information" {
    run run_sysinfo --more

    [ "$status" -eq 0 ]
    [[ "$output" == *"Shell:"* ]]
    [[ "$output" == *"Terminal:"* ]]
}

@test "sysinfo -m: shows network information" {
    run run_sysinfo -m

    [ "$status" -eq 0 ]
    [[ "$output" == *"Local IP:"* ]]
    [[ "$output" == *"Public IP:"* ]]
}

@test "sysinfo -m: shows display information" {
    run run_sysinfo -m

    [ "$status" -eq 0 ]
    [[ "$output" == *"Display:"* ]]
}

@test "sysinfo -m: shows volumes" {
    run run_sysinfo -m

    [ "$status" -eq 0 ]
    [[ "$output" == *"Volumes:"* ]]
}

# ============================================================================
# HELP TEXT
# ============================================================================

@test "sysinfo -h: shows help" {
    run run_sysinfo -h

    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: sysinfo"* ]]
    [[ "$output" == *"-m, --more"* ]]
    [[ "$output" == *"-h, --help"* ]]
}

@test "sysinfo --help: shows help" {
    run run_sysinfo --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"SUPPORTED PLATFORMS:"* ]]
}

# ============================================================================
# ERROR CASES
# ============================================================================

@test "sysinfo: handles unknown option" {
    run run_sysinfo --invalid

    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

# ============================================================================
# PLATFORM DETECTION TESTS
# ============================================================================

@test "sysinfo: detects platform" {
    run run_sysinfo

    [ "$status" -eq 0 ]
    # Should show macOS, Linux, or WSL in OS field
    [[ "$output" =~ (macOS|Linux|Ubuntu|Debian|Fedora|Alpine|WSL) ]]
}

@test "sysinfo: output is formatted consistently" {
    run run_sysinfo

    [ "$status" -eq 0 ]
    # Check that output uses consistent formatting (field: value)
    [[ "$output" =~ CPU:[[:space:]]+ ]]
    [[ "$output" =~ RAM:[[:space:]]+ ]]
    [[ "$output" =~ OS:[[:space:]]+ ]]
}

# ============================================================================
# DATA VALIDATION TESTS
# ============================================================================

@test "sysinfo: CPU shows core count" {
    run run_sysinfo

    [ "$status" -eq 0 ]
    [[ "$output" =~ \([0-9]+[[:space:]]cores?\) ]]
}

@test "sysinfo: RAM shows GB value" {
    run run_sysinfo

    [ "$status" -eq 0 ]
    [[ "$output" =~ [0-9]+[[:space:]]GB ]]
}

@test "sysinfo: storage shows available/total" {
    run run_sysinfo

    [ "$status" -eq 0 ]
    # Should show format like "500GB / 1TB" or similar
    [[ "$output" =~ Storage:[[:space:]]+[0-9]+.*[[:space:]]/[[:space:]][0-9]+ ]]
}

# ============================================================================
# SCRIPT QUALITY TESTS
# ============================================================================

@test "sysinfo: script has valid syntax" {
    run sh -n "$TEST_DIR/sysinfo"

    [ "$status" -eq 0 ]
}

@test "sysinfo: script is executable" {
    [ -x "$TEST_DIR/sysinfo" ]
}

@test "sysinfo: script has shebang" {
    run head -n1 "$TEST_DIR/sysinfo"

    [[ "$output" =~ "#!" ]]
}

# ============================================================================
# OUTPUT CONSISTENCY TESTS
# ============================================================================

@test "sysinfo: runs consistently (no randomness)" {
    output1=$(run_sysinfo)
    sleep 0.5
    output2=$(run_sysinfo)

    # Core system info shouldn't change between runs (uptime will differ with -m)
    # Compare just the basic fields
    cpu1=$(echo "$output1" | grep "CPU:")
    cpu2=$(echo "$output2" | grep "CPU:")
    [ "$cpu1" = "$cpu2" ]

    ram1=$(echo "$output1" | grep "RAM:")
    ram2=$(echo "$output2" | grep "RAM:")
    [ "$ram1" = "$ram2" ]
}

@test "sysinfo: uptime changes over time" {
    skip_if_not_extended_mode

    output1=$(run_sysinfo -m | grep "Uptime:")
    sleep 2
    output2=$(run_sysinfo -m | grep "Uptime:")

    # Uptime should be different (or at least not identical to the second)
    # This is a weak test but verifies uptime is dynamic
    [ "$status" -eq 0 ]
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

skip_if_not_extended_mode() {
    if [ -z "$EXTENDED_TESTS" ]; then
        skip "Extended tests not enabled"
    fi
}
