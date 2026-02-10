#!/usr/bin/env bats

# Integration tests for conflict handling and backup/restore

setup() {
    export TEST_DIR=$(mktemp -d)
    export TEST_HOME="$TEST_DIR/home"
    export TEST_DOTFILES="$TEST_DIR/dotfiles"

    mkdir -p "$TEST_HOME"
    cp -r "$BATS_TEST_DIRNAME/../.." "$TEST_DOTFILES"

    export HOME="$TEST_HOME"

    # Create test config
    cat > "$TEST_DOTFILES/config" << 'EOF'
.testfile
.config/test.conf
EOF

    mkdir -p "$TEST_DOTFILES/src/dotfiles/.config"
    echo "new content" > "$TEST_DOTFILES/src/dotfiles/.testfile"
    echo "new config" > "$TEST_DOTFILES/src/dotfiles/.config/test.conf"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ============================================================================
# CONFLICT DETECTION TESTS
# ============================================================================

@test "conflicts: detects conflicting regular file" {
    # Setup existing file
    echo "old content" > "$TEST_HOME/.testfile"

    cd "$TEST_DOTFILES"
    run bash src/symlink-manager.sh install

    # Should succeed and backup old file
    [ "$status" -eq 0 ]
    [ -L "$TEST_HOME/.testfile" ]
    [ -d "$TEST_DOTFILES/.backups" ]
}

@test "conflicts: detects conflicting directory" {
    # Setup existing directory
    mkdir -p "$TEST_HOME/.config"
    echo "old config" > "$TEST_HOME/.config/test.conf"

    cd "$TEST_DOTFILES"
    bash src/symlink-manager.sh install

    # Should replace with symlink
    [ -L "$TEST_HOME/.config/test.conf" ]
}

@test "conflicts: detects wrong symlink target" {
    # Setup symlink to wrong target
    echo "wrong" > "$TEST_HOME/.wrong"
    ln -s "$TEST_HOME/.wrong" "$TEST_HOME/.testfile"

    cd "$TEST_DOTFILES"
    bash src/symlink-manager.sh install

    # Should replace with correct symlink
    [ "$(readlink "$TEST_HOME/.testfile")" = "$TEST_DOTFILES/src/dotfiles/.testfile" ]
}

# ============================================================================
# BACKUP CREATION TESTS
# ============================================================================

@test "backup: creates backup for conflicting file" {
    # Setup conflict
    echo "important data" > "$TEST_HOME/.testfile"

    cd "$TEST_DOTFILES"
    bash src/symlink-manager.sh install

    # Assert backup created
    [ -d "$TEST_DOTFILES/.backups" ]
    backup_dir=$(find "$TEST_DOTFILES/.backups" -mindepth 1 -maxdepth 1 -type d | head -n1)
    [ -f "$backup_dir/.testfile" ]
    [ "$(cat "$backup_dir/.testfile")" = "important data" ]
}

@test "backup: preserves directory structure" {
    # Setup conflicting file (only .config/test.conf is in config, so only it will be backed up)
    mkdir -p "$TEST_HOME/.config"
    echo "data1" > "$TEST_HOME/.config/test.conf"

    cd "$TEST_DOTFILES"
    bash src/symlink-manager.sh install

    # Assert backup preserves structure
    backup_dir=$(find "$TEST_DOTFILES/.backups" -mindepth 1 -maxdepth 1 -type d | head -n1)
    # cp -RL creates the full path in the backup
    [ -f "$backup_dir/.config/test.conf" ]
    [ "$(cat "$backup_dir/.config/test.conf")" = "data1" ]
}

@test "backup: directory name has correct format" {
    # Setup conflict
    echo "data" > "$TEST_HOME/.testfile"

    cd "$TEST_DOTFILES"
    bash src/symlink-manager.sh install

    # Check backup directory name format: YYYY-MM-DD_HH-MM-SS_PID
    backup_dir=$(find "$TEST_DOTFILES/.backups" -mindepth 1 -maxdepth 1 -type d | head -n1)
    backup_name=$(basename "$backup_dir")
    [[ "$backup_name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}_[0-9]+$ ]]
}

@test "backup: multiple conflicts go to same backup directory" {
    # Setup multiple conflicts
    echo "old1" > "$TEST_HOME/.testfile"
    mkdir -p "$TEST_HOME/.config"
    echo "old2" > "$TEST_HOME/.config/test.conf"

    cd "$TEST_DOTFILES"
    bash src/symlink-manager.sh install

    # Assert single backup directory
    backup_count=$(find "$TEST_DOTFILES/.backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    [ "$backup_count" -eq 1 ]

    # Both files backed up with full paths
    backup_dir=$(find "$TEST_DOTFILES/.backups" -mindepth 1 -maxdepth 1 -type d | head -n1)
    [ -f "$backup_dir/.testfile" ]
    [ -f "$backup_dir/.config/test.conf" ]
}

@test "backup: separate runs create separate backup directories" {
    cd "$TEST_DOTFILES"

    # First conflict
    echo "conflict1" > "$TEST_HOME/.testfile"
    bash src/symlink-manager.sh install
    sleep 1  # Ensure different timestamp

    # Unlink and create new conflict
    bash src/symlink-manager.sh uninstall
    echo "conflict2" > "$TEST_HOME/.testfile"
    bash src/symlink-manager.sh install

    # Assert two backup directories
    backup_count=$(find "$TEST_DOTFILES/.backups" -mindepth 1 -maxdepth 1 -type d | wc -l)
    [ "$backup_count" -eq 2 ]
}

@test "backup: handles symlink in existing files" {
    # Setup: existing file is itself a symlink
    echo "target content" > "$TEST_HOME/.target"
    ln -s "$TEST_HOME/.target" "$TEST_HOME/.testfile"

    cd "$TEST_DOTFILES"
    bash src/symlink-manager.sh install

    # Backup should dereference symlink (cp -RL)
    backup_dir=$(find "$TEST_DOTFILES/.backups" -mindepth 1 -maxdepth 1 -type d | head -n1)
    [ -f "$backup_dir/.testfile" ]
    [ ! -L "$backup_dir/.testfile" ]  # Should be regular file, not symlink
    [ "$(cat "$backup_dir/.testfile")" = "target content" ]
}

# ============================================================================
# RESTORE TESTS
# ============================================================================

@test "restore: lists available backups" {
    cd "$TEST_DOTFILES"

    # Create two backups
    echo "old1" > "$TEST_HOME/.testfile"
    bash src/symlink-manager.sh install
    sleep 1

    bash src/symlink-manager.sh uninstall
    echo "old2" > "$TEST_HOME/.testfile"
    bash src/symlink-manager.sh install

    # Try to restore (will prompt, but we can check output)
    run bash -c "echo 0 | bash src/symlink-manager.sh restore"

    # Should mention backups
    [[ "$output" =~ "backup" ]] || [[ "$output" =~ "Available" ]]
}

@test "restore: exits gracefully with no backups" {
    cd "$TEST_DOTFILES"

    # Try to restore with no backups
    run bash -c "echo 0 | bash src/symlink-manager.sh restore"

    # Should handle gracefully
    [[ "$output" =~ "No backups" ]] || [[ "$output" =~ "backup" ]]
}

# ============================================================================
# COMPLEX CONFLICT SCENARIOS
# ============================================================================

@test "conflicts: handles existing directory when expecting file" {
    # Setup: home has directory, dotfiles has file
    mkdir -p "$TEST_HOME/.testfile"
    echo "data" > "$TEST_HOME/.testfile/subfile"

    cd "$TEST_DOTFILES"
    bash src/symlink-manager.sh install

    # Should backup directory and create file symlink
    [ -L "$TEST_HOME/.testfile" ]
    backup_dir=$(find "$TEST_DOTFILES/.backups" -mindepth 1 -maxdepth 1 -type d | head -n1)
    [ -f "$backup_dir/.testfile/subfile" ]
}

@test "conflicts: handles existing file when expecting directory" {
    # Setup: home has file, dotfiles has directory
    echo "file content" > "$TEST_HOME/.config"
    # Note: .config/test.conf is in our test config

    cd "$TEST_DOTFILES"
    bash src/symlink-manager.sh install

    # Should backup file and create directory symlink
    [ -L "$TEST_HOME/.config/test.conf" ]
    backup_dir=$(find "$TEST_DOTFILES/.backups" -mindepth 1 -maxdepth 1 -type d | head -n1)
    [ -f "$backup_dir/.config" ]
    [ "$(cat "$backup_dir/.config")" = "file content" ]
}

@test "conflicts: preserves permissions in backup" {
    # Setup: executable file
    echo "#!/bin/bash" > "$TEST_HOME/.testfile"
    chmod +x "$TEST_HOME/.testfile"

    cd "$TEST_DOTFILES"
    bash src/symlink-manager.sh install

    # Check backup preserves permissions
    backup_dir=$(find "$TEST_DOTFILES/.backups" -mindepth 1 -maxdepth 1 -type d | head -n1)
    [ -x "$backup_dir/.testfile" ]
}

@test "conflicts: handles special characters in filenames" {
    # Setup
    echo "content" > "$TEST_DOTFILES/src/dotfiles/.test file"
    echo ".test file" >> "$TEST_DOTFILES/config"
    echo "old" > "$TEST_HOME/.test file"

    cd "$TEST_DOTFILES"
    bash src/symlink-manager.sh install

    # Should handle spaces
    [ -L "$TEST_HOME/.test file" ]
    backup_dir=$(find "$TEST_DOTFILES/.backups" -mindepth 1 -maxdepth 1 -type d | head -n1)
    [ -f "$backup_dir/.test file" ]
}

# ============================================================================
# DATA INTEGRITY TESTS
# ============================================================================

@test "integrity: new symlink has correct content" {
    # Setup conflict
    echo "old content" > "$TEST_HOME/.testfile"

    cd "$TEST_DOTFILES"
    bash src/symlink-manager.sh install

    # New symlink should show new content
    [ "$(cat "$TEST_HOME/.testfile")" = "new content" ]
}

@test "integrity: backed up file has original content" {
    # Setup conflict with specific content
    echo "precious data that must not be lost" > "$TEST_HOME/.testfile"

    cd "$TEST_DOTFILES"
    bash src/symlink-manager.sh install

    # Check backup has original content
    backup_dir=$(find "$TEST_DOTFILES/.backups" -mindepth 1 -maxdepth 1 -type d | head -n1)
    [ "$(cat "$backup_dir/.testfile")" = "precious data that must not be lost" ]
}

@test "integrity: backup is independent copy, not symlink" {
    # Setup conflict
    echo "original" > "$TEST_HOME/.testfile"

    cd "$TEST_DOTFILES"
    bash src/symlink-manager.sh install

    # Modify source
    echo "modified" > "$TEST_DOTFILES/src/dotfiles/.testfile"

    # Backup should still have original content (not affected by source change)
    backup_dir=$(find "$TEST_DOTFILES/.backups" -mindepth 1 -maxdepth 1 -type d | head -n1)
    [ "$(cat "$backup_dir/.testfile")" = "original" ]
}
