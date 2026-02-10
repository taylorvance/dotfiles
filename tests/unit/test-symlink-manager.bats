#!/usr/bin/env bats

# Unit tests for symlink-manager.sh

setup() {
    # Create temporary test directories
    export TEST_DIR=$(mktemp -d)
    export TEST_HOME="$TEST_DIR/home"
    export TEST_DOTFILES="$TEST_DIR/dotfiles"
    export TEST_SOURCE="$TEST_DOTFILES/src/dotfiles"
    export TEST_CONFIG="$TEST_DOTFILES/config"
    export TEST_BACKUPS="$TEST_DOTFILES/.backups"

    mkdir -p "$TEST_HOME"
    mkdir -p "$TEST_SOURCE"
    mkdir -p "$TEST_DOTFILES/src"

    # Copy the actual symlink-manager.sh to test location
    cp "$BATS_TEST_DIRNAME/../../src/symlink-manager.sh" "$TEST_DOTFILES/src/"

    # Override HOME and BASEDIR for testing
    export HOME="$TEST_HOME"
    export ORIGINAL_HOME="$HOME"
}

teardown() {
    # Clean up test directory
    rm -rf "$TEST_DIR"
}

# Helper function to create test config
create_config() {
    echo "$@" > "$TEST_CONFIG"
}

# Helper function to run symlink-manager
run_symlink_manager() {
    cd "$TEST_DOTFILES"
    run bash src/symlink-manager.sh "$@"
}

# ============================================================================
# INSTALL MODE TESTS
# ============================================================================

@test "install: creates symlink for single file" {
    # Setup
    echo "test content" > "$TEST_SOURCE/.testfile"
    create_config ".testfile"

    # Run
    run_symlink_manager install

    # Assert
    [ "$status" -eq 0 ]
    [ -L "$TEST_HOME/.testfile" ]
    [ "$(readlink "$TEST_HOME/.testfile")" = "$TEST_SOURCE/.testfile" ]
}

@test "install: creates symlink for nested file" {
    # Setup
    mkdir -p "$TEST_SOURCE/.config/nvim"
    echo "vim config" > "$TEST_SOURCE/.config/nvim/init.vim"
    create_config ".config/nvim/init.vim"

    # Run
    run_symlink_manager install

    # Assert
    [ "$status" -eq 0 ]
    [ -L "$TEST_HOME/.config/nvim/init.vim" ]
    [ -f "$TEST_HOME/.config/nvim/init.vim" ]
}

@test "install: creates parent directories as needed" {
    # Setup
    mkdir -p "$TEST_SOURCE/.config/deep/nested/path"
    echo "content" > "$TEST_SOURCE/.config/deep/nested/path/file"
    create_config ".config/deep/nested/path/file"

    # Run
    run_symlink_manager install

    # Assert
    [ "$status" -eq 0 ]
    [ -d "$TEST_HOME/.config/deep/nested/path" ]
    [ -L "$TEST_HOME/.config/deep/nested/path/file" ]
}

@test "install: is idempotent (already symlinked)" {
    # Setup
    echo "content" > "$TEST_SOURCE/.testfile"
    create_config ".testfile"

    # First run
    run_symlink_manager install
    [ "$status" -eq 0 ]

    # Second run should not fail
    run_symlink_manager install
    [ "$status" -eq 0 ]
    [ -L "$TEST_HOME/.testfile" ]
}

@test "install: backs up conflicting regular file" {
    # Setup
    echo "old content" > "$TEST_HOME/.testfile"
    echo "new content" > "$TEST_SOURCE/.testfile"
    create_config ".testfile"

    # Run
    run_symlink_manager install

    # Assert
    [ "$status" -eq 0 ]
    [ -L "$TEST_HOME/.testfile" ]
    [ "$(cat "$TEST_HOME/.testfile")" = "new content" ]

    # Check backup was created
    [ -d "$TEST_BACKUPS" ]
    backup_dir=$(find "$TEST_BACKUPS" -mindepth 1 -maxdepth 1 -type d | head -n1)
    [ -f "$backup_dir/.testfile" ]
    [ "$(cat "$backup_dir/.testfile")" = "old content" ]
}

