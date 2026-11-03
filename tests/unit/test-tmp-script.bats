#!/usr/bin/env bats

# Unit tests for the `tmp` script (temporary workspace creator)
# @covers src/dotfiles/.local/bin/tmp
# @covers src/dotfiles/.zsh/functions.zsh

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
}

@test "tmp: stdout is only the workspace path; messages go to stderr" {
    stdout=$(run_tmp 2>/dev/null)

    [ "$(echo "$stdout" | wc -l | tr -d ' ')" -eq 1 ]
    [[ "$stdout" == "$TMP_BASE/"* ]]
    [ -d "$stdout" ]
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
    # Create two workspaces
    run_tmp > /dev/null
    run_tmp > /dev/null

    # Get the most recent
    run run_tmp -r

    [ "$status" -eq 0 ]
    [[ "$output" == "$TMP_BASE/"* ]]
}

@test "tmp -r: fails when no workspaces exist" {
    run run_tmp -r

    [ "$status" -eq 1 ]
    [[ "$output" == *"No temporary workspaces found"* ]]
}

@test "tmp -r: prints an existing directory" {
    run_tmp > /dev/null
    dir=$(run_tmp -r)

    [ -d "$dir" ]
}

# ============================================================================
# LIST/SELECT WORKSPACE TESTS (-l flag)
# ============================================================================

