#!/usr/bin/env bats

# Integration tests for idempotency (safe to run multiple times)

setup() {
    export TEST_DIR=$(mktemp -d)
    export TEST_HOME="$TEST_DIR/home"
    export TEST_DOTFILES="$TEST_DIR/dotfiles"

    mkdir -p "$TEST_HOME"
    cp -r "$BATS_TEST_DIRNAME/../.." "$TEST_DOTFILES"

    export HOME="$TEST_HOME"

    # Create test config and files
    cat > "$TEST_DOTFILES/config" << 'EOF'
.testfile
.config/test.conf
EOF

    mkdir -p "$TEST_DOTFILES/src/dotfiles/.config"
    echo "content1" > "$TEST_DOTFILES/src/dotfiles/.testfile"
    echo "content2" > "$TEST_DOTFILES/src/dotfiles/.config/test.conf"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ============================================================================
# IDEMPOTENCY TESTS
# ============================================================================

@test "idempotency: running link twice succeeds" {
    cd "$TEST_DOTFILES"

    # First run
    run bash src/symlink-manager.sh install
    [ "$status" -eq 0 ]

    # Second run
    run bash src/symlink-manager.sh install
    [ "$status" -eq 0 ]
}

@test "idempotency: symlinks remain correct after multiple runs" {
    cd "$TEST_DOTFILES"

    # Run three times
    bash src/symlink-manager.sh install
    bash src/symlink-manager.sh install
    bash src/symlink-manager.sh install

    # Assert symlinks still correct
    [ "$(readlink "$TEST_HOME/.testfile")" = "$TEST_DOTFILES/src/dotfiles/.testfile" ]
    [ "$(readlink "$TEST_HOME/.config/test.conf")" = "$TEST_DOTFILES/src/dotfiles/.config/test.conf" ]
}

@test "idempotency: no backup created on re-run" {
    cd "$TEST_DOTFILES"

    # First run
    bash src/symlink-manager.sh install
    [ ! -d "$TEST_DOTFILES/.backups" ]

    # Second run
    bash src/symlink-manager.sh install
    [ ! -d "$TEST_DOTFILES/.backups" ]
}

@test "idempotency: status remains success after multiple link runs" {
    cd "$TEST_DOTFILES"

    # Link multiple times
    bash src/symlink-manager.sh install
    bash src/symlink-manager.sh install

    # Check status
    run bash src/symlink-manager.sh status
    [ "$status" -eq 0 ]
}

@test "idempotency: unlink then link restores state" {
    cd "$TEST_DOTFILES"

    # Link, unlink, link again
    bash src/symlink-manager.sh install
    bash src/symlink-manager.sh uninstall
    bash src/symlink-manager.sh install

    # Assert symlinks recreated
    [ -L "$TEST_HOME/.testfile" ]
    [ -L "$TEST_HOME/.config/test.conf" ]
}

@test "idempotency: link -> unlink -> link produces same result" {
    cd "$TEST_DOTFILES"

    # First cycle
    bash src/symlink-manager.sh install
    first_target=$(readlink "$TEST_HOME/.testfile")
    bash src/symlink-manager.sh uninstall

    # Second cycle
    bash src/symlink-manager.sh install
    second_target=$(readlink "$TEST_HOME/.testfile")

    # Assert same target
    [ "$first_target" = "$second_target" ]
}

# ============================================================================
# CONTENT INTEGRITY TESTS
# ============================================================================

@test "idempotency: file content unchanged after multiple runs" {
    cd "$TEST_DOTFILES"

    # Multiple runs
    bash src/symlink-manager.sh install
    bash src/symlink-manager.sh install
    bash src/symlink-manager.sh install

    # Assert content
    [ "$(cat "$TEST_HOME/.testfile")" = "content1" ]
    [ "$(cat "$TEST_HOME/.config/test.conf")" = "content2" ]
}

@test "idempotency: modifying source reflects through symlink" {
    cd "$TEST_DOTFILES"

    # Initial setup
    bash src/symlink-manager.sh install
    [ "$(cat "$TEST_HOME/.testfile")" = "content1" ]

    # Modify source
    echo "modified" > "$TEST_DOTFILES/src/dotfiles/.testfile"

    # Should see changes immediately (no re-link needed)
    [ "$(cat "$TEST_HOME/.testfile")" = "modified" ]

    # Re-link should not break this
    bash src/symlink-manager.sh install
    [ "$(cat "$TEST_HOME/.testfile")" = "modified" ]
}

# ============================================================================
# CONFIG CHANGES TESTS
# ============================================================================

@test "idempotency: adding new file to config links it" {
    cd "$TEST_DOTFILES"

    # Initial setup
    bash src/symlink-manager.sh install
    [ -L "$TEST_HOME/.testfile" ]

    # Add new file
    echo "new content" > "$TEST_DOTFILES/src/dotfiles/.newfile"
    echo ".newfile" >> "$TEST_DOTFILES/config"

    # Re-run
    bash src/symlink-manager.sh install

    # Assert new file linked, old files unchanged
    [ -L "$TEST_HOME/.testfile" ]
    [ -L "$TEST_HOME/.newfile" ]
}

@test "idempotency: removing file from config does not unlink" {
    cd "$TEST_DOTFILES"

    # Initial setup with file
    bash src/symlink-manager.sh install
    [ -L "$TEST_HOME/.testfile" ]

    # Remove from config
    grep -v ".testfile" "$TEST_DOTFILES/config" > "$TEST_DOTFILES/config.tmp"
    mv "$TEST_DOTFILES/config.tmp" "$TEST_DOTFILES/config"

    # Re-run
    bash src/symlink-manager.sh install

    # Assert file still linked (manual unlink required)
    [ -L "$TEST_HOME/.testfile" ]
}

# ============================================================================
# CONCURRENT EXECUTION TESTS
# ============================================================================

@test "idempotency: sequential runs with different PIDs succeed" {
    cd "$TEST_DOTFILES"

    # Run in subshells (different PIDs)
    ( bash src/symlink-manager.sh install )
    [ "$?" -eq 0 ]

    ( bash src/symlink-manager.sh install )
    [ "$?" -eq 0 ]

    # Assert still correct
    [ -L "$TEST_HOME/.testfile" ]
}

# ============================================================================
# STATUS CHECKING TESTS
# ============================================================================

@test "idempotency: status after link is always success" {
    cd "$TEST_DOTFILES"

    # Link and check status multiple times
    bash src/symlink-manager.sh install
    run bash src/symlink-manager.sh status
    [ "$status" -eq 0 ]

    bash src/symlink-manager.sh install
    run bash src/symlink-manager.sh status
    [ "$status" -eq 0 ]
}

@test "idempotency: unlink then status shows not linked" {
    cd "$TEST_DOTFILES"

    # Link then unlink
    bash src/symlink-manager.sh install
    bash src/symlink-manager.sh uninstall

    # Status should report not linked
    run bash src/symlink-manager.sh status
    [ "$status" -eq 1 ]
}
