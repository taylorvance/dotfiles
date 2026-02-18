#!/usr/bin/env bats

# Unit tests for the `git-prune-branches` script

setup() {
    export TEST_DIR=$(mktemp -d)
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"

    # Copy the script
    cp "$BATS_TEST_DIRNAME/../../src/dotfiles/.local/bin/git-prune-branches" "$TEST_DIR/git-prune-branches"
    chmod +x "$TEST_DIR/git-prune-branches"

    # Create a "remote" bare repo and a working clone
    export REMOTE_REPO="$TEST_DIR/remote.git"
    export WORK_REPO="$TEST_DIR/work"

    git init --bare "$REMOTE_REPO" >/dev/null 2>&1
    git clone "$REMOTE_REPO" "$WORK_REPO" >/dev/null 2>&1

    cd "$WORK_REPO"
    git config user.email "test@test.com"
    git config user.name "Test"

    # Create initial commit on default branch
    echo "init" > file.txt
    git add file.txt
    git commit -m "initial" >/dev/null 2>&1
    git push -u origin HEAD >/dev/null 2>&1

    export DEFAULT_BRANCH=$(git branch --show-current)
}

teardown() {
    rm -rf "$TEST_DIR"
}

run_prune() {
    cd "$WORK_REPO"
    run "$TEST_DIR/git-prune-branches" "$@"
}

# Helper: create a branch, add a commit, push it, then merge into default
create_merged_branch() {
    local name="$1"
    local safename="${name//\//-}"
    cd "$WORK_REPO"
    git checkout -b "$name" >/dev/null 2>&1
    echo "$name" > "${safename}.txt"
    git add "${safename}.txt"
    git commit -m "work on $name" >/dev/null 2>&1
    git push -u origin "$name" >/dev/null 2>&1
    git checkout "$DEFAULT_BRANCH" >/dev/null 2>&1
    git merge "$name" --no-edit >/dev/null 2>&1
    git push >/dev/null 2>&1
}

# Helper: create a branch, push, merge, then delete remote (simulates PR merge + delete)
create_merged_gone_branch() {
    local name="$1"
    create_merged_branch "$name"
    git push origin --delete "$name" >/dev/null 2>&1
    git fetch --prune >/dev/null 2>&1
}

# Helper: create a branch, push, then delete remote without merging
create_gone_branch() {
    local name="$1"
    local safename="${name//\//-}"
    cd "$WORK_REPO"
    git checkout -b "$name" >/dev/null 2>&1
    echo "$name" > "${safename}.txt"
    git add "${safename}.txt"
    git commit -m "work on $name" >/dev/null 2>&1
    git push -u origin "$name" >/dev/null 2>&1
    git checkout "$DEFAULT_BRANCH" >/dev/null 2>&1
    git push origin --delete "$name" >/dev/null 2>&1
    git fetch --prune >/dev/null 2>&1
}

# Helper: create a branch, squash-merge it into default
create_squash_merged_branch() {
    local name="$1"
    local safename="${name//\//-}"
    cd "$WORK_REPO"
    git checkout -b "$name" >/dev/null 2>&1
    echo "$name" > "${safename}.txt"
    git add "${safename}.txt"
    git commit -m "work on $name" >/dev/null 2>&1
    git checkout "$DEFAULT_BRANCH" >/dev/null 2>&1
    git merge --squash "$name" >/dev/null 2>&1
    git commit -m "squashed: $name" >/dev/null 2>&1
}

# ============================================================================
# HELP AND BASIC OPTIONS
# ============================================================================

@test "git-prune-branches -h: shows help" {
    run_prune -h

    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"merged"* ]]
    [[ "$output" == *"gone"* ]]
    [[ "$output" == *"squash-merged"* ]]
}

@test "git-prune-branches: unknown option fails" {
    run_prune -z

    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

@test "git-prune-branches: fails outside git repo" {
    cd "$TEST_DIR"
    run "$TEST_DIR/git-prune-branches"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Not a git repository"* ]]
}

# ============================================================================
# NO BRANCHES TO PRUNE
# ============================================================================

@test "git-prune-branches: no branches to prune" {
    run_prune -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"No branches to prune"* ]]
}

# ============================================================================
# MERGED BRANCH DETECTION
# ============================================================================

@test "git-prune-branches: detects merged branch" {
    create_merged_branch "feature-merged"

    run_prune -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"feature-merged"* ]]
    [[ "$output" == *"merged"* ]]
}

