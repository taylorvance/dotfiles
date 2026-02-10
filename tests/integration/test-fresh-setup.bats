#!/usr/bin/env bats

# Integration tests for fresh system setup

setup() {
    # Create temporary test environment
    export TEST_DIR=$(mktemp -d)
    export TEST_HOME="$TEST_DIR/home"
    export TEST_DOTFILES="$TEST_DIR/dotfiles"

    mkdir -p "$TEST_HOME"

    # Copy entire dotfiles structure
    cp -r "$BATS_TEST_DIRNAME/../.." "$TEST_DOTFILES"

    # Override HOME
    export HOME="$TEST_HOME"

    # Create minimal test config
    cat > "$TEST_DOTFILES/config" << 'EOF'
.zshrc
.gitconfig
.tmux.conf
EOF

    # Create minimal test dotfiles
    mkdir -p "$TEST_DOTFILES/src/dotfiles"
    echo "# Test zshrc" > "$TEST_DOTFILES/src/dotfiles/.zshrc"
    echo "# Test gitconfig" > "$TEST_DOTFILES/src/dotfiles/.gitconfig"
    echo "# Test tmux.conf" > "$TEST_DOTFILES/src/dotfiles/.tmux.conf"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ============================================================================
# FRESH SETUP TESTS
# ============================================================================

@test "fresh setup: creates all symlinks on clean system" {
    # Run
    cd "$TEST_DOTFILES"
    run bash src/symlink-manager.sh install

    # Assert
    [ "$status" -eq 0 ]
    [ -L "$TEST_HOME/.zshrc" ]
    [ -L "$TEST_HOME/.gitconfig" ]
    [ -L "$TEST_HOME/.tmux.conf" ]
}

@test "fresh setup: symlinks point to correct targets" {
    # Run
    cd "$TEST_DOTFILES"
    bash src/symlink-manager.sh install

    # Assert
    [ "$(readlink "$TEST_HOME/.zshrc")" = "$TEST_DOTFILES/src/dotfiles/.zshrc" ]
    [ "$(readlink "$TEST_HOME/.gitconfig")" = "$TEST_DOTFILES/src/dotfiles/.gitconfig" ]
    [ "$(readlink "$TEST_HOME/.tmux.conf")" = "$TEST_DOTFILES/src/dotfiles/.tmux.conf" ]
}

@test "fresh setup: files are readable through symlinks" {
    # Run
    cd "$TEST_DOTFILES"
    bash src/symlink-manager.sh install

    # Assert
    grep -q "Test zshrc" "$TEST_HOME/.zshrc"
    grep -q "Test gitconfig" "$TEST_HOME/.gitconfig"
    grep -q "Test tmux.conf" "$TEST_HOME/.tmux.conf"
}

@test "fresh setup: does not create backup directory" {
    # Run
    cd "$TEST_DOTFILES"
    bash src/symlink-manager.sh install

    # Assert
    [ ! -d "$TEST_DOTFILES/.backups" ]
}

@test "fresh setup: status shows all linked" {
    # Run
    cd "$TEST_DOTFILES"
    bash src/symlink-manager.sh install
    run bash src/symlink-manager.sh status

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" =~ "✓" ]]
}

# ============================================================================
# NESTED DIRECTORY TESTS
# ============================================================================

@test "fresh setup: handles nested config directories" {
    # Setup
    mkdir -p "$TEST_DOTFILES/src/dotfiles/.config/nvim/lua"
    echo "init.vim content" > "$TEST_DOTFILES/src/dotfiles/.config/nvim/init.vim"
    echo "config.lua content" > "$TEST_DOTFILES/src/dotfiles/.config/nvim/lua/config.lua"
    echo ".config/nvim" >> "$TEST_DOTFILES/config"

    # Run
    cd "$TEST_DOTFILES"
    bash src/symlink-manager.sh install

    # Assert
    [ -L "$TEST_HOME/.config/nvim" ]
    [ -f "$TEST_HOME/.config/nvim/init.vim" ]
    [ -f "$TEST_HOME/.config/nvim/lua/config.lua" ]
}

@test "fresh setup: creates deep parent directories" {
    # Setup
    mkdir -p "$TEST_DOTFILES/src/dotfiles/.local/share/nvim/site"
    echo "content" > "$TEST_DOTFILES/src/dotfiles/.local/share/nvim/site/file"
    echo ".local/share/nvim/site/file" >> "$TEST_DOTFILES/config"

    # Run
    cd "$TEST_DOTFILES"
    bash src/symlink-manager.sh install

    # Assert
    [ -d "$TEST_HOME/.local/share/nvim/site" ]
    [ -L "$TEST_HOME/.local/share/nvim/site/file" ]
    [ -f "$TEST_HOME/.local/share/nvim/site/file" ]
}

# ============================================================================
# MIXED SCENARIOS
# ============================================================================

@test "fresh setup: handles mix of files and directories" {
    # Setup
    echo "file content" > "$TEST_DOTFILES/src/dotfiles/.file"
    mkdir -p "$TEST_DOTFILES/src/dotfiles/.dir"
    echo "dir content" > "$TEST_DOTFILES/src/dotfiles/.dir/file"
    cat >> "$TEST_DOTFILES/config" << 'EOF'
.file
.dir
EOF

    # Run
    cd "$TEST_DOTFILES"
    bash src/symlink-manager.sh install

    # Assert
    [ -L "$TEST_HOME/.file" ]
    [ -L "$TEST_HOME/.dir" ]
    [ -f "$TEST_HOME/.file" ]
    [ -d "$TEST_HOME/.dir" ]
}

# ============================================================================
# ERROR HANDLING
# ============================================================================

@test "fresh setup: continues on missing source file" {
    # Setup
    echo ".nonexistent" >> "$TEST_DOTFILES/config"

    # Run
    cd "$TEST_DOTFILES"
    run bash src/symlink-manager.sh install

    # Assert - should still succeed for other files
    [ -L "$TEST_HOME/.zshrc" ]
    [ -L "$TEST_HOME/.gitconfig" ]
    [ ! -e "$TEST_HOME/.nonexistent" ]
}

@test "fresh setup: handles empty config file" {
    # Setup
    echo "" > "$TEST_DOTFILES/config"

    # Run
    cd "$TEST_DOTFILES"
    run bash src/symlink-manager.sh install

    # Assert
    [ "$status" -eq 0 ]
}

# ============================================================================
# PERMISSIONS TESTS
# ============================================================================

@test "fresh setup: preserves file permissions through symlink" {
    # Setup
    echo "#!/bin/bash" > "$TEST_DOTFILES/src/dotfiles/.script.sh"
    chmod +x "$TEST_DOTFILES/src/dotfiles/.script.sh"
    echo ".script.sh" >> "$TEST_DOTFILES/config"

    # Run
    cd "$TEST_DOTFILES"
    bash src/symlink-manager.sh install

    # Assert
    [ -L "$TEST_HOME/.script.sh" ]
    [ -x "$TEST_HOME/.script.sh" ]
}
