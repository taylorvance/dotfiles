#!/usr/bin/env bats

# Unit tests for git-prune-worktrees
# @covers src/dotfiles/.local/bin/git-prune-worktrees
# @covers tests/helpers/fzf.bash

load ../helpers/fzf

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
    git config user.email "me@test.com"
    git config user.name "Me"

    # Create initial commit and push
    echo "init" > file.txt
    git add file.txt
    git commit -m "initial" >/dev/null 2>&1
    git push -u origin HEAD >/dev/null 2>&1
}

teardown() {
    rm -rf "$TEST_DIR"
}

# Helper: worktree on a new branch at the pushed initial commit, no upstream
create_worktree() {
    local name="$1"
    local wt_path="$TEST_DIR/wt-$name"
    cd "$REPO_DIR"
    git worktree add "$wt_path" -b "$name" >/dev/null 2>&1
    echo "$wt_path"
}

# Helper: worktree with one new commit, committed as EMAIL (default: me)
create_committed_worktree() {
    local name="$1" email="${2:-me@test.com}"
    local wt_path
    wt_path=$(create_worktree "$name")
    cd "$wt_path"
    echo "$name" > "$name.txt"
    git add "$name.txt"
    git -c user.email="$email" commit -m "$name commit" >/dev/null 2>&1
    cd "$REPO_DIR"
    echo "$wt_path"
}

# ============================================================================
# HELP AND ERRORS
# ============================================================================

@test "help flag shows usage" {
    run git-prune-worktrees --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"of your commits on no remote"* ]]
}

@test "short help flag works" {
    run git-prune-worktrees -h

    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

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

@test "no worktrees to prune shows message" {
    cd "$REPO_DIR"

    run git-prune-worktrees

    [ "$status" -eq 0 ]
    [[ "$output" == *"No worktrees to prune"* ]]
}

# ============================================================================
# REMOVABLE: nothing of yours would be lost
# ============================================================================

@test "branch with no upstream and no new commits is removable" {
    create_worktree "no-upstream" >/dev/null
    cd "$REPO_DIR"

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"Removable:"* ]]
    [[ "$output" == *"no-upstream"* ]]
    [[ "$output" == *"1 removable, 0 kept"* ]]
}

@test "pushed branch is removable" {
    local wt_path
    wt_path=$(create_committed_worktree "pushed")
    cd "$wt_path"
    git push -u origin HEAD >/dev/null 2>&1
    cd "$REPO_DIR"

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"1 removable, 0 kept"* ]]
}

@test "branch behind its upstream is removable" {
    local wt_path
    wt_path=$(create_committed_worktree "behind")
    cd "$wt_path"
    git push -u origin HEAD >/dev/null 2>&1
    git reset --hard HEAD~1 >/dev/null 2>&1
    cd "$REPO_DIR"

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"1 removable, 0 kept"* ]]
}

@test "unpushed commits by someone else are removable" {
    create_committed_worktree "their-pr" "someone@else.com" >/dev/null
    cd "$REPO_DIR"

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"their-pr"* ]]
    [[ "$output" == *"1 removable, 0 kept"* ]]
}

@test "detached worktree is listed and removable" {
    cd "$REPO_DIR"
    git worktree add --detach "$TEST_DIR/wt-detached" HEAD >/dev/null 2>&1
    local short
    short=$(git rev-parse --short=7 HEAD)

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"$short (detached)"* ]]
    [[ "$output" == *"1 removable, 0 kept"* ]]
}

@test "gitignored files do not block removal" {
    local wt_path
    wt_path=$(create_worktree "with-ignored")
    echo ".env" >> "$REPO_DIR/.git/info/exclude"
    echo "secret" > "$wt_path/.env"
    cd "$REPO_DIR"

    run bash -c "echo y | git-prune-worktrees"

    [ "$status" -eq 0 ]
    [ ! -d "$wt_path" ]
}

# ============================================================================
# KEPT: something would be lost, or removal is refused
# ============================================================================

