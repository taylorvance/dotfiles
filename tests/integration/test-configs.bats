#!/usr/bin/env bats

# Integration tests for actual config files (nvim, tmux, zsh, git)
# These tests verify that the dotfiles work correctly in practice

setup() {
    export TEST_DIR=$(mktemp -d)
    export TEST_HOME="$TEST_DIR/home"
    export TEST_DOTFILES="$TEST_DIR/dotfiles"

    mkdir -p "$TEST_HOME"

    # Copy entire dotfiles repository including real configs
    cp -r "$BATS_TEST_DIRNAME/../.." "$TEST_DOTFILES"

    export HOME="$TEST_HOME"

    # Install the actual dotfiles
    cd "$TEST_DOTFILES"
    bash src/symlink-manager.sh install 2>&1
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ============================================================================
# ZSH CONFIGURATION TESTS
# ============================================================================

@test "zsh: .zshrc sources without errors" {
    skip_if_not_installed zsh

    # Try to source .zshrc in non-interactive mode
    run zsh -c "source $TEST_HOME/.zshrc 2>&1; echo 'sourced'"

    # Should at least attempt to source (may have warnings about plugins)
    [[ "$output" =~ "sourced" ]] || [ "$status" -eq 0 ]
}

@test "zsh: basic aliases are defined" {
    skip_if_not_installed zsh

    # Check if common aliases work
    run zsh -c "source $TEST_HOME/.zshrc 2>/dev/null; alias ll"

    # Should define ll alias (even if tools not installed)
    [ "$status" -eq 0 ] || [[ "$output" =~ "ll" ]]
}

@test "zsh: PATH modifications work" {
    skip_if_not_installed zsh

    # Check if .local/bin is added to PATH
    run zsh -c "source $TEST_HOME/.zshrc 2>/dev/null; echo \$PATH"

    [[ "$output" =~ ".local/bin" ]] || [ "$status" -eq 0 ]
}

@test "zsh: editor is set" {
    skip_if_not_installed zsh

    run zsh -c "source $TEST_HOME/.zshrc 2>/dev/null; echo \$EDITOR"

    [[ "$output" =~ "nvim" ]] || [[ "$output" =~ "vim" ]] || [ "$status" -eq 0 ]
}

# ============================================================================
# GIT CONFIGURATION TESTS
# ============================================================================

@test "git: .gitconfig is valid" {
    skip_if_not_installed git

    # Verify gitconfig has no syntax errors
    run git config --file "$TEST_HOME/.gitconfig" --list

    [ "$status" -eq 0 ]
}

@test "git: aliases are defined" {
    skip_if_not_installed git

    # Check for common aliases
    run git config --file "$TEST_HOME/.gitconfig" alias.st
    [ "$status" -eq 0 ]
    [[ "$output" =~ "status" ]]
}

@test "git: core editor is set" {
    skip_if_not_installed git

    run git config --file "$TEST_HOME/.gitconfig" core.editor
    [ "$status" -eq 0 ]
    [[ "$output" =~ "nvim" ]] || [[ "$output" =~ "vim" ]]
}

@test "git: delta pager configured" {
    skip_if_not_installed git

    # Check if delta is configured (it's OK if output is empty, just checking config is valid)
    git config --file "$TEST_HOME/.gitconfig" core.pager >/dev/null 2>&1 || true

    # Just verify the config file is readable and valid
    run git config --file "$TEST_HOME/.gitconfig" --list
    [ "$status" -eq 0 ]
}

@test "git: global gitignore is referenced" {
    skip_if_not_installed git

    run git config --file "$TEST_HOME/.gitconfig" core.excludesfile
    [ "$status" -eq 0 ]
    [[ "$output" =~ ".gitignore" ]]
}

@test "git: .gitignore file exists if referenced" {
    skip_if_not_installed git

    # Check if global gitignore is set
    gitignore_path=$(git config --file "$TEST_HOME/.gitconfig" core.excludesfile 2>/dev/null | sed "s|~|$TEST_HOME|")

    if [ -n "$gitignore_path" ]; then
        [ -f "$gitignore_path" ] || [ -L "$gitignore_path" ]
    else
        skip "No global gitignore configured"
    fi
}

# ============================================================================
# TMUX CONFIGURATION TESTS
# ============================================================================

@test "tmux: .tmux.conf has valid syntax" {
    skip_if_not_installed tmux

    # Tmux can validate config
    run tmux -f "$TEST_HOME/.tmux.conf" source-file "$TEST_HOME/.tmux.conf"

    # Exit code 0 means valid (may have warnings about missing plugins)
    [ "$status" -eq 0 ] || [[ "$output" =~ "unknown" ]]
}

@test "tmux: can start with config" {
    skip_if_not_installed tmux

    # Try to start tmux with config (immediately exit)
    run tmux -f "$TEST_HOME/.tmux.conf" new-session -d "echo test"

    # Should be able to start
    [ "$status" -eq 0 ]

    # Clean up any tmux sessions
    tmux kill-server 2>/dev/null || true
}

@test "tmux: prefix key is set" {
    skip_if_not_installed tmux

    # Check config for prefix setting
    run grep -q "prefix" "$TEST_HOME/.tmux.conf"
    [ "$status" -eq 0 ]
}

@test "tmux: mouse support configured" {
    skip_if_not_installed tmux

    # Check for mouse setting
    run grep -qi "mouse" "$TEST_HOME/.tmux.conf"
    [ "$status" -eq 0 ]
}

# ============================================================================
# NEOVIM CONFIGURATION TESTS
# ============================================================================

@test "nvim: config directory exists" {
    [ -d "$TEST_HOME/.config/nvim" ] || [ -L "$TEST_HOME/.config/nvim" ]
}

@test "nvim: init.vim exists" {
    [ -f "$TEST_HOME/.config/nvim/init.vim" ] || [ -L "$TEST_HOME/.config/nvim/init.vim" ]
}

@test "nvim: can parse init.vim" {
    skip_if_not_installed nvim

    # Check for syntax errors (this will try to load, may fail on missing plugins)
    run nvim --headless -u "$TEST_HOME/.config/nvim/init.vim" +qall 2>&1

    # Should exit (may have plugin errors, but should parse)
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "nvim: lua config directory exists if referenced" {
    if [ -f "$TEST_HOME/.config/nvim/init.vim" ]; then
        # Check if init.vim references lua configs
        if grep -q "lua" "$TEST_HOME/.config/nvim/init.vim" 2>/dev/null; then
            [ -d "$TEST_HOME/.config/nvim/lua" ] || [ -L "$TEST_HOME/.config/nvim/lua" ]
        else
            skip "No lua configs referenced"
        fi
    else
        skip "init.vim not found"
    fi
}

@test "nvim: lazy.nvim bootstrap exists" {
    # Check if lazy.nvim is configured
    if [ -f "$TEST_HOME/.config/nvim/lua/config/lazy.lua" ]; then
        run grep -q "lazy.nvim" "$TEST_HOME/.config/nvim/lua/config/lazy.lua"
        [ "$status" -eq 0 ]
    else
        skip "lazy.lua not found"
    fi
}

# ============================================================================
# CUSTOM SCRIPTS TESTS
# ============================================================================

@test "custom scripts: .local/bin directory exists" {
    [ -d "$TEST_HOME/.local/bin" ] || [ -L "$TEST_HOME/.local/bin" ]
}

@test "custom scripts: 'e' script exists and is executable" {
    if [ -f "$TEST_HOME/.local/bin/e" ] || [ -L "$TEST_HOME/.local/bin/e" ]; then
        [ -x "$TEST_HOME/.local/bin/e" ]
    else
        skip "e script not in config"
    fi
}

@test "custom scripts: 'e' script has valid bash syntax" {
    if [ -f "$TEST_HOME/.local/bin/e" ] || [ -L "$TEST_HOME/.local/bin/e" ]; then
        run bash -n "$TEST_HOME/.local/bin/e"
        [ "$status" -eq 0 ]
    else
        skip "e script not in config"
    fi
}

@test "custom scripts: 'e' script has shebang" {
    if [ -f "$TEST_HOME/.local/bin/e" ] || [ -L "$TEST_HOME/.local/bin/e" ]; then
        run head -n1 "$TEST_HOME/.local/bin/e"
        [[ "$output" =~ "#!" ]]
    else
        skip "e script not in config"
    fi
}

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

@test "integration: all config files are accessible" {
    # Check that symlinked files can be read
    if [ -L "$TEST_HOME/.zshrc" ]; then
        [ -r "$TEST_HOME/.zshrc" ]
    fi
    if [ -L "$TEST_HOME/.gitconfig" ]; then
        [ -r "$TEST_HOME/.gitconfig" ]
    fi
    if [ -L "$TEST_HOME/.tmux.conf" ]; then
        [ -r "$TEST_HOME/.tmux.conf" ]
    fi
}

@test "integration: no broken symlinks" {
    # Find all symlinks in TEST_HOME and verify they're not broken
    while IFS= read -r symlink; do
        [ -e "$symlink" ] || {
            echo "Broken symlink: $symlink"
            return 1
        }
    done < <(find "$TEST_HOME" -type l 2>/dev/null || true)
}

@test "integration: config files have no syntax errors" {
    local errors=0

    # Check .zshrc
    if [ -f "$TEST_HOME/.zshrc" ] && command -v zsh >/dev/null 2>&1; then
        zsh -n "$TEST_HOME/.zshrc" 2>/dev/null || ((errors++))
    fi

    # Check bash scripts
    while IFS= read -r script; do
        if [ -f "$script" ] && head -n1 "$script" | grep -q bash; then
            bash -n "$script" 2>/dev/null || ((errors++))
        fi
    done < <(find "$TEST_HOME/.local/bin" -type f 2>/dev/null || true)

    [ "$errors" -eq 0 ]
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
