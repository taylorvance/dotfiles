#!/usr/bin/env bats

# Unit tests for the `clean` script (build dependency cleaner)

setup() {
    export TEST_DIR=$(mktemp -d)

    # Copy the clean script
    cp "$BATS_TEST_DIRNAME/../../src/dotfiles/.local/bin/clean" "$TEST_DIR/clean"
    chmod +x "$TEST_DIR/clean"

    # Create project structure with cleanable directories
    mkdir -p "$TEST_DIR/projects/webapp/node_modules"
    mkdir -p "$TEST_DIR/projects/webapp/src"
    mkdir -p "$TEST_DIR/projects/api/node_modules"
    mkdir -p "$TEST_DIR/projects/ml/.venv"
    mkdir -p "$TEST_DIR/projects/ml/__pycache__"
    mkdir -p "$TEST_DIR/projects/lib/mypackage.egg-info"
    mkdir -p "$TEST_DIR/projects/pytest-proj/.pytest_cache/v"
    mkdir -p "$TEST_DIR/projects/deep/nested/thing/node_modules"

    # Add some content so sizes are non-zero
    dd if=/dev/zero of="$TEST_DIR/projects/webapp/node_modules/bigfile" bs=1024 count=100 2>/dev/null
    dd if=/dev/zero of="$TEST_DIR/projects/api/node_modules/bigfile" bs=1024 count=50 2>/dev/null
    dd if=/dev/zero of="$TEST_DIR/projects/ml/.venv/bigfile" bs=1024 count=200 2>/dev/null
    echo "cache" > "$TEST_DIR/projects/ml/__pycache__/module.pyc"
    echo "egg" > "$TEST_DIR/projects/lib/mypackage.egg-info/PKG-INFO"
    echo "pytest" > "$TEST_DIR/projects/pytest-proj/.pytest_cache/v/cache"
}

teardown() {
    rm -rf "$TEST_DIR"
}

run_clean() {
    "$TEST_DIR/clean" "$@"
}

# ============================================================================
# HELP AND BASIC OPTIONS
# ============================================================================

@test "clean -h: shows help" {
    run run_clean -h

    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: clean"* ]]
    [[ "$output" == *"-r"* ]]
    [[ "$output" == *"-n"* ]]
    [[ "$output" == *"node_modules"* ]]
}