@test "git-prune-branches: does not list default branch" {
    create_merged_branch "feature-test"

    run_prune -n

    [ "$status" -eq 0 ]
    # Default branch should not appear as a prunable branch
    [[ "$output" == *"feature-test"* ]]
    [[ "$output" == *"1 branch"* ]]
}

# ============================================================================
# GONE BRANCH DETECTION
# ============================================================================

@test "git-prune-branches: detects gone branch" {
    create_gone_branch "feature-remote-deleted"

    run_prune -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"feature-remote-deleted"* ]]
    [[ "$output" == *"gone"* ]]
}

@test "git-prune-branches: detects merged+gone branch" {
    create_merged_gone_branch "feature-pr-completed"

    run_prune -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"feature-pr-completed"* ]]
    [[ "$output" == *"merged"* ]]
    [[ "$output" == *"gone"* ]]
}

# ============================================================================
# SQUASH-MERGED DETECTION
# ============================================================================

@test "git-prune-branches: detects squash-merged branch with -a" {
    create_squash_merged_branch "feature-squashed"

    run_prune -n -a

    [ "$status" -eq 0 ]
    [[ "$output" == *"feature-squashed"* ]]
    [[ "$output" == *"squash-merged"* ]]
}

@test "git-prune-branches: skips squash-merged without -a flag" {
    create_squash_merged_branch "feature-squashed-hidden"

    run_prune -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"No branches to prune"* ]]
}

# ============================================================================
# MULTIPLE BRANCHES
# ============================================================================

@test "git-prune-branches: handles mix of branch states" {
    create_merged_branch "br-merged-only"
    create_merged_gone_branch "br-merged-and-gone"
    create_gone_branch "br-gone-only"

    run_prune -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"br-merged-only"* ]]
    [[ "$output" == *"br-merged-and-gone"* ]]
    [[ "$output" == *"br-gone-only"* ]]
    [[ "$output" == *"3 branch"* ]]
}

# ============================================================================
# DELETION
# ============================================================================

@test "git-prune-branches: deletes merged branch with y confirmation" {
    create_merged_branch "feature-to-delete"

    cd "$WORK_REPO"
    run bash -c 'echo y | "$1" 2>&1' _ "$TEST_DIR/git-prune-branches"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Deleted feature-to-delete"* ]]

    # Verify branch is actually gone
    cd "$WORK_REPO"
    run git branch --list "feature-to-delete"
    [[ -z "$output" ]]
}

@test "git-prune-branches: aborts on N confirmation" {
    create_merged_branch "feature-keep-me"

    cd "$WORK_REPO"
    run bash -c 'echo n | "$1" 2>&1' _ "$TEST_DIR/git-prune-branches"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Aborted"* ]]

    # Verify branch still exists
    cd "$WORK_REPO"
    run git branch --list "feature-keep-me"
    [[ "$output" == *"feature-keep-me"* ]]
}

@test "git-prune-branches: aborts on empty confirmation (default N)" {
    create_merged_branch "feature-keep-default"

    cd "$WORK_REPO"
    run bash -c 'echo "" | "$1" 2>&1' _ "$TEST_DIR/git-prune-branches"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Aborted"* ]]

    # Verify branch still exists
    cd "$WORK_REPO"
    run git branch --list "feature-keep-default"
    [[ "$output" == *"feature-keep-default"* ]]
}

@test "git-prune-branches: deletes gone branch with force flag" {
    create_gone_branch "feature-gone-delete"

    cd "$WORK_REPO"
    run bash -c 'echo y | "$1" 2>&1' _ "$TEST_DIR/git-prune-branches"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Deleted feature-gone-delete"* ]]

    # Verify branch is gone
    cd "$WORK_REPO"
    run git branch --list "feature-gone-delete"
    [[ -z "$output" ]]
}

# ============================================================================
# DRY RUN
# ============================================================================

@test "git-prune-branches -n: does not delete anything" {
    create_merged_branch "feature-dry-run"

    run_prune -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"feature-dry-run"* ]]

    # Verify branch still exists
    cd "$WORK_REPO"
    run git branch --list "feature-dry-run"
    [[ "$output" == *"feature-dry-run"* ]]
}

# ============================================================================
# DEFAULT BRANCH DETECTION
# ============================================================================

@test "git-prune-branches: detects default branch" {
    run_prune -n

    # Should not error - default branch detection worked
    [ "$status" -eq 0 ]
}
