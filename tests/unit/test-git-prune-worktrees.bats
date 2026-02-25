#!/usr/bin/env bats

# Unit tests for git-prune-worktrees

setup() {
    export TEST_DIR=$(mktemp -d)
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"

    # Put the script on PATH
    export PATH="$BATS_TEST_DIRNAME/../../src/dotfiles/.local/bin:$PATH"

    # Create a bare repo as the "remote"
    export REMOTE_DIR="$TEST_DIR/remote.git"
    git init --bare "$REMOTE_DIR" >/dev/null 2>&1

    # Clone it
    export REPO_DIR="$TEST_DIR/repo"
    git clone "$REMOTE_DIR" "$REPO_DIR" >/dev/null 2>&1
    cd "$REPO_DIR"
    git config user.email "test@test.com"
    git config user.name "Test"

    # Create initial commit and push
    echo "init" > file.txt
    git add file.txt
    git commit -m "initial" >/dev/null 2>&1
    git push -u origin HEAD >/dev/null 2>&1
}

teardown() {
    rm -rf "$TEST_DIR"
}

# Helper: create a worktree with branch pushed and synced with upstream
create_synced_worktree() {
    local name="$1"
    local wt_path="$TEST_DIR/wt-$name"
    cd "$REPO_DIR"
    git worktree add "$wt_path" -b "$name" >/dev/null 2>&1
    cd "$wt_path"
    git push -u origin HEAD >/dev/null 2>&1
    cd "$REPO_DIR"
    echo "$wt_path"
}

# Helper: create a worktree with uncommitted changes
create_dirty_worktree() {
    local name="$1"
    local wt_path
    wt_path=$(create_synced_worktree "$name")
    echo "dirty" > "$wt_path/dirty-file.txt"
    echo "$wt_path"
}

# Helper: create a worktree with unpushed commits
create_ahead_worktree() {
    local name="$1"
    local wt_path
    wt_path=$(create_synced_worktree "$name")
    cd "$wt_path"
    echo "extra" > extra.txt
    git add extra.txt
    git commit -m "ahead commit" >/dev/null 2>&1
    cd "$REPO_DIR"
    echo "$wt_path"
}

# Helper: create a worktree that is behind upstream
create_behind_worktree() {
    local name="$1"
    local wt_path
    wt_path=$(create_synced_worktree "$name")
    # Push a new commit then reset the local branch back
    cd "$wt_path"
    echo "extra" > extra.txt
    git add extra.txt
    git commit -m "will reset" >/dev/null 2>&1
    git push >/dev/null 2>&1
    git reset --hard HEAD~1 >/dev/null 2>&1
    cd "$REPO_DIR"
    echo "$wt_path"
}

# Helper: create a worktree with no upstream tracking branch
create_unpublished_worktree() {
    local name="$1"
    local wt_path="$TEST_DIR/wt-$name"
    cd "$REPO_DIR"
    git worktree add "$wt_path" -b "$name" >/dev/null 2>&1
    echo "$wt_path"
}

# ============================================================================
# HELP
# ============================================================================

@test "help flag shows usage" {
    run git-prune-worktrees --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"synced"* ]]
}

@test "short help flag works" {
    run git-prune-worktrees -h

    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

# ============================================================================
# NO WORKTREES
# ============================================================================

@test "no worktrees to prune shows message" {
    cd "$REPO_DIR"

    run git-prune-worktrees

    [ "$status" -eq 0 ]
    [[ "$output" == *"No worktrees to prune"* ]]
}

# ============================================================================
# STATE DETECTION
# ============================================================================

@test "detects synced worktree as safe" {
    create_synced_worktree "synced-feat" >/dev/null
    cd "$REPO_DIR"

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"[synced]"* ]]
    [[ "$output" == *"synced-feat"* ]]
    [[ "$output" == *"1 safe"* ]]
}

@test "detects dirty worktree (untracked file)" {
    create_dirty_worktree "dirty-feat" >/dev/null
    cd "$REPO_DIR"

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"[dirty]"* ]]
    [[ "$output" == *"dirty-feat"* ]]
    [[ "$output" == *"0 safe"* ]]
}

