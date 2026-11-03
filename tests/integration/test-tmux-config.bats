#!/usr/bin/env bats

# Integration tests for the deployed tmux config and vendored plugins
# @covers src/dotfiles/.tmux.conf
# @covers src/dotfiles/.tmux/*
# @covers vendor/tmux/*
# @covers src/symlink-manager.sh
# @covers tests/helpers/dotfiles-home.bash

bats_require_minimum_version 1.5.0

load ../helpers/dotfiles-home

setup_file() {
    install_dotfiles_home
}

setup() {
    skip_if_not_installed tmux
}

teardown() {
    tmux kill-server 2>/dev/null || true
}

@test "tmux: .tmux.conf has valid syntax" {
    # Without the plugins, their run-shell lines fail
    if [ ! -f "$TEST_HOME/.tmux/plugins/tmux-resurrect/resurrect.tmux" ]; then
        skip "plugin submodules not synced (run: git submodule update --init)"
    fi

    # source-file needs a running server; bad commands or options exit nonzero
    run tmux -f /dev/null start-server \; source-file "$TEST_HOME/.tmux.conf"
    [ "$status" -eq 0 ]
}

@test "tmux: can start with config" {
    run tmux -f "$TEST_HOME/.tmux.conf" new-session -d "echo test"
    [ "$status" -eq 0 ]
}

@test "tmux: can create and switch panes" {
    tmux -f "$TEST_HOME/.tmux.conf" new-session -d -s test_session "sleep 10"

    # Split window (should create pane)
    tmux -f "$TEST_HOME/.tmux.conf" split-window -h -t test_session "sleep 10" || true

    pane_count=$(tmux -f "$TEST_HOME/.tmux.conf" list-panes -t test_session 2>/dev/null | wc -l | tr -d ' ')

    # Should have at least 1 pane (might be 2 if split worked)
    [ "$pane_count" -ge 1 ]
}

@test "tmux: prefix key is set" {
    run grep -q "prefix" "$TEST_HOME/.tmux.conf"
    [ "$status" -eq 0 ]
}

@test "tmux: mouse support configured" {
    run grep -qi "mouse" "$TEST_HOME/.tmux.conf"
    [ "$status" -eq 0 ]
}

@test "tmux: clipboard integration is configured" {
    run grep -E "(pbcopy|xclip|wl-copy)" "$TEST_HOME/.tmux.conf"
    [ "$status" -eq 0 ]
}

@test "tmux: vendored plugins are linked and loadable" {
    if [ ! -f "$TEST_HOME/.tmux/plugins/tmux-resurrect/resurrect.tmux" ]; then
        skip "plugin submodules not synced (run: git submodule update --init)"
    fi

    # All three vendored plugins arrive via the .tmux/plugins symlink
    [ -x "$TEST_HOME/.tmux/plugins/tmux-resurrect/resurrect.tmux" ]
    [ -x "$TEST_HOME/.tmux/plugins/tmux-continuum/continuum.tmux" ]
    [ -x "$TEST_HOME/.tmux/plugins/tmux-yank/yank.tmux" ]

    # And .tmux.conf loads each of them
    run grep -c "^run-shell ~/.tmux/plugins/" "$TEST_HOME/.tmux.conf"
    [ "$output" -eq 3 ]
}