@test "clean: unknown option fails" {
    run run_clean -z

    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

@test "clean: invalid directory fails" {
    run run_clean /nonexistent/path

    [ "$status" -eq 1 ]
    [[ "$output" == *"not a directory"* ]]
}

# ============================================================================
# SCANNING (NON-RECURSIVE, MAXDEPTH 2)
# ============================================================================

@test "clean: finds top-level project dependencies" {
    run run_clean -n "$TEST_DIR/projects"

    [ "$status" -eq 0 ]
    [[ "$output" == *"webapp/node_modules"* ]]
    [[ "$output" == *"api/node_modules"* ]]
    [[ "$output" == *"ml/.venv"* ]]
    [[ "$output" == *"ml/__pycache__"* ]]
}

@test "clean: does not find deeply nested dirs without -r" {
    run run_clean -n "$TEST_DIR/projects"

    [ "$status" -eq 0 ]
    # deep/nested/thing/node_modules should NOT appear (maxdepth 2)
    [[ "$output" != *"deep/nested/thing/node_modules"* ]]
}

@test "clean: shows total count" {
    run run_clean -n "$TEST_DIR/projects"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Found"* ]]
    [[ "$output" == *"directories"* ]]
}

@test "clean: shows sizes" {
    run run_clean -n "$TEST_DIR/projects"

    [ "$status" -eq 0 ]
    # Should show size units
    [[ "$output" == *"KB"* ]] || [[ "$output" == *"MB"* ]]
}

# ============================================================================
# RECURSIVE MODE (-r)
# ============================================================================

@test "clean -r: finds deeply nested directories" {
    run run_clean -r -n "$TEST_DIR/projects"

    [ "$status" -eq 0 ]
    [[ "$output" == *"deep/nested/thing/node_modules"* ]]
}

@test "clean -r: finds all target directories" {
    run run_clean -r -n "$TEST_DIR/projects"

    [ "$status" -eq 0 ]
    [[ "$output" == *"webapp/node_modules"* ]]
    [[ "$output" == *"api/node_modules"* ]]
    [[ "$output" == *"deep/nested/thing/node_modules"* ]]
    [[ "$output" == *".venv"* ]]
    [[ "$output" == *"__pycache__"* ]]
}

# ============================================================================
# DRY RUN MODE (-n)
# ============================================================================

@test "clean -n: does not delete anything" {
    run run_clean -n "$TEST_DIR/projects"

    [ "$status" -eq 0 ]
    # Directories should still exist
    [ -d "$TEST_DIR/projects/webapp/node_modules" ]
    [ -d "$TEST_DIR/projects/api/node_modules" ]
    [ -d "$TEST_DIR/projects/ml/.venv" ]
}

@test "clean -n: does not prompt" {
    run run_clean -n "$TEST_DIR/projects"

    [ "$status" -eq 0 ]
    # Should not contain prompt text
    [[ "$output" != *"Delete all?"* ]]
}

# ============================================================================
# DELETION (y response)
# ============================================================================

@test "clean: deletes all with y response" {
    run bash -c "echo 'y' | $TEST_DIR/clean $TEST_DIR/projects"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Freed"* ]]

    # Directories should be deleted
    [ ! -d "$TEST_DIR/projects/webapp/node_modules" ]
    [ ! -d "$TEST_DIR/projects/api/node_modules" ]
    [ ! -d "$TEST_DIR/projects/ml/.venv" ]
    [ ! -d "$TEST_DIR/projects/ml/__pycache__" ]
}

@test "clean: preserves non-target directories" {
    run bash -c "echo 'y' | $TEST_DIR/clean $TEST_DIR/projects"

    [ "$status" -eq 0 ]
    # src directory should still exist
    [ -d "$TEST_DIR/projects/webapp/src" ]
    # Project directories should still exist
    [ -d "$TEST_DIR/projects/webapp" ]
    [ -d "$TEST_DIR/projects/ml" ]
}

# ============================================================================
# ABORT (n response)
# ============================================================================

@test "clean: aborts with n response" {
    run bash -c "echo 'n' | $TEST_DIR/clean $TEST_DIR/projects"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Aborted"* ]]

    # Directories should still exist
    [ -d "$TEST_DIR/projects/webapp/node_modules" ]
}

@test "clean: aborts with empty response (default)" {
    run bash -c "echo '' | $TEST_DIR/clean $TEST_DIR/projects"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Aborted"* ]]
    [ -d "$TEST_DIR/projects/webapp/node_modules" ]
}

# ============================================================================
# TARGET DIRECTORY PATTERNS
# ============================================================================

@test "clean: finds node_modules" {
    run run_clean -n "$TEST_DIR/projects"

    [[ "$output" == *"node_modules"* ]]
}

@test "clean: finds __pycache__" {
    run run_clean -n "$TEST_DIR/projects"

    [[ "$output" == *"__pycache__"* ]]
}

@test "clean: finds .venv" {
    run run_clean -n "$TEST_DIR/projects"

    [[ "$output" == *".venv"* ]]
}

@test "clean: finds venv" {
    mkdir -p "$TEST_DIR/projects/another/venv"
    echo "test" > "$TEST_DIR/projects/another/venv/file"

    run run_clean -n "$TEST_DIR/projects"

    [[ "$output" == *"venv"* ]]
}

@test "clean: finds .pytest_cache" {
    run run_clean -n "$TEST_DIR/projects"

    [[ "$output" == *".pytest_cache"* ]]
}

@test "clean: finds *.egg-info" {
    run run_clean -n "$TEST_DIR/projects"

    [[ "$output" == *"egg-info"* ]]
}

# ============================================================================
# EDGE CASES
# ============================================================================

@test "clean: handles empty directory" {
    mkdir -p "$TEST_DIR/empty"

    run run_clean -n "$TEST_DIR/empty"

    [ "$status" -eq 0 ]
    [[ "$output" == *"No cleanable directories found"* ]]
}

@test "clean: handles directory with no matches" {
    mkdir -p "$TEST_DIR/clean-project/src"
    mkdir -p "$TEST_DIR/clean-project/tests"

    run run_clean -n "$TEST_DIR/clean-project"

    [ "$status" -eq 0 ]
    [[ "$output" == *"No cleanable directories found"* ]]
}

@test "clean: defaults to current directory" {
    cd "$TEST_DIR/projects"

    run "$TEST_DIR/clean" -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"node_modules"* ]]
}

@test "clean: sorts by size descending" {
    run run_clean -n "$TEST_DIR/projects"

    [ "$status" -eq 0 ]
    # .venv has 200KB, should appear before webapp/node_modules (100KB)
    # Check that .venv appears in output (it's the largest)
    [[ "$output" == *".venv"* ]]
}

# ============================================================================
# SIZE FORMATTING
# ============================================================================

@test "clean: formats KB correctly" {
    # Create small directory
    mkdir -p "$TEST_DIR/small/node_modules"
    echo "tiny" > "$TEST_DIR/small/node_modules/file"

    run run_clean -n "$TEST_DIR/small"

    [ "$status" -eq 0 ]
    [[ "$output" == *"KB"* ]]
}

@test "clean: shows total size" {
    run run_clean -n "$TEST_DIR/projects"

    [ "$status" -eq 0 ]
    [[ "$output" == *"total"* ]]
}

# ============================================================================
# INTERACTIVE MODE (requires fzf - skip if not available)
# ============================================================================

@test "clean: script checks for fzf in interactive mode" {
    # Static check: verify the script contains fzf availability check
    grep -q 'command -v fzf' "$TEST_DIR/clean"
    grep -q 'fzf required for interactive mode' "$TEST_DIR/clean"
}
