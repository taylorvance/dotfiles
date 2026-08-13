#!/usr/bin/env bats

# Unit tests for bump-plugins.sh
# Runs the real script against a mock git on an isolated PATH.

setup() {
    export TEST_DIR=$(mktemp -d)
    export TEST_SCRIPT="$TEST_DIR/bump-plugins.sh"
    cp "$BATS_TEST_DIRNAME/../../src/bump-plugins.sh" "$TEST_SCRIPT"

    export MOCK_BIN="$TEST_DIR/bin"
    mkdir -p "$MOCK_BIN"
    export PATH="$MOCK_BIN:$PATH"

    export MOCK_GIT_CALLS="$TEST_DIR/git_calls"
    touch "$MOCK_GIT_CALLS"

    # Mock git: logs every call; `submodule foreach` with a log command
    # emits incoming commits when MOCK_INCOMING=1
    cat > "$MOCK_BIN/git" <<'EOF'
#!/bin/bash
echo "$@" >> "$MOCK_GIT_CALLS"
case "$*" in
    *"submodule foreach"*"git log"*)
        if [ "${MOCK_INCOMING:-0}" = "1" ]; then
            printf '== mock-plugin\nabc123 fake upstream commit\n\n'
        fi
        ;;
esac
exit 0
EOF
    chmod +x "$MOCK_BIN/git"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "bump-plugins: N at fetch prompt - exits without fetching" {
    run bash -c 'echo "N" | '"$TEST_SCRIPT"

    [ "$status" -eq 0 ]
    ! grep -q "fetch" "$MOCK_GIT_CALLS"
}

@test "bump-plugins: EOF at fetch prompt - aborts safely" {
    run bash -c "$TEST_SCRIPT < /dev/null"

    [ "$status" -eq 0 ]
    ! grep -q "fetch" "$MOCK_GIT_CALLS"
}

@test "bump-plugins: fetch confirmed but nothing incoming - reports up to date" {
    run bash -c 'echo "y" | '"$TEST_SCRIPT"

    [ "$status" -eq 0 ]
    grep -q "fetch" "$MOCK_GIT_CALLS"
    [[ "$output" == *"up to date"* ]]
    ! grep -q "update --remote" "$MOCK_GIT_CALLS"
}

@test "bump-plugins: N at checkout prompt - shows commits but applies nothing" {
    export MOCK_INCOMING=1

    run bash -c 'printf "y\nN\n" | '"$TEST_SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"fake upstream commit"* ]]
    [[ "$output" == *"Aborted"* ]]
    ! grep -q "update --remote" "$MOCK_GIT_CALLS"
}

@test "bump-plugins: y at both prompts - checks out the update" {
    export MOCK_INCOMING=1

    run bash -c 'printf "y\ny\n" | '"$TEST_SCRIPT"

    [ "$status" -eq 0 ]
    grep -q "submodule update --remote" "$MOCK_GIT_CALLS"
    [[ "$output" == *"commit the submodule bump"* ]]
}
