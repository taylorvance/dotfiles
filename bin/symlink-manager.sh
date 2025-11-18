#!/bin/bash

# Symlink manager for dotfiles
# Supports: install, uninstall, status, restore modes

set -e

MODE="${1:-install}"
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
DESTINATIONDIR=$HOME
SOURCEDIR=$BASEDIR/home-away-from-HOME
CONFIGFILE=$BASEDIR/config
BACKUPSDIR=$BASEDIR/backups

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

install_dotfiles() {
    BACKUPDIR=$BACKUPSDIR/"$(date +%Y-%m-%d_%H-%M-%S)_$$"

    if [ -d "$BACKUPDIR" ]; then
        echo "Backup directory $BACKUPDIR already exists. Please wait literally one second and try again."
        exit 1
    fi

    printf "Installing dotfiles...\n"

    while IFS= read -r filepath; do
        # Skip empty lines
        [ -z "$filepath" ] && continue

        # Remove trailing slash (necessary because ln -s behaves differently for directories with trailing slashes)
        filepath=${filepath%/}

        printf "\n${filepath}:  "

        oldfile=$DESTINATIONDIR/$filepath
        newfile=$SOURCEDIR/$filepath

        if [ ! -e "$newfile" ]; then
            printf "${RED}source not found${NC}"
            continue
        fi

        # If the file is already correctly symlinked, skip.
        if [ "$oldfile" -ef "$newfile" ] 2>/dev/null; then
            printf "${GREEN}already installed${NC}"
            continue
        fi

        # If a file with this name already exists, copy it to the backup folder to avoid overwriting.
        if [ -e "$oldfile" ]; then
            mkdir -p "$BACKUPDIR"
            # Make a deep, recursive copy, removing symlinks.
            cp -RL "$oldfile" "$BACKUPDIR"
            rm -rf "$oldfile"
            printf "${YELLOW}backed up${NC}; "
        fi

        mkdir -p "$(dirname "$oldfile")"
        ln -Ffs "$newfile" "$oldfile"
        printf "${GREEN}installed${NC}"
    done < "$CONFIGFILE"

    printf "\n\n${GREEN}Installation complete!${NC}\n"
}

uninstall_dotfiles() {
    printf "Uninstalling dotfiles...\n"

    while IFS= read -r filepath; do
        # Skip empty lines
        [ -z "$filepath" ] && continue

        filepath=${filepath%/}

        printf "\n${filepath}:  "

        oldfile=$DESTINATIONDIR/$filepath
        newfile=$SOURCEDIR/$filepath

        # Check if it's currently symlinked to our dotfiles
        if [ "$oldfile" -ef "$newfile" ] 2>/dev/null; then
            rm -f "$oldfile"
            printf "${GREEN}removed${NC}"
        elif [ -L "$oldfile" ]; then
            printf "${YELLOW}symlink exists but points elsewhere${NC}"
        elif [ -e "$oldfile" ]; then
            printf "${YELLOW}exists but not a symlink${NC}"
        else
            printf "not installed"
        fi
    done < "$CONFIGFILE"

    printf "\n\n${GREEN}Uninstallation complete!${NC}\n"
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

        printf "  %-50s " "$filepath"

        if [ ! -e "$newfile" ]; then
            printf "${RED}✗ source missing${NC}\n"
            all_ok=false
        elif [ "$oldfile" -ef "$newfile" ] 2>/dev/null; then
            printf "${GREEN}✓ installed${NC}\n"
        elif [ -L "$oldfile" ]; then
            printf "${YELLOW}⚠ wrong symlink${NC}\n"
            all_ok=false
        elif [ -e "$oldfile" ]; then
            printf "${YELLOW}⚠ file exists${NC}\n"
            all_ok=false
        else
            printf "${RED}✗ not installed${NC}\n"
            all_ok=false
        fi
    done < "$CONFIGFILE"

    printf "\n"
    if $all_ok; then
        printf "${GREEN}All dotfiles are correctly installed!${NC}\n"
        exit 0
    else
        printf "${YELLOW}Some dotfiles need attention.${NC}\n"
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
        echo "Usage: $0 {install|uninstall|status|restore}"
        exit 1
        ;;
esac
