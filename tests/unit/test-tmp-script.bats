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
    # Create two workspaces
    run_tmp > /dev/null
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
    run bash -c "echo '1' | $TEST_DIR/tmp -l"

    [ "$status" -eq 0 ]
    [[ "$output" == *"cd \"$TMP_BASE/"* ]]
}

@test "tmp -l: listing includes a contents preview" {
    # Workspace with a couple of files
    output=$(run_tmp)
    dir=$(echo "$output" | grep '^cd ' | sed 's/cd "\(.*\)"/\1/')
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
    dir=$(echo "$output" | grep '^cd ' | sed 's/cd "\(.*\)"/\1/')
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

@test "tmp FILE: outputs cd and EDITOR_CMD with the filename" {
    run run_tmp custom.py

    [ "$status" -eq 0 ]
    [[ "$output" == *"Created temporary workspace"* ]]
    echo "$output" | grep -q '^cd '
    echo "$output" | grep -q '^EDITOR_CMD:custom\.py$'
}

@test "tmp FILE...: outputs one EDITOR_CMD line per filename" {
    run run_tmp notes.md test.py

    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^EDITOR_CMD:notes\.md$'
    echo "$output" | grep -q '^EDITOR_CMD:test\.py$'
    [ "$(echo "$output" | grep -c '^EDITOR_CMD:')" -eq 2 ]
}

@test "tmp: no filenames means no EDITOR_CMD lines" {
    run run_tmp

    [ "$status" -eq 0 ]
    ! echo "$output" | grep -q '^EDITOR_CMD:'
}

@test "tmp sub/file: creates parent directories inside the workspace" {
    output=$(run_tmp sub/dir/file.txt)

    dir=$(echo "$output" | grep '^cd ' | sed 's/cd "\(.*\)"/\1/')

    [ -d "$dir/sub/dir" ]
    echo "$output" | grep -q '^EDITOR_CMD:sub/dir/file\.txt$'
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

@test "tmp: output is eval-friendly" {
    output=$(run_tmp)

    # Should contain a valid cd command that can be eval'd
    [[ "$output" == *'cd "'* ]]

    # Extract and verify cd command
    cd_cmd=$(echo "$output" | grep '^cd ' | tail -1)
    [ -n "$cd_cmd" ]
}

@test "tmp: same-second runs get a numbered suffix" {
    # Freeze date so every run computes an identical timestamp. Real `date`
    # can't be forced into one second, so this is what actually guarantees the
    # collision path runs.
    mkdir -p "$TEST_DIR/bin"
    printf '#!/bin/sh\necho "20260101-000000"\n' > "$TEST_DIR/bin/date"
    chmod +x "$TEST_DIR/bin/date"

    dir1=$(PATH="$TEST_DIR/bin:$PATH" run_tmp | sed -n 's/^cd "\(.*\)"$/\1/p')
    dir2=$(PATH="$TEST_DIR/bin:$PATH" run_tmp | sed -n 's/^cd "\(.*\)"$/\1/p')
    dir3=$(PATH="$TEST_DIR/bin:$PATH" run_tmp | sed -n 's/^cd "\(.*\)"$/\1/p')

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

# The wrapper evals the script's "cd" line and handles EDITOR_CMD. These
# tests source functions.zsh in bash (it is bash-compatible, like the gw
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

@test "tmp wrapper: passes info output through, consumes the cd line" {
    setup_wrapper

    output=$(tmp)

    [[ "$output" == *"Created temporary workspace"* ]]
    [[ "$output" != *'cd "'* ]]
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
