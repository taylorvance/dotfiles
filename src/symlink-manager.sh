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
    # -P preserves symlinks as symlinks: the backup mirrors what was actually
    # in $HOME, and copying can't fail on dangling links the way -L did
    cp -PR "$source_path" "$BACKUPDIR/$relative_path"
}

# Make sure the parent of $1 is a directory, backing up and removing any
# non-directory ancestor (e.g. ~/.config exists as a file but the config
# wants ~/.config/foo/bar). Walks the whole chain, not just the immediate
# parent.
ensure_parent_dirs() {
    local target_parent="$1"
    local path="$target_parent"
    local chain=()
    local component

    while [ -n "$path" ] && [ "$path" != "$DESTINATIONDIR" ] && [ "$path" != "/" ]; do
        chain=("$path" "${chain[@]}")
        path="$(dirname "$path")"
    done

    for component in "${chain[@]}"; do
        if path_exists "$component" && [ ! -d "$component" ]; then
            backup_path "$component" "${component#"$DESTINATIONDIR"/}"
            rm -rf "$component"
            break # nothing deeper can exist below a non-directory
        fi
    done

    mkdir -p "$target_parent"
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

    local filepath oldfile newfile
    while IFS= read -r filepath || [ -n "$filepath" ]; do
        is_skipped_config_line "$filepath" && continue

        filepath="$(normalize_config_path "$filepath")"

        oldfile=$DESTINATIONDIR/$filepath
        newfile=$SOURCEDIR/$filepath

        # If the file is already correctly symlinked, skip.
        if [ "$oldfile" -ef "$newfile" ] 2>/dev/null; then
            printf "  ${DIM}✓${NC} %s\n" "$filepath"
            continue
        fi

        # If a file with this name already exists, it will be backed up
        if path_exists "$oldfile"; then
            if [ "$DRY_RUN" = true ]; then
                printf "  ${YELLOW}→${NC} %s (would backup existing & link)\n" "$filepath"
            else
                backup_path "$oldfile" "$filepath"
                rm -rf "$oldfile"
            fi
        else
            if [ "$DRY_RUN" = true ]; then
                printf "  ${BLUE}+${NC} %s (would create link)\n" "$filepath"
            fi
        fi

        if [ "$DRY_RUN" = false ]; then
            ensure_parent_dirs "$(dirname "$oldfile")"
            ln -s "$newfile" "$oldfile"
            printf "  ${GREEN}✓${NC} %s\n" "$filepath"
        fi
    done < "$CONFIGFILE"

    if [ "$DRY_RUN" = true ]; then
        printf "\n${BLUE}[DRY RUN]${NC} No changes made. Run without -n to apply.\n"
    else
        printf "\n${GREEN}All dotfiles linked${NC}\n"
    fi
}

uninstall_dotfiles() {
    if [ "$DRY_RUN" = true ]; then
        printf "${BLUE}[DRY RUN]${NC} Preview of changes:\n\n"
    else
        printf "Unlinking dotfiles...\n\n"
    fi

    local filepath oldfile newfile
    local removed=0 skipped=0
    while IFS= read -r filepath || [ -n "$filepath" ]; do
        is_skipped_config_line "$filepath" && continue

        filepath="$(normalize_config_path "$filepath")"

        oldfile=$DESTINATIONDIR/$filepath
        newfile=$SOURCEDIR/$filepath

        # Check if it's currently symlinked to our dotfiles
        if [ "$oldfile" -ef "$newfile" ] 2>/dev/null && [ -L "$oldfile" ]; then
            if [ "$DRY_RUN" = true ]; then
                printf "  ${YELLOW}→${NC} %s (would unlink)\n" "$filepath"
            else
                rm -f "$oldfile"
                printf "  ${GREEN}✓${NC} %s\n" "$filepath"
            fi
            removed=$((removed + 1))
        elif [ -L "$oldfile" ]; then
            printf "  ${YELLOW}⚠${NC} %s (skipped: symlink points elsewhere)\n" "$filepath"
            skipped=$((skipped + 1))
        elif [ -e "$oldfile" ]; then
            printf "  ${YELLOW}⚠${NC} %s (skipped: not a symlink)\n" "$filepath"
            skipped=$((skipped + 1))
        else
            printf "  ${YELLOW}⚠${NC} %s (skipped: not found)\n" "$filepath"
            skipped=$((skipped + 1))
        fi
    done < "$CONFIGFILE"

    printf "\n"
    if [ "$DRY_RUN" = true ]; then
        printf "${BLUE}[DRY RUN]${NC} No changes made. Run without -n to apply.\n"
    else
        printf "${GREEN}%d unlinked${NC}, %d skipped\n" "$removed" "$skipped"
    fi
}