@test "untracked file keeps a worktree" {
    local wt_path
    wt_path=$(create_worktree "untracked")
    echo "new" > "$wt_path/new.txt"
    cd "$REPO_DIR"

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"[uncommitted changes]"* ]]
    [[ "$output" == *"0 removable, 1 kept"* ]]
}

@test "untracked file keeps a worktree even when status hides untracked files" {
    local wt_path
    wt_path=$(create_worktree "hidden-untracked")
    git config status.showUntrackedFiles no
    echo "new" > "$wt_path/new.txt"
    cd "$REPO_DIR"

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"[uncommitted changes]"* ]]
}

@test "modified tracked file keeps a worktree" {
    local wt_path
    wt_path=$(create_worktree "modified")
    echo "changed" >> "$wt_path/file.txt"
    cd "$REPO_DIR"

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"[uncommitted changes]"* ]]
}

@test "your unpushed commit keeps a worktree" {
    create_committed_worktree "mine" >/dev/null
    cd "$REPO_DIR"

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"[1 of your commits on no remote]"* ]]
    [[ "$output" == *"0 removable, 1 kept"* ]]
}

@test "your email matches case-insensitively" {
    create_committed_worktree "mine-upper" "ME@TEST.COM" >/dev/null
    cd "$REPO_DIR"

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"[1 of your commits on no remote]"* ]]
}

@test "without user.email every unpushed commit counts as yours" {
    create_committed_worktree "unknown-me" "someone@else.com" >/dev/null
    cd "$REPO_DIR"
    git config --unset user.email

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"[1 of your commits on no remote]"* ]]
}

@test "locked worktree is kept" {
    local wt_path
    wt_path=$(create_worktree "locked-one")
    cd "$REPO_DIR"
    git worktree lock "$wt_path"

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"[locked]"* ]]
}

@test "the worktree you run it from is kept" {
    local wt_path
    wt_path=$(create_worktree "here")
    cd "$wt_path"

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"[current worktree]"* ]]
    [[ "$output" == *"0 removable, 1 kept"* ]]
}

@test "mixed states: correctly categorizes multiple worktrees" {
    create_worktree "safe-one" >/dev/null
    create_committed_worktree "theirs-one" "someone@else.com" >/dev/null
    create_committed_worktree "mine-one" >/dev/null
    local dirty
    dirty=$(create_worktree "dirty-one")
    echo "x" > "$dirty/x.txt"
    cd "$REPO_DIR"

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"2 removable, 2 kept"* ]]
}

# ============================================================================
# MISSING DIRECTORIES
# ============================================================================

@test "dry run reports a missing worktree directory but leaves it registered" {
    local wt_path
    wt_path=$(create_worktree "gone")
    rm -rf "$wt_path"
    cd "$REPO_DIR"

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"1 worktree(s) with a missing directory"* ]]
    [[ "$(git worktree list)" == *"wt-gone"* ]]
}

@test "real run forgets a missing worktree directory" {
    local wt_path
    wt_path=$(create_worktree "gone")
    rm -rf "$wt_path"
    cd "$REPO_DIR"

    run git-prune-worktrees < /dev/null

    [ "$status" -eq 0 ]
    [[ "$output" == *"Forgot 1 worktree(s)"* ]]
    [[ "$output" == *"No worktrees to prune"* ]]
    [[ "$(git worktree list)" != *"wt-gone"* ]]
}

# ============================================================================
# PROMPT AND REMOVAL
# ============================================================================

@test "dry run does not prompt" {
    create_worktree "dry-feat" >/dev/null
    cd "$REPO_DIR"

    run git-prune-worktrees -n

    [ "$status" -eq 0 ]
    [[ "$output" == *"dry-feat"* ]]
    [[ "$output" != *"Remove all"* ]]
}

@test "abort preserves all worktrees" {
    create_worktree "keep-feat" >/dev/null
    cd "$REPO_DIR"

    printf 'n\n' | git-prune-worktrees

    [ -d "$TEST_DIR/wt-keep-feat" ]
}

@test "EOF at prompt aborts safely" {
    local wt_path
    wt_path=$(create_worktree "eof-test")
    cd "$REPO_DIR"

    run bash -c "git-prune-worktrees < /dev/null"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Aborted"* ]]
    [ -d "$wt_path" ]
}

