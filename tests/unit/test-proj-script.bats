#!/usr/bin/env bats

# Unit tests for the `proj` script (tmux session manager)

setup() {
    export TEST_DIR=$(mktemp -d)
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"

    # Copy the proj script
    cp "$BATS_TEST_DIRNAME/../../src/dotfiles/.local/bin/proj" "$TEST_DIR/proj"
    chmod +x "$TEST_DIR/proj"

    # Sessions state file for mock tmux
    export MOCK_TMUX_SESSIONS="$TEST_DIR/mock_sessions"
    export MOCK_TMUX_CALLS="$TEST_DIR/mock_tmux_calls"
    touch "$MOCK_TMUX_SESSIONS" "$MOCK_TMUX_CALLS"

    # Create mock tmux
    cat > "$TEST_DIR/tmux" <<'EOF'
#!/bin/bash
echo "tmux $*" >> "$MOCK_TMUX_CALLS"

subcommand="$1"; shift

case "$subcommand" in
    has-session)
        name=""
        for arg; do
            case "$arg" in -t=*) name="${arg#-t=}" ;; esac
        done
        grep -qxF "$name" "$MOCK_TMUX_SESSIONS"
        ;;
    new-session)
        name=""
        while [ $# -gt 0 ]; do
            case "$1" in
                -s) shift; name="$1" ;;
                -c|-t) shift ;;
            esac
            shift
        done
        [ -n "$name" ] && echo "$name" >> "$MOCK_TMUX_SESSIONS"
        ;;
    switch-client)
        exit 0
        ;;
    attach-session)
        exit 0
        ;;
    kill-session)
        name=""
        while [ $# -gt 0 ]; do
            case "$1" in -t) shift; name="$1" ;; esac
            shift
        done
        if [ -n "$name" ]; then
            grep -vxF "$name" "$MOCK_TMUX_SESSIONS" > "$MOCK_TMUX_SESSIONS.tmp"
            mv "$MOCK_TMUX_SESSIONS.tmp" "$MOCK_TMUX_SESSIONS"
        fi
        ;;
    list-sessions)
        [ -s "$MOCK_TMUX_SESSIONS" ] || exit 1
        cat "$MOCK_TMUX_SESSIONS"
        ;;
    display-message)
        echo "${MOCK_CURRENT_SESSION:-test_current}"
        ;;
    *)
        exit 1
        ;;
esac
EOF
    chmod +x "$TEST_DIR/tmux"

    # Create mock fzf (returns first line of input)
    cat > "$TEST_DIR/fzf" <<'EOF'
#!/bin/bash
head -1
EOF
    chmod +x "$TEST_DIR/fzf"

    export PATH="$TEST_DIR:$PATH"
}

teardown() {
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
}

@test "proj --help: shows help with all sections" {
    run run_proj --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"USAGE:"* ]]
    [[ "$output" == *"OPTIONS:"* ]]
    [[ "$output" == *"EXAMPLES:"* ]]
}

@test "proj: script has valid syntax" {
    run bash -n "$TEST_DIR/proj"

    [ "$status" -eq 0 ]
}

@test "proj: script is executable" {
    [ -x "$TEST_DIR/proj" ]
}

