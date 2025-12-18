#!/usr/bin/env bats

# Unit tests for the `tmp` script (temporary workspace creator)

setup() {
    export TEST_DIR=$(mktemp -d)
    export TMP_BASE="$TEST_DIR/tmp-workspaces"

    # Copy the tmp script
    cp "$BATS_TEST_DIRNAME/../../src/dotfiles/.local/bin/tmp" "$TEST_DIR/tmp"
    chmod +x "$TEST_DIR/tmp"

    # Modify script to use TEST_DIR instead of default location (portable sed)
    # Pattern matches: TMP_BASE="${TMPDIR:-/tmp}/tmp-workspaces" or TMP_BASE="/tmp/tmp-workspaces"
    if sed --version 2>&1 | grep -q GNU; then
        # GNU sed (Linux)
        sed -i "s|TMP_BASE=.*tmp-workspaces.*|TMP_BASE=\"$TMP_BASE\"|" "$TEST_DIR/tmp"
    else
        # BSD sed (macOS)
        sed -i '' "s|TMP_BASE=.*tmp-workspaces.*|TMP_BASE=\"$TMP_BASE\"|" "$TEST_DIR/tmp"
    fi
}

teardown() {
    rm -rf "$TEST_DIR"
}

run_tmp() {
    "$TEST_DIR/tmp" "$@"
}

# ============================================================================
# BASIC CREATION TESTS
# ============================================================================

@test "tmp: creates new workspace" {
    run run_tmp

    [ "$status" -eq 0 ]
    [[ "$output" == *"Created temporary workspace"* ]]
    [[ "$output" == *"cd \"$TMP_BASE/"* ]]
}

@test "tmp: workspace directory exists after creation" {
    run_tmp > /dev/null 2>&1

    [ -d "$TMP_BASE" ]
    [ "$(ls -1 "$TMP_BASE" | wc -l)" -eq 1 ]
}

@test "tmp: creates timestamped directory" {
    output=$(run_tmp)

    # Extract timestamp from output
    timestamp=$(echo "$output" | grep -o '[0-9]\{8\}-[0-9]\{6\}' | head -1)

    [ -n "$timestamp" ]
    [ -d "$TMP_BASE/$timestamp" ]
}

# ============================================================================
# RECENT WORKSPACE TESTS (-r flag)
# ============================================================================

@test "tmp -r: returns most recent workspace" {
    # Create two workspaces with delay
    run_tmp > /dev/null
    sleep 1
    run_tmp > /dev/null

    # Get the most recent
    run run_tmp -r

    [ "$status" -eq 0 ]
    [[ "$output" == *"cd \"$TMP_BASE/"* ]]
}

@test "tmp -r: fails when no workspaces exist" {
    run run_tmp -r

    [ "$status" -eq 1 ]
    [[ "$output" == *"No temporary workspaces found"* ]]
}

@test "tmp -r: cd command is valid" {
    run_tmp > /dev/null
    output=$(run_tmp -r)

    # Extract cd command and verify it's a valid path
    cd_path=$(echo "$output" | grep '^cd ' | sed 's/cd "\(.*\)"/\1/')

    [ -d "$cd_path" ]
}

# ============================================================================
# LIST/SELECT WORKSPACE TESTS (-l flag)
# ============================================================================

@test "tmp -l: shows existing workspaces" {
    # Create workspaces
    run_tmp > /dev/null
    sleep 1
    run_tmp > /dev/null

    # Run with empty selection (should fall through to create new)
    run bash -c "echo '' | $TEST_DIR/tmp -l"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Existing temp workspaces:"* ]]
}

@test "tmp -l: creates new when no workspaces exist" {
    run bash -c "echo '' | $TEST_DIR/tmp -l"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Created temporary workspace"* ]]
}

@test "tmp -l: selects workspace by number" {
    # Create two workspaces
    run_tmp > /dev/null
    sleep 1
    run_tmp > /dev/null

    # Select first one (most recent)
    run bash -c "echo '1' | $TEST_DIR/tmp -l"

    [ "$status" -eq 0 ]
    [[ "$output" == *"cd \"$TMP_BASE/"* ]]
}

@test "tmp -l: rejects invalid selection" {
    run_tmp > /dev/null

    # Try to select workspace 999
    run bash -c "echo '999' | $TEST_DIR/tmp -l"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid selection"* ]]
}

# ============================================================================
# EDIT MODE TESTS (-e flag)
# ============================================================================

@test "tmp -e: creates workspace and outputs EDITOR_CMD marker" {
    run run_tmp -e

    [ "$status" -eq 0 ]
    [[ "$output" == *"Created temporary workspace"* ]]
    [[ "$output" == *'cd "'* ]]
    [[ "$output" == *"EDITOR_CMD:"* ]]
}

@test "tmp -e: workspace directory exists" {
    output=$(run_tmp -e)

    # Extract the directory from cd command
    dir=$(echo "$output" | grep '^cd ' | sed 's/cd "\(.*\)"/\1/')

    [ -d "$dir" ]
}

@test "tmp -e: outputs cd and EDITOR_CMD with default filename" {
    run run_tmp -e

    [ "$status" -eq 0 ]

    # Should have cd command
    echo "$output" | grep -q '^cd '

    # Should have EDITOR_CMD with scratch.txt
    echo "$output" | grep -q '^EDITOR_CMD:scratch\.txt$'
}

@test "tmp -e custom.py: uses custom filename" {
    run run_tmp -e custom.py

    [ "$status" -eq 0 ]

    # Should have cd command
    echo "$output" | grep -q '^cd '

    # Should have EDITOR_CMD with custom filename
    echo "$output" | grep -q '^EDITOR_CMD:custom\.py$'
}

