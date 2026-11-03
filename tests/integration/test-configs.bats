#!/usr/bin/env bats

# Cross-cutting checks on the whole deployed dotfiles tree. Per-tool config
# tests live in test-<tool>-config.bats with narrower @covers, so pre-push
# runs only the tool that changed plus these.
# @covers src/dotfiles/*
# @covers src/symlink-manager.sh
# @covers tests/helpers/dotfiles-home.bash

bats_require_minimum_version 1.5.0

load ../helpers/dotfiles-home

setup_file() {
    install_dotfiles_home
}

@test "integration: no broken symlinks" {
    while IFS= read -r symlink; do
        [ -e "$symlink" ] || {
            echo "Broken symlink: $symlink"
            return 1
        }
    done < <(find "$TEST_HOME" -type l 2>/dev/null || true)
}

@test "integration: all config files are accessible" {
    local f
    for f in .zshrc .gitconfig .tmux.conf; do
        if [ -L "$TEST_HOME/$f" ]; then
            [ -r "$TEST_HOME/$f" ]
        fi
    done
}

@test "integration: config files have no syntax errors" {
    local errors=0

    if [ -f "$TEST_HOME/.zshrc" ] && command -v zsh >/dev/null 2>&1; then
        zsh -n "$TEST_HOME/.zshrc" 2>/dev/null || ((errors++))
    fi

    while IFS= read -r script; do
        if [ -f "$script" ] && head -n1 "$script" | grep -q bash; then
            bash -n "$script" 2>/dev/null || ((errors++))
        fi
    done < <(find "$TEST_HOME/.local/bin" -type l 2>/dev/null || true)

    [ "$errors" -eq 0 ]
}

@test "custom scripts: every deployed script is executable with a shebang" {
    [ -d "$TEST_HOME/.local/bin" ]

    local script
    for script in "$TEST_HOME"/.local/bin/*; do
        [ -x "$script" ] || { echo "not executable: $script"; return 1; }
        [[ "$(head -n1 "$script")" == "#!"* ]] || { echo "no shebang: $script"; return 1; }
    done
}