@test "proj: unknown option errors" {
    run run_proj --invalid-option

    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

@test "proj: errors when tmux not installed" {
    export PATH="/usr/bin:/bin"

    run run_proj someproject

    [ "$status" -eq 1 ]
    [[ "$output" == *"tmux is not installed"* ]]
}

# ============================================================================
# CREATE MODE TESTS (-c flag)
# ============================================================================

@test "proj -c NAME: creates session with given name" {
    unset TMUX

    run run_proj -c mysession

    [ "$status" -eq 0 ]
    grep -qxF "mysession" "$MOCK_TMUX_SESSIONS"
}

@test "proj -c: defaults session name to basename of PWD" {
    unset TMUX
    mkdir -p "$TEST_DIR/myproject"
    cd "$TEST_DIR/myproject"

    run run_proj -c

    [ "$status" -eq 0 ]
    grep -qxF "myproject" "$MOCK_TMUX_SESSIONS"
}

@test "proj -c: normalizes dots and spaces in name" {
    unset TMUX
    mkdir -p "$TEST_DIR/my.cool project"
    cd "$TEST_DIR/my.cool project"

    run run_proj -c

    [ "$status" -eq 0 ]
    # Name should have dots/spaces replaced
    grep -qE "my.cool.project|my_cool_project" "$MOCK_TMUX_SESSIONS"
}

@test "proj -c NAME: fails if session already exists" {
    unset TMUX
    echo "existing" >> "$MOCK_TMUX_SESSIONS"

    run run_proj -c existing

    [ "$status" -eq 1 ]
    [[ "$output" == *"already exists"* ]]
}

@test "proj -c: in tmux, creates detached and switches" {
    export TMUX=mock_socket

    run run_proj -c newsession

    [ "$status" -eq 0 ]
    grep -qxF "newsession" "$MOCK_TMUX_SESSIONS"
    grep -q "switch-client" "$MOCK_TMUX_CALLS"
}

@test "proj -c: outside tmux, creates and attaches" {
    unset TMUX

    run run_proj -c newsession

    [ "$status" -eq 0 ]
    grep -qxF "newsession" "$MOCK_TMUX_SESSIONS"
    # Should call attach (new-session without -d)
    grep -q "new-session" "$MOCK_TMUX_CALLS"
}

# ============================================================================
# KILL MODE TESTS (-k flag)
# ============================================================================

@test "proj -k NAME: kills named session" {
    echo "target_session" >> "$MOCK_TMUX_SESSIONS"

    run run_proj -k target_session

    [ "$status" -eq 0 ]
    [[ "$output" == *"Killed session: target_session"* ]]
    ! grep -qxF "target_session" "$MOCK_TMUX_SESSIONS"
}

@test "proj -k NAME: fails for non-existent session" {
    run run_proj -k nonexistent

    [ "$status" -eq 1 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "proj -k: in tmux, kills current session" {
    export TMUX=mock_socket
    export MOCK_CURRENT_SESSION=current_session
    echo "current_session" >> "$MOCK_TMUX_SESSIONS"

    run run_proj -k

    [ "$status" -eq 0 ]
    [[ "$output" == *"Killed session: current_session"* ]]
}

@test "proj -k: outside tmux with no arg, uses fzf to pick" {
    unset TMUX
    echo "session_a" >> "$MOCK_TMUX_SESSIONS"
    echo "session_b" >> "$MOCK_TMUX_SESSIONS"

    run run_proj -k

    [ "$status" -eq 0 ]
    # Mock fzf returns first line, so session_a should be killed
    [[ "$output" == *"Killed session: session_a"* ]]
}

@test "proj -k: outside tmux with no sessions, errors" {
    unset TMUX

    run run_proj -k

    [ "$status" -eq 1 ]
    [[ "$output" == *"No tmux sessions running"* ]]
}

@test "proj -k: outside tmux with no fzf and no arg, errors helpfully" {
    unset TMUX
    echo "session_a" >> "$MOCK_TMUX_SESSIONS"
    export PATH="$TEST_DIR:$(echo $PATH | tr ':' '\n' | grep -v fzf | tr '\n' ':')"
    # Remove fzf from the test dir
    rm -f "$TEST_DIR/fzf"

    run run_proj -k

    [ "$status" -eq 1 ]
    [[ "$output" == *"fzf"* ]] || [[ "$output" == *"session name"* ]]
}

# ============================================================================
# ATTACH MODE TESTS (no flag)
# ============================================================================

@test "proj NAME: attaches to exact matching session" {
    export TMUX=mock_socket
    echo "dotfiles" >> "$MOCK_TMUX_SESSIONS"

    run run_proj dotfiles

    [ "$status" -eq 0 ]
    grep -q "switch-client.*dotfiles" "$MOCK_TMUX_CALLS"
}

@test "proj NAME: attaches outside tmux" {
    unset TMUX
    echo "dotfiles" >> "$MOCK_TMUX_SESSIONS"

    run run_proj dotfiles

    [ "$status" -eq 0 ]
    grep -q "attach-session.*dotfiles" "$MOCK_TMUX_CALLS"
}

@test "proj NAME: exact match wins over substring matches" {
    export TMUX=mock_socket
    echo "dot" >> "$MOCK_TMUX_SESSIONS"
    echo "dotfiles" >> "$MOCK_TMUX_SESSIONS"
    echo "dotnetproj" >> "$MOCK_TMUX_SESSIONS"

    run run_proj dot

    [ "$status" -eq 0 ]
    # Should switch to exact match "dot", not fzf
    grep -q "switch-client.*dot$\|switch-client -t dot$" "$MOCK_TMUX_CALLS"
}

@test "proj NAME: multiple fuzzy matches uses fzf" {
    export TMUX=mock_socket
    echo "dotfiles" >> "$MOCK_TMUX_SESSIONS"
    echo "dotnetproj" >> "$MOCK_TMUX_SESSIONS"

    run run_proj dot

    [ "$status" -eq 0 ]
    # Mock fzf returns first line (dotfiles)
    grep -q "switch-client.*dotfiles" "$MOCK_TMUX_CALLS"
}

@test "proj NAME: no match prompts to create, y creates session" {
    unset TMUX

    run bash -c 'echo "y" | '"$TEST_DIR"'/proj brandnew'

    [ "$status" -eq 0 ]
    grep -qxF "brandnew" "$MOCK_TMUX_SESSIONS"
}

@test "proj NAME: no match prompts to create, N aborts" {
    unset TMUX

    run bash -c 'echo "N" | '"$TEST_DIR"'/proj brandnew'

    [ "$status" -eq 0 ]
    ! grep -qxF "brandnew" "$MOCK_TMUX_SESSIONS"
}

@test "proj NAME: prompt shows cwd" {
    unset TMUX

    run bash -c 'echo "N" | '"$TEST_DIR"'/proj brandnew'

    [[ "$output" == *"$PWD"* ]]
}

# ============================================================================
# INTERACTIVE MODE TESTS (no args)
# ============================================================================

@test "proj: no args, picks from sessions via fzf" {
    export TMUX=mock_socket
    echo "session_a" >> "$MOCK_TMUX_SESSIONS"
    echo "session_b" >> "$MOCK_TMUX_SESSIONS"

    run run_proj

    [ "$status" -eq 0 ]
    # Mock fzf returns first line (session_a)
    grep -q "switch-client.*session_a" "$MOCK_TMUX_CALLS"
}

@test "proj: no args, no sessions, errors" {
    run run_proj

    [ "$status" -eq 1 ]
    [[ "$output" == *"No tmux sessions running"* ]]
}

@test "proj: no args without fzf, errors" {
    echo "session_a" >> "$MOCK_TMUX_SESSIONS"
    rm -f "$TEST_DIR/fzf"

    run run_proj

    [ "$status" -eq 1 ]
    [[ "$output" == *"fzf"* ]]
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