# ============================================================================
# DELETE WORKSPACE TESTS (-d flag)
# ============================================================================

@test "tmp -d: shows workspaces to delete" {
    run_tmp > /dev/null

    run bash -c "echo '' | $TEST_DIR/tmp -d"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Temp workspaces:"* ]]
}

@test "tmp -d: cancels on empty input" {
    run_tmp > /dev/null

    run bash -c "echo '' | $TEST_DIR/tmp -d"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Cancelled"* ]]
    # Workspace should still exist
    [ "$(ls -1 "$TMP_BASE" | wc -l)" -eq 1 ]
}

@test "tmp -d: deletes all with 'a'" {
    run_tmp > /dev/null
    run_tmp > /dev/null

    run bash -c "echo 'a' | $TEST_DIR/tmp -d"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Deleting all workspaces"* ]]
    # All workspaces should be deleted
    [ ! -d "$TMP_BASE" ] || [ -z "$(ls -A "$TMP_BASE")" ]
}

@test "tmp -d: deletes all with 'all'" {
    run_tmp > /dev/null

    run bash -c "echo 'all' | $TEST_DIR/tmp -d"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Deleting all workspaces"* ]]
}

@test "tmp -d: deletes specific workspace by number" {
    run_tmp > /dev/null
    sleep 1
    run_tmp > /dev/null

    initial_count=$(ls -1 "$TMP_BASE" | wc -l | tr -d ' ')

    # Delete first workspace (most recent)
    run bash -c "echo '1' | $TEST_DIR/tmp -d"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Deleted:"* ]]

    final_count=$(ls -1 "$TMP_BASE" | wc -l | tr -d ' ')
    [ "$final_count" -eq $((initial_count - 1)) ]
}

@test "tmp -d: deletes multiple workspaces" {
    # Create 3 workspaces
    run_tmp > /dev/null
    sleep 1
    run_tmp > /dev/null
    sleep 1
    run_tmp > /dev/null

    # Delete workspace 1 and 3
    run bash -c "echo '1 3' | $TEST_DIR/tmp -d"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Deleted 2 workspace(s)"* ]]

    remaining=$(ls -1 "$TMP_BASE" | wc -l | tr -d ' ')
    [ "$remaining" -eq 1 ]
}

@test "tmp -d: handles invalid numbers gracefully" {
    run_tmp > /dev/null

    run bash -c "echo '999' | $TEST_DIR/tmp -d"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Invalid number: 999"* ]]
    [[ "$output" == *"No workspaces deleted"* ]]
}

@test "tmp -d: no workspaces to delete" {
    run run_tmp -d

    [ "$status" -eq 0 ]
    [[ "$output" == *"No temporary workspaces to delete"* ]]
}

# ============================================================================
# HELP TEXT
# ============================================================================

@test "tmp -h: shows help" {
    run run_tmp -h

    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: tmp"* ]]
    [[ "$output" == *"-l"* ]]
    [[ "$output" == *"-r"* ]]
    [[ "$output" == *"-e"* ]]
    [[ "$output" == *"-d"* ]]
}

# ============================================================================
# ERROR CASES
# ============================================================================

@test "tmp: handles unknown option" {
    run run_tmp -z

    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

@test "tmp: output is eval-friendly" {
    output=$(run_tmp)

    # Should contain a valid cd command that can be eval'd
    [[ "$output" == *'cd "'* ]]

    # Extract and verify cd command
    cd_cmd=$(echo "$output" | grep '^cd ' | tail -1)
    [ -n "$cd_cmd" ]
}

@test "tmp: creates unique timestamps" {
    output1=$(run_tmp)
    sleep 1  # Ensure timestamps differ
    output2=$(run_tmp)

    # Extract directory names
    dir1=$(echo "$output1" | grep 'cd "' | sed 's/.*cd "\(.*\)"/\1/')
    dir2=$(echo "$output2" | grep 'cd "' | sed 's/.*cd "\(.*\)"/\1/')

    [ "$dir1" != "$dir2" ]
    [ -d "$dir1" ]
    [ -d "$dir2" ]
}

# ============================================================================
# TMPDIR ENVIRONMENT VARIABLE TESTS
# ============================================================================

@test "tmp: respects TMPDIR environment variable" {
    # Setup: Create a fresh tmp script without the test override
    cp "$BATS_TEST_DIRNAME/../../src/dotfiles/.local/bin/tmp" "$TEST_DIR/tmp-original"
    chmod +x "$TEST_DIR/tmp-original"

    # Create custom temp directory (use a simple path without special chars)
    custom_tmp="$TEST_DIR/customtmp"
    mkdir -p "$custom_tmp"

    # Run with custom TMPDIR (remove any trailing slash for consistent comparison)
    output=$(TMPDIR="$custom_tmp" "$TEST_DIR/tmp-original" 2>&1)

    # Assert: workspace should be created in custom TMPDIR
    # Check that the directory was created
    [ -d "$custom_tmp/tmp-workspaces" ]
    # Check output mentions the custom path
    [[ "$output" == *"tmp-workspaces"* ]]
}

@test "tmp: falls back to /tmp when TMPDIR not set" {
    # This test verifies the fallback behavior
    # The script uses ${TMPDIR:-/tmp} so unsetting TMPDIR should use /tmp
    cp "$BATS_TEST_DIRNAME/../../src/dotfiles/.local/bin/tmp" "$TEST_DIR/tmp-original"
    chmod +x "$TEST_DIR/tmp-original"

    # Run without TMPDIR (unset it explicitly)
    unset TMPDIR
    output=$("$TEST_DIR/tmp-original")

    # Assert: should use /tmp
    [[ "$output" == *"/tmp/tmp-workspaces/"* ]]

    # Cleanup
    rm -rf /tmp/tmp-workspaces
}
