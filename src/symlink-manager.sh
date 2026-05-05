#!/bin/bash

# Symlink manager for dotfiles
# Supports: install, uninstall, status, restore modes
# Use --dry-run or -n to preview changes without making them

set -e

# Parse flags
DRY_RUN=false
MODE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        install|uninstall|status|restore)
            if [ -n "$MODE" ]; then
                echo "Usage: $0 [-n|--dry-run] {install|uninstall|status|restore}"
                exit 1
            fi
            MODE="$1"
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Usage: $0 [-n|--dry-run] {install|uninstall|status|restore}"
            exit 1
            ;;
        *)
            echo "Unknown mode: $1"
            echo "Usage: $0 [-n|--dry-run] {install|uninstall|status|restore}"
            exit 1
            ;;
    esac
done
MODE="${MODE:-install}"

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
DESTINATIONDIR=$HOME
SOURCEDIR=$BASEDIR/src/dotfiles
CONFIGFILE=$BASEDIR/config
BACKUPSDIR=$BASEDIR/.backups

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
DIM='\033[0;90m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

path_exists() {
    [ -e "$1" ] || [ -L "$1" ]
}

is_skipped_config_line() {
    local line="$1"
    [ -z "$line" ] || [[ "$line" == \#* ]]
}

normalize_config_path() {
    local filepath="$1"
    filepath="${filepath%/}"
    printf '%s\n' "$filepath"
}

validate_relative_path() {
    local filepath="$1"

    if [ -z "$filepath" ]; then
        printf "  ${RED}✗${NC} invalid empty path in config\n"
        return 1
    fi

    case "$filepath" in
        /*)
            printf "  ${RED}✗${NC} %s (must be relative to \$HOME)\n" "$filepath"
            return 1
            ;;
        ~|~/*)
            printf "  ${RED}✗${NC} %s (must not use ~ expansion)\n" "$filepath"
            return 1
            ;;
        .|..|../*|*/..|*/../*|./*|*/./*|*/.|*//*)
            printf "  ${RED}✗${NC} %s (unsafe or ambiguous path)\n" "$filepath"
            return 1
            ;;
    esac

    if [[ "$filepath" =~ ^[[:space:]] ]] || [[ "$filepath" =~ [[:space:]]$ ]]; then
        printf "  ${RED}✗${NC} %s (leading/trailing whitespace)\n" "$filepath"
        return 1
    fi

    return 0
}

validate_config() {
    local check_sources="$1"
    local filepath line newfile
    local had_error=false

    if [ ! -f "$CONFIGFILE" ]; then
        printf "  ${RED}✗${NC} config file missing: %s\n" "$CONFIGFILE"
        return 1
    fi

    while IFS= read -r line || [ -n "$line" ]; do
        is_skipped_config_line "$line" && continue

        filepath="$(normalize_config_path "$line")"
        if ! validate_relative_path "$filepath"; then
            had_error=true
            continue
        fi

        if [ "$check_sources" = true ]; then
            newfile=$SOURCEDIR/$filepath
            if ! path_exists "$newfile"; then
                printf "  ${RED}✗${NC} %s (source missing)\n" "$filepath"
                had_error=true
            fi
        fi
    done < "$CONFIGFILE"

    if [ "$had_error" = true ]; then
        return 1
    fi
    return 0
}

backup_path() {
    local source_path="$1"
    local relative_path="$2"

    mkdir -p "$BACKUPDIR/$(dirname "$relative_path")"

    if [ -L "$source_path" ] && [ ! -e "$source_path" ]; then
        cp -P "$source_path" "$BACKUPDIR/$relative_path"
    else
        cp -RL "$source_path" "$BACKUPDIR/$relative_path"
    fi
}

install_dotfiles() {
    BACKUPDIR=$BACKUPSDIR/"$(date +%Y-%m-%d_%H-%M-%S)_$$"

    if [ "$DRY_RUN" = true ]; then
        printf "${BLUE}[DRY RUN]${NC} Preview of changes:\n\n"
    else
        if [ -d "$BACKUPDIR" ]; then
            echo "Backup directory $BACKUPDIR already exists. Please wait literally one second and try again."
            exit 1
        fi
        printf "Linking dotfiles...\n\n"
    fi

    while IFS= read -r filepath; do
        is_skipped_config_line "$filepath" && continue

        filepath="$(normalize_config_path "$filepath")"

        oldfile=$DESTINATIONDIR/$filepath
        newfile=$SOURCEDIR/$filepath

        # If the file is already correctly symlinked, skip.
        if [ "$oldfile" -ef "$newfile" ] 2>/dev/null; then
            printf "  ${DIM}✓${NC} ${filepath}\n"
            continue
        fi

        # If a file with this name already exists, it will be backed up
        if path_exists "$oldfile"; then
            if [ "$DRY_RUN" = true ]; then
                printf "  ${YELLOW}→${NC} ${filepath} (would backup existing & link)\n"
            else
                mkdir -p "$BACKUPDIR"
                # Make a deep, recursive copy, removing symlinks, preserving full path structure
                backup_path "$oldfile" "$filepath"
                rm -rf "$oldfile"
            fi
        else
            if [ "$DRY_RUN" = true ]; then
                printf "  ${BLUE}+${NC} ${filepath} (would create link)\n"
            fi
        fi

        if [ "$DRY_RUN" = false ]; then
            # Create parent directories, removing any conflicting files in the path
            local parent_dir="$(dirname "$oldfile")"
            if path_exists "$parent_dir" && [ ! -d "$parent_dir" ]; then
                # Parent path is a file, need to back it up and remove it
                mkdir -p "$BACKUPDIR"
                local parent_path="${parent_dir#$DESTINATIONDIR/}"
                backup_path "$parent_dir" "$parent_path"
                rm -rf "$parent_dir"
            fi
            mkdir -p "$parent_dir"
            ln -s "$newfile" "$oldfile"
            printf "  ${GREEN}✓${NC} ${filepath}\n"
        fi
    done < "$CONFIGFILE"

    if [ "$DRY_RUN" = true ]; then
        printf "\n${BLUE}[DRY RUN]${NC} No changes made. Run without -n to apply.\n"
    else
        printf "\n${GREEN}All dotfiles linked${NC}\n"
    fi
}

uninstall_dotfiles() {
    printf "Unlinking dotfiles...\n\n"

    while IFS= read -r filepath; do
        is_skipped_config_line "$filepath" && continue

        filepath="$(normalize_config_path "$filepath")"

        oldfile=$DESTINATIONDIR/$filepath
        newfile=$SOURCEDIR/$filepath

        # Check if it's currently symlinked to our dotfiles
        if [ "$oldfile" -ef "$newfile" ] 2>/dev/null; then
            rm -f "$oldfile"
            printf "  ${GREEN}✓${NC} ${filepath}\n"
        elif [ -L "$oldfile" ]; then
            printf "  ${YELLOW}⚠${NC} ${filepath}\n"
        elif [ -e "$oldfile" ]; then
            printf "  ${YELLOW}⚠${NC} ${filepath}\n"
        else
            printf "  ${YELLOW}⚠${NC} ${filepath}\n"
        fi
    done < "$CONFIGFILE"

    printf "\n${GREEN}All dotfiles unlinked${NC}\n"
}

show_status() {
    printf "Dotfiles status:\n\n"

    local all_ok=true

    while IFS= read -r filepath; do
        is_skipped_config_line "$filepath" && continue

        filepath="$(normalize_config_path "$filepath")"

        oldfile=$DESTINATIONDIR/$filepath
        newfile=$SOURCEDIR/$filepath

        if [ ! -e "$newfile" ]; then
            printf "  ${RED}✗${NC} ${filepath}\n"
            all_ok=false
        elif [ "$oldfile" -ef "$newfile" ] 2>/dev/null; then
            printf "  ${GREEN}✓${NC} ${filepath}\n"
        elif [ -L "$oldfile" ]; then
            printf "  ${YELLOW}⚠${NC} ${filepath}\n"
            all_ok=false
        elif [ -e "$oldfile" ]; then
            printf "  ${YELLOW}⚠${NC} ${filepath}\n"
            all_ok=false
        else
            printf "  ${RED}✗${NC} ${filepath}\n"
            all_ok=false
        fi
    done < "$CONFIGFILE"

    printf "\n"
    if $all_ok; then
        printf "${GREEN}All dotfiles linked${NC}\n"
        exit 0
    else
        printf "${YELLOW}Run 'make link' to install missing dotfiles${NC}\n"
        exit 1
    fi
}

restore_from_backup() {
    if [ ! -d "$BACKUPSDIR" ] || [ -z "$(ls -A "$BACKUPSDIR" 2>/dev/null)" ]; then
        echo "No backups found in $BACKUPSDIR"
        exit 1
    fi

    printf "Available backups:\n\n"

    local -a backups
    while IFS= read -r backup; do
        backups+=("$backup")
        printf "  [%d] %s\n" "${#backups[@]}" "$(basename "$backup")"
    done < <(find "$BACKUPSDIR" -mindepth 1 -maxdepth 1 -type d | sort -r)

    printf "\nEnter backup number to restore (or 0 to cancel): "
    read -r choice

    if [ "$choice" -eq 0 ] 2>/dev/null; then
        echo "Cancelled."
        exit 0
    fi

    if [ "$choice" -lt 1 ] 2>/dev/null || [ "$choice" -gt "${#backups[@]}" ] 2>/dev/null; then
        echo "Invalid choice."
        exit 1
    fi

    local backup_dir="${backups[$((choice-1))]}"

    printf "\nRestoring from %s...\n" "$(basename "$backup_dir")"

    # Copy all files from backup back to home
    if [ -d "$backup_dir" ]; then
        cp -R "$backup_dir"/. "$DESTINATIONDIR/"
        printf "${GREEN}Restore complete!${NC}\n"
        printf "Note: You may want to run 'make teardown' first to remove symlinks.\n"
    else
        echo "Backup directory not found."
        exit 1
    fi
}

case "$MODE" in
    install)
        if ! validate_config true; then
            printf "\n${RED}Config validation failed. No changes made.${NC}\n"
            exit 1
        fi
        install_dotfiles
        ;;
    uninstall)
        if ! validate_config false; then
            printf "\n${RED}Config validation failed. No changes made.${NC}\n"
            exit 1
        fi
        uninstall_dotfiles
        ;;
    status)
        if ! validate_config false; then
            printf "\n${RED}Config validation failed.${NC}\n"
            exit 1
        fi
        show_status
        ;;
    restore)
        restore_from_backup
        ;;
    *)
        echo "Usage: $0 [-n|--dry-run] {install|uninstall|status|restore}"
        exit 1
        ;;
esac
