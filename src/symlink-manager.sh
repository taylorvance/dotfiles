#!/bin/bash

# Symlink manager for dotfiles
# Supports: install, uninstall, status, restore modes
# Use --dry-run or -n to preview changes without making them

set -e

# Parse flags
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            MODE="$1"
            shift
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
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
        # Skip empty lines
        [ -z "$filepath" ] && continue

        # Remove trailing slash (necessary because ln -s behaves differently for directories with trailing slashes)
        filepath=${filepath%/}

        oldfile=$DESTINATIONDIR/$filepath
        newfile=$SOURCEDIR/$filepath

        if [ ! -e "$newfile" ]; then
            printf "  ${RED}✗${NC} ${filepath} (source missing)\n"
            continue
        fi

        # If the file is already correctly symlinked, skip.
        if [ "$oldfile" -ef "$newfile" ] 2>/dev/null; then
            printf "  ${GREEN}✓${NC} ${filepath} (already linked)\n"
            continue
        fi

        # If a file with this name already exists, it will be backed up
        if [ -e "$oldfile" ]; then
            if [ "$DRY_RUN" = true ]; then
                printf "  ${YELLOW}→${NC} ${filepath} (would backup existing & link)\n"
            else
                mkdir -p "$BACKUPDIR"
                # Make a deep, recursive copy, removing symlinks, preserving full path structure
                mkdir -p "$BACKUPDIR/$(dirname "$filepath")"
                cp -RL "$oldfile" "$BACKUPDIR/$filepath"
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
            if [ -f "$parent_dir" ]; then
                # Parent path is a file, need to back it up and remove it
                mkdir -p "$BACKUPDIR"
                local parent_path="${parent_dir#$DESTINATIONDIR/}"
                mkdir -p "$BACKUPDIR/$(dirname "$parent_path")"
                cp -RL "$parent_dir" "$BACKUPDIR/$parent_path"
                rm -rf "$parent_dir"
            fi
            mkdir -p "$parent_dir"
            ln -Ffs "$newfile" "$oldfile"
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
        # Skip empty lines
        [ -z "$filepath" ] && continue

        filepath=${filepath%/}

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
        # Skip empty lines
        [ -z "$filepath" ] && continue

        filepath=${filepath%/}

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
        install_dotfiles
        ;;
    uninstall)
        uninstall_dotfiles
        ;;
    status)
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
