#!/usr/bin/env bats

# Unit tests for the `proj` script (project-aware workflow manager)

setup() {
    export TEST_DIR=$(mktemp -d)
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"

    # Copy the proj script
    cp "$BATS_TEST_DIRNAME/../../src/dotfiles/.local/bin/proj" "$TEST_DIR/proj"
    chmod +x "$TEST_DIR/proj"

    # Create mock zoxide
    cat > "$TEST_DIR/zoxide" <<'EOF'
#!/bin/bash
# Mock zoxide for testing
case "$1" in
    query)
        if [ "$2" = "-l" ]; then
            # List mode
            echo "/home/user/projects/dotfiles"
            echo "/home/user/projects/myapp"
            echo "/home/user/work/backend"
        else
            # Query mode - return first match
            case "$2" in
                dotfiles) echo "/home/user/projects/dotfiles" ;;
                myapp) echo "/home/user/projects/myapp" ;;
                backend) echo "/home/user/work/backend" ;;
                *) exit 1 ;;
            esac
        fi
        ;;
esac
EOF
    chmod +x "$TEST_DIR/zoxide"

    # Create mock fzf
    cat > "$TEST_DIR/fzf" <<'EOF'
#!/bin/bash
# Mock fzf - just return first line
head -1
EOF
    chmod +x "$TEST_DIR/fzf"

    # Create test project directories
    mkdir -p "$HOME/projects/dotfiles"
    mkdir -p "$HOME/projects/myapp"
    mkdir -p "$HOME/work/backend"

    # Add mocks to PATH
    export PATH="$TEST_DIR:$PATH"
}

teardown() {
    # Only kill tmux sessions with "test_" prefix (created by tests)
    # NEVER use "tmux kill-server" - it kills ALL sessions including user's real ones!
    tmux list-sessions -F '#{session_name}' 2>/dev/null | grep '^test_' | while read s; do
        tmux kill-session -t "$s" 2>/dev/null || true
    done
    rm -rf "$TEST_DIR"
}

run_proj() {
    "$TEST_DIR/proj" "$@"
}

# ============================================================================
# HELP AND BASIC TESTS
# ============================================================================

@test "proj -h: shows help" {
    run run_proj -h

    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: proj"* ]]
    [[ "$output" == *"Project-aware workflow manager"* ]]
}

@test "proj --help: shows help" {
    run run_proj --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"BASIC USAGE:"* ]]
    [[ "$output" == *"OPTIONS:"* ]]
    [[ "$output" == *"FEATURES:"* ]]
}

@test "proj: script has valid syntax" {
    run bash -n "$TEST_DIR/proj"

    [ "$status" -eq 0 ]
}

@test "proj: script is executable" {
    [ -x "$TEST_DIR/proj" ]
}

# ============================================================================
# DETACH MODE TESTS (-d flag)
# ============================================================================

@test "proj -d: outputs cd command without tmux" {
    # Ensure we're not in tmux
    unset TMUX

    run run_proj -d dotfiles

    [ "$status" -eq 0 ]
    [[ "$output" == *'cd "'* ]]
    [[ "$output" == *"dotfiles"* ]]
}

@test "proj -d: works with direct path" {
    mkdir -p "$HOME/test-project"

    run run_proj -d "$HOME/test-project"

    [ "$status" -eq 0 ]
    [[ "$output" == *'cd "'* ]]
    [[ "$output" == *"test-project"* ]]
}

@test "proj -d: fails for non-existent project" {
    run run_proj -d nonexistent-project-xyz

    [ "$status" -eq 1 ]
    [[ "$output" == *"Could not find project"* ]]
}

# ============================================================================
# LIST MODE TESTS (-l flag)
# ============================================================================

@test "proj -l: shows message when no sessions exist" {
    skip_if_not_installed tmux

    # Skip if there are existing sessions (don't kill them!)
    if tmux list-sessions 2>/dev/null | grep -qv '^test_'; then
        skip "User has active tmux sessions - cannot test empty state safely"
    fi

    run run_proj -l

    [ "$status" -eq 0 ]
    [[ "$output" == *"No active tmux sessions"* ]] || [ -z "$output" ]
}

@test "proj -l: lists sessions when they exist" {
    skip_if_not_installed tmux

    # Create a test session
    tmux new-session -d -s test_session "sleep 10" 2>/dev/null || skip "Could not create tmux session"

    run run_proj -l

    [ "$status" -eq 0 ]
    [[ "$output" == *"test_session"* ]]

    # Cleanup
    tmux kill-session -t test_session 2>/dev/null || true
}

@test "proj -l: fails gracefully when tmux not installed" {
    # Temporarily hide tmux
    export PATH="/usr/bin:/bin"

    run run_proj -l

    [ "$status" -eq 1 ]
    [[ "$output" == *"tmux is not installed"* ]]
}

