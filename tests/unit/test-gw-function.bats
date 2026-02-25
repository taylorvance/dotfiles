#!/usr/bin/env bats

# Unit tests for the `gw` shell function (git worktree cd)

setup() {
    export TEST_DIR=$(mktemp -d)
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"

    # Create a git repo with worktrees
    export REPO_DIR="$TEST_DIR/repo"
    git init "$REPO_DIR" >/dev/null 2>&1
    cd "$REPO_DIR"
    git config user.email "test@test.com"
    git config user.name "Test"
    git commit --allow-empty -m "initial" >/dev/null 2>&1

    # Create a branch and worktree
    export WT_DIR="$TEST_DIR/worktree-feature"
    git worktree add "$WT_DIR" -b feature >/dev/null 2>&1

    # Source the functions file
    FUNCTIONS_FILE="$BATS_TEST_DIRNAME/../../src/dotfiles/.zsh/functions.zsh"
    # Source only gw (avoid functions that need zsh-specific features)
    eval "$(sed -n '/^gw()/,/^}/p' "$FUNCTIONS_FILE")"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ============================================================================
# NO-ARGS: GO TO MAIN WORKTREE
# ============================================================================

@test "gw: no args goes to main worktree" {
    cd "$WT_DIR"

    gw
    [ "$PWD" = "$REPO_DIR" ]
}

@test "gw: no args works from main worktree (stays put)" {
    cd "$REPO_DIR"

    gw
    [ "$PWD" = "$REPO_DIR" ]
}

# ============================================================================
# QUERY: JUMP TO MATCHING WORKTREE
# ============================================================================

@test "gw <query>: jumps to matching worktree" {
    cd "$REPO_DIR"

    gw feature
    [ "$PWD" = "$WT_DIR" ]
}

@test "gw <query>: partial match works" {
    cd "$REPO_DIR"

    gw feat
    [ "$PWD" = "$WT_DIR" ]
}

@test "gw <query>: no match prints error and list" {
    cd "$REPO_DIR"

    run gw nonexistent

    [ "$status" -eq 1 ]
    [[ "$output" == *"No worktree matching 'nonexistent'"* ]]
    # Should also show the worktree list
    [[ "$output" == *"$REPO_DIR"* ]]
}

@test "gw <query>: can jump back to main from worktree by path match" {
    cd "$WT_DIR"

    gw repo
    [ "$PWD" = "$REPO_DIR" ]
}

# ============================================================================
# MULTIPLE WORKTREES
# ============================================================================

@test "gw: handles multiple worktrees" {
    cd "$REPO_DIR"

    # Add a second worktree
    local wt2="$TEST_DIR/worktree-bugfix"
    git worktree add "$wt2" -b bugfix >/dev/null 2>&1

    gw bugfix
    [ "$PWD" = "$wt2" ]
}

@test "gw: ambiguous query jumps to one of the matches" {
    cd "$REPO_DIR"

    local wt2="$TEST_DIR/worktree-feat2"
    git worktree add "$wt2" -b feat2 >/dev/null 2>&1

    # "worktree-feat" matches both; should jump to one of them
    gw worktree-feat
    [[ "$PWD" = "$WT_DIR" || "$PWD" = "$wt2" ]]
}

# ============================================================================
# LIST MODE
# ============================================================================

@test "gw -l: lists worktrees when fzf not available" {
    cd "$REPO_DIR"

    # Hide fzf
    local real_path="$PATH"
    export PATH="/usr/bin:/bin"
    # Also unset any fzf function/alias
    unset -f fzf 2>/dev/null || true

    run gw -l

    export PATH="$real_path"

    [ "$status" -eq 0 ]
    [[ "$output" == *"$REPO_DIR"* ]]
    [[ "$output" == *"$WT_DIR"* ]]
}

# ============================================================================
# ERROR HANDLING
# ============================================================================

@test "gw: errors outside git repo" {
    cd "$TEST_DIR"

    run gw

    [ "$status" -ne 0 ]
    [[ "$output" == *"Not in a git repository"* ]]
}

@test "gw: works from inside worktree subdirectory" {
    mkdir -p "$WT_DIR/subdir/nested"
    cd "$WT_DIR/subdir/nested"

    gw
    [ "$PWD" = "$REPO_DIR" ]
}