@test "y removes removable worktrees and their branches, keeps the rest" {
    create_worktree "rm-one" >/dev/null
    create_committed_worktree "rm-theirs" "someone@else.com" >/dev/null
    create_committed_worktree "keep-mine" >/dev/null
    cd "$REPO_DIR"

    run bash -c "echo y | git-prune-worktrees"

    [ "$status" -eq 0 ]
    [ ! -d "$TEST_DIR/wt-rm-one" ]
    [ ! -d "$TEST_DIR/wt-rm-theirs" ]
    [ -z "$(git branch --list rm-one rm-theirs)" ]
    [ -d "$TEST_DIR/wt-keep-mine" ]
    [[ "$(git branch --list keep-mine)" == *"keep-mine"* ]]
}

@test "y removes a detached worktree" {
    cd "$REPO_DIR"
    git worktree add --detach "$TEST_DIR/wt-detached" HEAD >/dev/null 2>&1

    run bash -c "echo y | git-prune-worktrees"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Removed"*"(detached)"* ]]
    [[ "$output" != *"failed"* ]]
    [ ! -d "$TEST_DIR/wt-detached" ]
}

# ============================================================================
# INTERACTIVE SELECTION (i)
# ============================================================================

@test "git-prune-worktrees i: removes only the selected worktree" {
    create_worktree "pick-me" >/dev/null
    create_worktree "leave-me" >/dev/null
    stub_fzf_match "pick-me"

    cd "$REPO_DIR"
    run bash -c "echo i | git-prune-worktrees"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Removed pick-me"* ]]
    [ ! -d "$TEST_DIR/wt-pick-me" ]
    [ -d "$TEST_DIR/wt-leave-me" ]
    [ -z "$(git branch --list pick-me)" ]
}

@test "git-prune-worktrees i: never offers a kept worktree" {
    create_worktree "clean-one" >/dev/null
    local dirty
    dirty=$(create_worktree "has-uncommitted-work")
    echo "x" > "$dirty/x.txt"
    create_committed_worktree "has-my-commit" >/dev/null
    stub_fzf_none

    cd "$REPO_DIR"
    run bash -c "echo i | git-prune-worktrees"

    # This failed on the macOS runner while passing in the container and on a
    # local macOS repro; surface enough to tell why if it happens again
    if [ "$status" -ne 0 ]; then
        printf 'unexpected exit %s\noutput:\n%s\ncandidates:\n%s\n' \
            "$status" "$output" "$(fzf_candidates 2>/dev/null)" >&2
    fi
    [ "$status" -eq 0 ]
    offered=$(fzf_candidates)
    [[ "$offered" == *"clean-one"* ]]
    # Removal uses --force and branch -D, so a kept worktree on this menu
    # would destroy work with one keystroke
    [[ "$offered" != *"has-uncommitted-work"* ]]
    [[ "$offered" != *"has-my-commit"* ]]
    [ -d "$dirty" ]
}

@test "git-prune-worktrees i: ESC aborts without removing" {
    create_worktree "survives-esc" >/dev/null
    stub_fzf_abort

    cd "$REPO_DIR"
    run bash -c "echo i | git-prune-worktrees"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Aborted."* ]]
    [ -d "$TEST_DIR/wt-survives-esc" ]
}

@test "git-prune-worktrees i: selecting nothing removes nothing" {
    create_worktree "survives-empty" >/dev/null
    stub_fzf_none

    cd "$REPO_DIR"
    run bash -c "echo i | git-prune-worktrees"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Nothing selected."* ]]
    [ -d "$TEST_DIR/wt-survives-empty" ]
}

@test "git-prune-worktrees i: without fzf, reports it and removes nothing" {
    create_worktree "survives-no-fzf" >/dev/null
    no_fzf

    cd "$REPO_DIR"
    run env PATH="$NO_FZF_PATH" bash -c "echo i | git-prune-worktrees"

    [[ "$output" == *"fzf required for interactive mode"* ]]
    [ -d "$TEST_DIR/wt-survives-no-fzf" ]
}