@test "detects dirty worktree (modified tracked file)" {
    local wt_path
    wt_path=$(create_synced_worktree "dirty-mod")
    # Modify an existing tracked file instead of creating untracked
    echo "changed" >> "$wt_path/file.txt"
    cd "$REPO_DIR"

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"[dirty]"* ]]
    [[ "$output" == *"dirty-mod"* ]]
    [[ "$output" == *"0 safe"* ]]
}

@test "detects ahead worktree" {
    create_ahead_worktree "ahead-feat" >/dev/null
    cd "$REPO_DIR"

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"[ahead]"* ]]
    [[ "$output" == *"ahead-feat"* ]]
    [[ "$output" == *"0 safe"* ]]
}

@test "detects behind worktree" {
    create_behind_worktree "behind-feat" >/dev/null
    cd "$REPO_DIR"

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"[behind]"* ]]
    [[ "$output" == *"behind-feat"* ]]
    [[ "$output" == *"0 safe"* ]]
}

@test "detects unpublished worktree" {
    create_unpublished_worktree "unpub-feat" >/dev/null
    cd "$REPO_DIR"

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"[unpublished]"* ]]
    [[ "$output" == *"unpub-feat"* ]]
    [[ "$output" == *"0 safe"* ]]
}

# ============================================================================
# DRY RUN
# ============================================================================

@test "dry run shows worktrees but does not prompt" {
    create_synced_worktree "dry-feat" >/dev/null
    cd "$REPO_DIR"

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"dry-feat"* ]]
    # Should not contain the removal prompt
    [[ "$output" != *"Remove all"* ]]
}

# ============================================================================
# MAIN WORKTREE
# ============================================================================

@test "skips main worktree" {
    create_synced_worktree "some-feat" >/dev/null
    cd "$REPO_DIR"

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    # Only the secondary worktree should be listed
    [[ "$output" == *"some-feat"* ]]
    [[ "$output" == *"1 safe"* ]]
}

# ============================================================================
# REMOVAL
# ============================================================================

@test "mixed states: correctly categorizes multiple worktrees" {
    create_synced_worktree "safe-one" >/dev/null
    create_dirty_worktree "dirty-one" >/dev/null
    create_ahead_worktree "ahead-one" >/dev/null
    create_unpublished_worktree "unpub-one" >/dev/null
    cd "$REPO_DIR"

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"[synced]"* ]]
    [[ "$output" == *"safe-one"* ]]
    [[ "$output" == *"[dirty]"* ]]
    [[ "$output" == *"dirty-one"* ]]
    [[ "$output" == *"[ahead]"* ]]
    [[ "$output" == *"ahead-one"* ]]
    [[ "$output" == *"[unpublished]"* ]]
    [[ "$output" == *"unpub-one"* ]]
    [[ "$output" == *"1 safe, 3 skipped"* ]]
}

@test "abort preserves all worktrees" {
    create_synced_worktree "keep-feat" >/dev/null
    cd "$REPO_DIR"

    printf 'n\n' | git-prune-worktrees

    # Worktree should still exist
    [ -d "$TEST_DIR/wt-keep-feat" ]
}

@test "removal of multiple safe worktrees" {
    create_synced_worktree "rm-one" >/dev/null
    create_synced_worktree "rm-two" >/dev/null
    cd "$REPO_DIR"

    printf 'y\n' | git-prune-worktrees

    [ ! -d "$TEST_DIR/wt-rm-one" ]
    [ ! -d "$TEST_DIR/wt-rm-two" ]

    # Both branches should still exist
    run git branch --list "rm-one"
    [[ "$output" == *"rm-one"* ]]
    run git branch --list "rm-two"
    [[ "$output" == *"rm-two"* ]]
}

@test "removal removes worktree but preserves branch" {
    create_synced_worktree "remove-feat" >/dev/null
    cd "$REPO_DIR"

    printf 'y\n' | git-prune-worktrees

    # Worktree directory should be gone
    [ ! -d "$TEST_DIR/wt-remove-feat" ]

    # Branch should still exist
    run git branch --list "remove-feat"
    [[ "$output" == *"remove-feat"* ]]
}

# ============================================================================
# ERROR HANDLING
# ============================================================================

@test "errors outside git repo" {
    cd "$TEST_DIR"

    run git-prune-worktrees

    [ "$status" -ne 0 ]
    [[ "$output" == *"Not a git repository"* ]]
}

@test "unknown option shows error" {
    cd "$REPO_DIR"

    run git-prune-worktrees --invalid

    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown option"* ]]
}