@test "install: backs up conflicting symlink to wrong target" {
    # Setup
    echo "wrong" > "$TEST_HOME/.wrong"
    ln -s "$TEST_HOME/.wrong" "$TEST_HOME/.testfile"
    echo "correct" > "$TEST_SOURCE/.testfile"
    create_config ".testfile"

    # Run
    run_symlink_manager install

    # Assert
    [ "$status" -eq 0 ]
    [ -L "$TEST_HOME/.testfile" ]
    [ "$(readlink "$TEST_HOME/.testfile")" = "$TEST_SOURCE/.testfile" ]
}

@test "install: backs up conflicting directory" {
    # Setup
    mkdir -p "$TEST_HOME/.config/nvim"
    echo "old config" > "$TEST_HOME/.config/nvim/init.vim"
    mkdir -p "$TEST_SOURCE/.config/nvim"
    echo "new config" > "$TEST_SOURCE/.config/nvim/init.vim"
    create_config ".config/nvim"

    # Run
    run_symlink_manager install

    # Assert
    [ "$status" -eq 0 ]
    [ -L "$TEST_HOME/.config/nvim" ]

    # Check backup was created with the directory
    backup_dir=$(find "$TEST_BACKUPS" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -n1)
    [ -n "$backup_dir" ]
    [ -d "$backup_dir" ]
    # cp -RL $HOME/.config/nvim $BACKUPDIR creates $BACKUPDIR/.config/nvim
    [ -d "$backup_dir/.config/nvim" ]
    [ -f "$backup_dir/.config/nvim/init.vim" ]
}

@test "install: skips missing source file" {
    # Setup
    create_config ".nonexistent"

    # Run
    run_symlink_manager install

    # Assert (should not create symlink, but shouldn't fail completely)
    [ ! -e "$TEST_HOME/.nonexistent" ]
}

@test "install: handles multiple files in config" {
    # Setup
    echo "content1" > "$TEST_SOURCE/.file1"
    echo "content2" > "$TEST_SOURCE/.file2"
    echo "content3" > "$TEST_SOURCE/.file3"
    printf ".file1\n.file2\n.file3\n" > "$TEST_CONFIG"

    # Run
    run_symlink_manager install

    # Assert
    [ "$status" -eq 0 ]
    [ -L "$TEST_HOME/.file1" ]
    [ -L "$TEST_HOME/.file2" ]
    [ -L "$TEST_HOME/.file3" ]
}

@test "install: skips empty lines in config" {
    # Setup
    echo "content" > "$TEST_SOURCE/.testfile"
    printf ".testfile\n\n\n" > "$TEST_CONFIG"

    # Run
    run_symlink_manager install

    # Assert
    [ "$status" -eq 0 ]
    [ -L "$TEST_HOME/.testfile" ]
}

@test "install: handles paths with trailing slash" {
    # Setup
    mkdir -p "$TEST_SOURCE/.config"
    echo "content" > "$TEST_SOURCE/.config/file"
    create_config ".config/"

    # Run
    run_symlink_manager install

    # Assert
    [ "$status" -eq 0 ]
    [ -L "$TEST_HOME/.config" ]
}

@test "install: handles files with spaces in name" {
    # Setup
    echo "content" > "$TEST_SOURCE/.my file"
    create_config ".my file"

    # Run
    run_symlink_manager install

    # Assert
    [ "$status" -eq 0 ]
    [ -L "$TEST_HOME/.my file" ]
}

# ============================================================================
# UNINSTALL MODE TESTS
# ============================================================================

@test "uninstall: removes correctly symlinked file" {
    # Setup
    echo "content" > "$TEST_SOURCE/.testfile"
    create_config ".testfile"
    run_symlink_manager install

    # Run uninstall
    run_symlink_manager uninstall

    # Assert
    [ "$status" -eq 0 ]
    [ ! -e "$TEST_HOME/.testfile" ]
}