show_status() {
    printf "Dotfiles status:\n\n"

    local filepath oldfile newfile
    local all_ok=true

    while IFS= read -r filepath || [ -n "$filepath" ]; do
        is_skipped_config_line "$filepath" && continue

        filepath="$(normalize_config_path "$filepath")"

        oldfile=$DESTINATIONDIR/$filepath
        newfile=$SOURCEDIR/$filepath

        if ! path_exists "$newfile"; then
            printf "  ${RED}✗${NC} %s (source missing)\n" "$filepath"
            all_ok=false
        elif [ "$oldfile" -ef "$newfile" ] 2>/dev/null; then
            printf "  ${GREEN}✓${NC} %s\n" "$filepath"
        elif [ -L "$oldfile" ]; then
            printf "  ${YELLOW}⚠${NC} %s (symlink points elsewhere)\n" "$filepath"
            all_ok=false
        elif [ -e "$oldfile" ]; then
            printf "  ${YELLOW}⚠${NC} %s (exists but is not a symlink)\n" "$filepath"
            all_ok=false
        else
            printf "  ${RED}✗${NC} %s (not linked)\n" "$filepath"
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
    local backup
    while IFS= read -r backup; do
        backups+=("$backup")
        printf "  [%d] %s\n" "${#backups[@]}" "$(basename "$backup")"
    done < <(find "$BACKUPSDIR" -mindepth 1 -maxdepth 1 -type d | sort -r)

    printf "\nRestored files replace whatever is at their path in \$HOME,\n"
    printf "including symlinks created by 'make link'.\n"

    printf "\nEnter backup number to restore (or 0 to cancel): "
    local choice
    if ! read -r choice; then
        echo "Cancelled."
        exit 0
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
        echo "Invalid choice."
        exit 1
    fi

    if [ "$choice" -eq 0 ]; then
        echo "Cancelled."
        exit 0
    fi

    if [ "$choice" -lt 1 ] || [ "$choice" -gt "${#backups[@]}" ]; then
        echo "Invalid choice."
        exit 1
    fi

    local backup_dir="${backups[$((choice-1))]}"

    if [ "$DRY_RUN" = true ]; then
        printf "\n${BLUE}[DRY RUN]${NC} Would restore from %s:\n\n" "$(basename "$backup_dir")"
    else
        printf "\nRestoring from %s...\n\n" "$(basename "$backup_dir")"
    fi

    # Recreate directory structure first
    local entry rel dest
    if [ "$DRY_RUN" = false ]; then
        while IFS= read -r entry; do
            rel="${entry#./}"
            [ "$rel" = "." ] && continue
            mkdir -p "$DESTINATIONDIR/$rel"
        done < <(cd "$backup_dir" && find . -type d)
    fi

    # Copy entry-by-entry so our own symlinks can be removed first; a plain
    # recursive cp would write *through* an existing symlink and overwrite
    # the repo's source files instead of restoring the original.
    local restored=0
    while IFS= read -r entry; do
        rel="${entry#./}"
        if [ "$DRY_RUN" = true ]; then
            printf "  ${YELLOW}→${NC} ~/%s (would restore)\n" "$rel"
            restored=$((restored + 1))
            continue
        fi
        dest="$DESTINATIONDIR/$rel"
        if [ -L "$dest" ]; then
            rm -f "$dest"
        fi
        cp -PR "$backup_dir/$rel" "$dest"
        printf "  ${GREEN}✓${NC} ~/%s\n" "$rel"
        restored=$((restored + 1))
    done < <(cd "$backup_dir" && find . \( -type f -o -type l \))

    printf "\n"
    if [ "$DRY_RUN" = true ]; then
        printf "${BLUE}[DRY RUN]${NC} No changes made. Run without -n to apply.\n"
    else
        printf "${GREEN}Restore complete!${NC} %d file(s) restored.\n" "$restored"
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