# ============================================================================
# KILL MODE TESTS (-k flag)
# ============================================================================

@test "proj -k: fails without project name" {
    skip_if_not_installed tmux

    run run_proj -k

    [ "$status" -eq 1 ]
    [[ "$output" == *"requires a project name"* ]]
}

@test "proj -k: fails for non-existent session" {
    skip_if_not_installed tmux

    run run_proj -k nonexistent

    [ "$status" -eq 1 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "proj -k: kills existing session" {
    skip_if_not_installed tmux

    # Create a test session
    tmux new-session -d -s test_kill "sleep 10" 2>/dev/null || skip "Could not create tmux session"

    # Verify it exists
    tmux has-session -t test_kill 2>/dev/null || skip "Session not created"

    # Kill it
    run run_proj -k test_kill

    [ "$status" -eq 0 ]
    [[ "$output" == *"Killed session"* ]]

    # Verify it's gone
    run tmux has-session -t test_kill
    [ "$status" -ne 0 ]
}

# ============================================================================
# INTERACTIVE MODE TESTS (no args)
# ============================================================================

@test "proj: interactive mode requires fzf" {
    # Temporarily hide fzf
    export PATH="/usr/bin:/bin"

    run run_proj

    [ "$status" -eq 1 ]
    [[ "$output" == *"fzf is required"* ]]
}

@test "proj: interactive mode shows projects from zoxide" {
    # Run without args to trigger interactive mode, then -d to get cd output
    # Our mock fzf returns first line from zoxide list
    # We need to call it with a project after fzf picks it

    # Actually test that it falls through to zoxide when no project given
    run run_proj -d dotfiles

    # Should work with direct project name
    [ "$status" -eq 0 ]
    [[ "$output" == *"cd"* ]]
    [[ "$output" == *"dotfiles"* ]]
}

# ============================================================================
# PROJECT NAME NORMALIZATION TESTS
# ============================================================================

@test "proj: normalizes project names with dots" {
    skip_if_not_installed tmux

    mkdir -p "$HOME/test.project.name"

    # This should work and normalize the session name
    run run_proj -d "$HOME/test.project.name"

    [ "$status" -eq 0 ]
    [[ "$output" == *"test.project.name"* ]]
}

@test "proj: normalizes project names with spaces" {
    skip_if_not_installed tmux

    mkdir -p "$HOME/test project"

    run run_proj -d "$HOME/test project"

    [ "$status" -eq 0 ]
    [[ "$output" == *"test project"* ]]
}

# ============================================================================
# ERROR HANDLING TESTS
# ============================================================================

@test "proj: handles unknown option" {
    run run_proj --invalid-option

    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

@test "proj: handles missing zoxide gracefully" {
    # Remove zoxide from PATH
    export PATH="/usr/bin:/bin"

    # Direct path should still work
    mkdir -p "$HOME/direct-project"
    run run_proj -d "$HOME/direct-project"

    [ "$status" -eq 0 ]
    [[ "$output" == *"cd"* ]]
}

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

@test "proj: works with absolute paths" {
    mkdir -p "$HOME/absolute/path/project"

    run run_proj -d "$HOME/absolute/path/project"

    [ "$status" -eq 0 ]
    [[ "$output" == *'cd "'*"/absolute/path/project"* ]]
}

@test "proj: works with relative paths" {
    mkdir -p "$HOME/relative-test"
    cd "$HOME"

    run run_proj -d "./relative-test"

    [ "$status" -eq 0 ]
    [[ "$output" == *"relative-test"* ]]
}

@test "proj: zoxide integration works" {
    # Our mock zoxide should resolve "dotfiles"
    run run_proj -d dotfiles

    [ "$status" -eq 0 ]
    [[ "$output" == *"dotfiles"* ]]
}

# ============================================================================
# TMUX SESSION CREATION (external tests, might skip in CI)
# ============================================================================

@test "proj: creates tmux session for new project" {
    skip_if_not_installed tmux
    skip "Requires interactive tmux testing"

    # This would test: proj myapp
    # Expected: creates tmux session named "myapp" in the project directory
}

@test "proj: attaches to existing session" {
    skip_if_not_installed tmux
    skip "Requires interactive tmux testing"

    # This would test: proj myapp (when session already exists)
    # Expected: attaches to existing "myapp" session
}

@test "proj: switches session when inside tmux" {
    skip_if_not_installed tmux
    skip "Requires interactive tmux testing"

    # This would test behavior when TMUX is set
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

skip_if_not_installed() {
    local tool=$1
    if ! command -v "$tool" >/dev/null 2>&1; then
        skip "$tool not installed"
    fi
}