@test "uninstall: does not remove regular file" {
    # Setup
    echo "important" > "$TEST_HOME/.testfile"
    create_config ".testfile"

    # Run uninstall
    run_symlink_manager uninstall

    # Assert (file should still exist)
    [ -f "$TEST_HOME/.testfile" ]
    [ "$(cat "$TEST_HOME/.testfile")" = "important" ]
}

@test "uninstall: does not remove symlink to wrong target" {
    # Setup
    echo "other" > "$TEST_HOME/.other"
    ln -s "$TEST_HOME/.other" "$TEST_HOME/.testfile"
    create_config ".testfile"

    # Run uninstall
    run_symlink_manager uninstall

    # Assert (symlink should still exist)
    [ -L "$TEST_HOME/.testfile" ]
}

@test "uninstall: handles non-existent file gracefully" {
    # Setup
    create_config ".nonexistent"

    # Run uninstall
    run_symlink_manager uninstall

    # Assert (should not fail)
    [ ! -e "$TEST_HOME/.nonexistent" ]
}

# ============================================================================
# STATUS MODE TESTS
# ============================================================================

@test "status: reports correctly linked file" {
    # Setup
    echo "content" > "$TEST_SOURCE/.testfile"
    create_config ".testfile"
    run_symlink_manager install

    # Run status
    run_symlink_manager status

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" =~ "✓" ]]
}

@test "status: reports missing source file" {
    # Setup
    create_config ".nonexistent"

    # Run status
    run_symlink_manager status

    # Assert
    [ "$status" -eq 1 ]
    [[ "$output" =~ "✗" ]]
}

@test "status: reports not linked file" {
    # Setup
    echo "content" > "$TEST_SOURCE/.testfile"
    create_config ".testfile"
    # Don't run install

    # Run status
    run_symlink_manager status

    # Assert
    [ "$status" -eq 1 ]
    [[ "$output" =~ "✗" ]]
}

@test "status: reports wrong symlink target" {
    # Setup
    echo "wrong" > "$TEST_HOME/.wrong"
    ln -s "$TEST_HOME/.wrong" "$TEST_HOME/.testfile"
    echo "correct" > "$TEST_SOURCE/.testfile"
    create_config ".testfile"

    # Run status
    run_symlink_manager status

    # Assert
    [ "$status" -eq 1 ]
    [[ "$output" =~ "⚠" ]]
}

@test "status: reports regular file (not symlink)" {
    # Setup
    echo "content" > "$TEST_HOME/.testfile"
    echo "source" > "$TEST_SOURCE/.testfile"
    create_config ".testfile"

    # Run status
    run_symlink_manager status

    # Assert
    [ "$status" -eq 1 ]
    [[ "$output" =~ "⚠" ]]
}

# ============================================================================
# BACKUP MECHANISM TESTS
# ============================================================================

@test "backup: creates timestamped backup directory" {
    # Setup
    echo "old" > "$TEST_HOME/.testfile"
    echo "new" > "$TEST_SOURCE/.testfile"
    create_config ".testfile"

    # Run
    run_symlink_manager install

    # Assert backup directory exists with correct format
    [ -d "$TEST_BACKUPS" ]
    backup_count=$(find "$TEST_BACKUPS" -mindepth 1 -maxdepth 1 -type d | wc -l)
    [ "$backup_count" -eq 1 ]

    backup_dir=$(find "$TEST_BACKUPS" -mindepth 1 -maxdepth 1 -type d | head -n1)
    [[ "$(basename "$backup_dir")" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}_[0-9]+$ ]]
}

