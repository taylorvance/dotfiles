#!/usr/bin/env bats

# Integration tests for the deployed git config and its aliases
# @covers src/dotfiles/.gitconfig
# @covers src/dotfiles/.config/git/*
# @covers src/symlink-manager.sh
# @covers tests/helpers/dotfiles-home.bash

bats_require_minimum_version 1.5.0

load ../helpers/dotfiles-home

setup_file() {
    install_dotfiles_home
}

setup() {
    skip_if_not_installed git
}

@test "git: .gitconfig is valid" {
    run git config --file "$TEST_HOME/.gitconfig" --list
    [ "$status" -eq 0 ]
}

@test "git: aliases are defined" {
    run git config --file "$TEST_HOME/.gitconfig" alias.st
    [ "$status" -eq 0 ]
    [[ "$output" =~ "status" ]]
}

@test "git: core editor is set" {
    run git config --file "$TEST_HOME/.gitconfig" core.editor
    [ "$status" -eq 0 ]
    [[ "$output" =~ "nvim" ]] || [[ "$output" =~ "vim" ]]
}

@test "git: global excludes file is referenced" {
    run git config --file "$TEST_HOME/.gitconfig" core.excludesfile
    [ "$status" -eq 0 ]
    # Must NOT be a file named .gitignore: the tracked copy would then act
    # as a per-directory ignore file inside the dotfiles repo itself
    [[ "$output" == *"/git/ignore"* ]]
}

@test "git: global excludes file exists at the referenced path" {
    excludes_path=$(git config --file "$TEST_HOME/.gitconfig" core.excludesfile 2>/dev/null | sed "s|~|$TEST_HOME|")

    [ -n "$excludes_path" ]
    [ -f "$excludes_path" ] || [ -L "$excludes_path" ]
}

# Scratch repo using the deployed .gitconfig (HOME=$TEST_HOME). Its
# useConfigOnly leaves no email, so supply one via the environment.
dia_repo() {
    export GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_EMAIL=test@example.com
    git init -q "$BATS_TEST_TMPDIR/repo"
    cd "$BATS_TEST_TMPDIR/repo"
    echo base > f
    git add f
    git commit -q -m base
    echo one > f
    git commit -q -am one
}

@test "git: dia shows what the last amend of HEAD changed" {
    dia_repo
    echo two > f
    git commit -q -a --amend --no-edit

    run git dia
    [ "$status" -eq 0 ]
    [[ "$output" == *"-one"* ]]
    [[ "$output" == *"+two"* ]]
}

@test "git: dia still finds the amend after HEAD moves away and back" {
    dia_repo
    echo two > f
    git commit -q -a --amend --no-edit
    # HEAD@{1} is now the base commit, so a naive HEAD@{1} diff would show base
    git switch -q -c other HEAD~1
    git switch -q -

    run git dia
    [ "$status" -eq 0 ]
    [[ "$output" == *"-one"* ]]
    [[ "$output" == *"+two"* ]]
    [[ "$output" != *"base"* ]]
}

@test "git: dia is empty for a message-only amend" {
    dia_repo
    git commit -q --amend -m reworded

    run git dia
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "git: dia fails when HEAD was not created by an amend" {
    dia_repo

    run git dia
    [ "$status" -ne 0 ]
}

# Clone of a scratch bare remote whose default branch is main, using the
# deployed .gitconfig (stm relies on its `default` and `l` aliases)
stm_repo() {
    export GIT_AUTHOR_NAME=Test GIT_COMMITTER_NAME=Test
    export GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_EMAIL=test@example.com
    git init -q --bare -b main "$BATS_TEST_TMPDIR/remote.git"
    git clone -q "$BATS_TEST_TMPDIR/remote.git" "$BATS_TEST_TMPDIR/work" 2>/dev/null
    cd "$BATS_TEST_TMPDIR/work"
    git switch -q -c main
    echo base > f
    git add f
    git commit -q -m base
    git push -q -u origin main
    git remote set-head origin main
}

@test "git: stm reports an up-to-date branch with no changes" {
    stm_repo

    run git stm
    [ "$status" -eq 0 ]
    [[ "$output" == *"0 ahead of origin/main: no changes"* ]]
    [[ "$output" == *"up to date with origin/main"* ]]
}

@test "git: stm counts and lists commits ahead" {
    stm_repo
    git switch -q -c feature
    echo more >> f
    git commit -q -am "feature work"

    run git stm
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 ahead of origin/main: 1 file changed"* ]]
    [[ "$output" == *"feature work"* ]]
}

@test "git: stm reports commits behind after fetching" {
    stm_repo
    git switch -q -c feature
    git clone -q "$BATS_TEST_TMPDIR/remote.git" "$BATS_TEST_TMPDIR/other"
    (
        cd "$BATS_TEST_TMPDIR/other"
        echo upstream > g
        git add g
        git commit -q -m upstream
        git push -q origin main
    )

    run git stm
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 behind origin/main"* ]]
}

@test "git: stm shows the branch line when upstream is not origin/<default>" {
    stm_repo
    git switch -q -c feature

    run git stm
    [ "$status" -eq 0 ]
    [[ "$output" == *"## feature"* ]]
}

@test "git: stm fails when the fetch fails" {
    stm_repo
    git remote set-url origin "$BATS_TEST_TMPDIR/missing.git"

    run git stm
    [ "$status" -ne 0 ]
    [[ "$output" == *"(fetch failed; as of last fetch)"* ]]
}