@test "tmp -l: shows existing workspaces" {
    # Create workspaces
    run_tmp > /dev/null
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

@test "tmp -l: Enter still creates new when workspaces exist" {
    run_tmp > /dev/null

    run bash -c "echo '' | $TEST_DIR/tmp -l"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Created temporary workspace"* ]]
}

@test "tmp -l: aborts on EOF instead of creating a workspace" {
    run_tmp > /dev/null
    before=$(ls -1 "$TMP_BASE" | wc -l)

    run bash -c "$TEST_DIR/tmp -l < /dev/null"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Aborted."* ]]
    [[ "$output" != *"Created temporary workspace"* ]]
    [ "$(ls -1 "$TMP_BASE" | wc -l)" -eq "$before" ]
}

@test "tmp -l: selects workspace by number" {
    # Create two workspaces
    run_tmp > /dev/null
    run_tmp > /dev/null

    # Select first one (most recent)
    dir=$(echo '1' | "$TEST_DIR/tmp" -l 2>/dev/null)

    [[ "$dir" == "$TMP_BASE/"* ]]
    [ -d "$dir" ]
}

@test "tmp -l: listing includes a contents preview" {
    # Workspace with a couple of files
    output=$(run_tmp)
    dir=$(echo "$output" | head -1)
    touch "$dir/test.py" "$dir/data.csv"

    run bash -c "echo '' | $TEST_DIR/tmp -l"

    [ "$status" -eq 0 ]
    [[ "$output" == *"test.py"* ]]
    [[ "$output" == *"data.csv"* ]]
}

@test "tmp -l: preview shows (empty) and truncates with +N more" {
    # One empty workspace, one with 5 files
    run_tmp > /dev/null
    output=$(run_tmp)
    dir=$(echo "$output" | head -1)
    touch "$dir/a" "$dir/b" "$dir/c" "$dir/d" "$dir/e"

    run bash -c "echo '' | $TEST_DIR/tmp -l"

    [ "$status" -eq 0 ]
    [[ "$output" == *"(empty)"* ]]
    [[ "$output" == *"+2 more"* ]]
}

@test "tmp -l: rejects invalid selection" {
    run_tmp > /dev/null

    # Try to select workspace 999
    run bash -c "echo '999' | $TEST_DIR/tmp -l"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid selection"* ]]
}

# ============================================================================
# FILENAME ARGUMENT TESTS
# ============================================================================

@test "tmp FILE: prints the workspace, then the filename" {
    stdout=$(run_tmp custom.py 2>/dev/null)

    [ -d "$(echo "$stdout" | sed -n 1p)" ]
    [ "$(echo "$stdout" | sed -n 2p)" = "custom.py" ]
    [ "$(echo "$stdout" | wc -l | tr -d ' ')" -eq 2 ]
}

@test "tmp FILE...: prints one line per filename, in order" {
    stdout=$(run_tmp notes.md test.py 2>/dev/null)

    [ "$(echo "$stdout" | sed -n 2p)" = "notes.md" ]
    [ "$(echo "$stdout" | sed -n 3p)" = "test.py" ]
    [ "$(echo "$stdout" | wc -l | tr -d ' ')" -eq 3 ]
}

@test "tmp sub/file: creates parent directories inside the workspace" {
    stdout=$(run_tmp sub/dir/file.txt 2>/dev/null)

    dir=$(echo "$stdout" | sed -n 1p)

    [ -d "$dir/sub/dir" ]
    [ "$(echo "$stdout" | sed -n 2p)" = "sub/dir/file.txt" ]
}

@test "tmp -e: is no longer a valid option" {
    run run_tmp -e

    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
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

@test "tmp -d: aborts on EOF" {
    run_tmp > /dev/null

    run bash -c "$TEST_DIR/tmp -d < /dev/null"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Aborted."* ]]
    # Workspace should still exist
    [ "$(ls -1 "$TMP_BASE" | wc -l)" -eq 1 ]
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
    run_tmp > /dev/null
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

@test "tmp --help: shows help" {
    run run_tmp --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: tmp"* ]]
    # No workspace created as a side effect
    [ ! -d "$TMP_BASE" ]
}

@test "tmp: rejects combined mode flags" {
    for combo in "-r -d" "-l -d" "-r -l" "-r -l -d"; do
        # shellcheck disable=SC2086  # deliberate word splitting of the combo
        run run_tmp $combo

        [ "$status" -eq 1 ]
        [[ "$output" == *"cannot be combined"* ]]
    done

    # Nothing was created or deleted on the way out
    [ ! -d "$TMP_BASE" ]
}

@test "tmp -h: shows help" {
    run run_tmp -h

    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: tmp"* ]]
    [[ "$output" == *"-l"* ]]
    [[ "$output" == *"-r"* ]]
    [[ "$output" == *"-d"* ]]
    [[ "$output" == *"FILE"* ]]
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

@test "tmp: same-second runs get a numbered suffix" {
    # Freeze date so every run computes an identical timestamp. Real `date`
    # can't be forced into one second, so this is what actually guarantees the
    # collision path runs.
    mkdir -p "$TEST_DIR/bin"
    printf '#!/bin/sh\necho "20260101-000000"\n' > "$TEST_DIR/bin/date"
    chmod +x "$TEST_DIR/bin/date"

    dir1=$(PATH="$TEST_DIR/bin:$PATH" run_tmp | head -1)
    dir2=$(PATH="$TEST_DIR/bin:$PATH" run_tmp | head -1)
    dir3=$(PATH="$TEST_DIR/bin:$PATH" run_tmp | head -1)

    [ "$(basename "$dir1")" = "20260101-000000" ]
    [ "$(basename "$dir2")" = "20260101-000000-2" ]
    [ "$(basename "$dir3")" = "20260101-000000-3" ]
    [ -d "$dir1" ]
    [ -d "$dir2" ]
    [ -d "$dir3" ]
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
    # Verify the script contains correct fallback logic (static analysis)
    # This avoids writing to real /tmp which would break test isolation
    cp "$BATS_TEST_DIRNAME/../../src/dotfiles/.local/bin/tmp" "$TEST_DIR/tmp-original"

    # Assert: script uses ${TMPDIR:-/tmp} pattern for fallback
    grep -q 'TMPDIR:-/tmp' "$TEST_DIR/tmp-original"
}

# ============================================================================
# SHELL WRAPPER (functions.zsh tmp())
# ============================================================================

# The wrapper cds to the script's first stdout line and opens the rest in
# $EDITOR. These tests source functions.zsh in bash (it is bash-compatible, like the gw
# tests) with HOME pointed at an isolated dir containing the patched script.

setup_wrapper() {
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME/.local/bin"
    cp "$TEST_DIR/tmp" "$HOME/.local/bin/tmp"
    source "$BATS_TEST_DIRNAME/../../src/dotfiles/.zsh/functions.zsh"
}

@test "tmp wrapper: cds into the new workspace" {
    setup_wrapper

    tmp > /dev/null

    [[ "$PWD" == "$TMP_BASE/"* ]]
}

@test "tmp wrapper: shows messages, consumes the path" {
    setup_wrapper

    stdout=$(tmp 2>/dev/null)
    combined=$(tmp 2>&1)

    [ -z "$stdout" ]
    [[ "$combined" == *"Created temporary workspace"* ]]
}

@test "tmp wrapper: -h shows help without changing directory" {
    setup_wrapper
    before=$PWD

    output=$(tmp -h)

    [[ "$output" == *"Usage: tmp"* ]]
    [ "$PWD" = "$before" ]
}

@test "tmp wrapper: opens editor with the filename" {
    setup_wrapper
    export EDITOR="$TEST_DIR/mock-editor"
    cat > "$EDITOR" <<EOF
#!/bin/bash
echo "EDITED:\$*" > "$TEST_DIR/editor.log"
EOF
    chmod +x "$EDITOR"

    tmp notes.py > /dev/null

    [ -f "$TEST_DIR/editor.log" ]
    grep -q "EDITED:notes.py" "$TEST_DIR/editor.log"
    [[ "$PWD" == "$TMP_BASE/"* ]]
}

@test "tmp wrapper: opens multiple files in one editor invocation" {
    setup_wrapper
    export EDITOR="$TEST_DIR/mock-editor"
    cat > "$EDITOR" <<EOF
#!/bin/bash
echo "EDITED:\$*" > "$TEST_DIR/editor.log"
EOF
    chmod +x "$EDITOR"

    tmp notes.md test.py > /dev/null

    [ -f "$TEST_DIR/editor.log" ]
    grep -q "EDITED:notes.md test.py" "$TEST_DIR/editor.log"
}

@test "tmp wrapper: propagates failure exit code" {
    setup_wrapper

    run tmp -r

    [ "$status" -eq 1 ]
}