@test "backup: preserves directory structure" {
    # Setup
    mkdir -p "$TEST_HOME/.config/nvim/lua"
    echo "old config" > "$TEST_HOME/.config/nvim/init.vim"
    echo "old lua" > "$TEST_HOME/.config/nvim/lua/config.lua"
    mkdir -p "$TEST_SOURCE/.config/nvim/lua"
    echo "new config" > "$TEST_SOURCE/.config/nvim/init.vim"
    create_config ".config/nvim"

    # Run
    run_symlink_manager install

    # Assert backup was created and preserves structure
    [ -d "$TEST_BACKUPS" ]
    backup_dir=$(find "$TEST_BACKUPS" -mindepth 1 -maxdepth 1 -type d | head -n1)
    [ -n "$backup_dir" ]

    # The backup preserves the full path structure
    [ -d "$backup_dir/.config/nvim" ]
    [ -f "$backup_dir/.config/nvim/init.vim" ]
    [ -f "$backup_dir/.config/nvim/lua/config.lua" ]
}

@test "backup: does not create backup dir if no conflicts" {
    # Setup
    echo "content" > "$TEST_SOURCE/.testfile"
    create_config ".testfile"

    # Run
    run_symlink_manager install

    # Assert no backup directory created
    [ ! -d "$TEST_BACKUPS" ]
}

@test "backup: handles multiple conflicting files in one run" {
    # Setup
    echo "old1" > "$TEST_HOME/.file1"
    echo "old2" > "$TEST_HOME/.file2"
    echo "new1" > "$TEST_SOURCE/.file1"
    echo "new2" > "$TEST_SOURCE/.file2"
    printf ".file1\n.file2\n" > "$TEST_CONFIG"

    # Run
    run_symlink_manager install

    # Assert single backup dir with both files
    backup_count=$(find "$TEST_BACKUPS" -mindepth 1 -maxdepth 1 -type d | wc -l)
    [ "$backup_count" -eq 1 ]

    backup_dir=$(find "$TEST_BACKUPS" -mindepth 1 -maxdepth 1 -type d | head -n1)
    [ -f "$backup_dir/.file1" ]
    [ -f "$backup_dir/.file2" ]
}

# ============================================================================
# DRY-RUN MODE TESTS
# ============================================================================

@test "dry-run: shows preview without making changes" {
    # Setup
    echo "content" > "$TEST_SOURCE/.testfile"
    create_config ".testfile"

    # Run with dry-run flag
    run_symlink_manager -n install

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" =~ "DRY RUN" ]]
    [[ "$output" =~ "would create link" ]]
    # Should NOT create the symlink
    [ ! -e "$TEST_HOME/.testfile" ]
}

@test "dry-run: --dry-run long form works" {
    # Setup
    echo "content" > "$TEST_SOURCE/.testfile"
    create_config ".testfile"

    # Run with long form flag
    run_symlink_manager --dry-run install

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" =~ "DRY RUN" ]]
    [ ! -e "$TEST_HOME/.testfile" ]
}

@test "dry-run: shows backup warning for conflicting files" {
    # Setup
    echo "old content" > "$TEST_HOME/.testfile"
    echo "new content" > "$TEST_SOURCE/.testfile"
    create_config ".testfile"

    # Run with dry-run flag
    run_symlink_manager -n install

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" =~ "would backup existing" ]]
    # Should NOT create backup or symlink
    [ ! -d "$TEST_BACKUPS" ]
    [ -f "$TEST_HOME/.testfile" ]
    [ "$(cat "$TEST_HOME/.testfile")" = "old content" ]
}

@test "dry-run: shows already linked status" {
    # Setup
    echo "content" > "$TEST_SOURCE/.testfile"
    create_config ".testfile"
    # Actually create the symlink first
    run_symlink_manager install

    # Run dry-run
    run_symlink_manager -n install

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" =~ "already linked" ]]
}

@test "dry-run: flag position can come after mode" {
    # Setup
    echo "content" > "$TEST_SOURCE/.testfile"
    create_config ".testfile"

    # Run with flag after mode
    run_symlink_manager install -n

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" =~ "DRY RUN" ]]
    [ ! -e "$TEST_HOME/.testfile" ]
}
