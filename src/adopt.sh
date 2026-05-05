#!/usr/bin/env bash
# Adopt existing files from $HOME into src/dotfiles and config.

set -e

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
DESTINATIONDIR=$HOME
SOURCEDIR=$BASEDIR/src/dotfiles
CONFIGFILE=$BASEDIR/config

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
	cat <<EOF
Usage: $0 PATH [PATH...]

Copy existing PATH(s) from \$HOME into src/dotfiles, add them to config,
and preview the link operation. PATH may be relative to \$HOME, ~/..., or
an absolute path under \$HOME.

Examples:
  $0 .config/tool/config.toml
  $0 ~/.gitconfig
  make adopt F=.config/tool/config.toml
EOF
}

die() {
	echo "Error: $1" >&2
	exit 1
}

path_exists() {
	[ -e "$1" ] || [ -L "$1" ]
}

normalize_home_path() {
	local input="$1"
	local rel

	case "$input" in
		~)
			rel=""
			;;
		~/*)
			rel="${input#~/}"
			;;
		"$DESTINATIONDIR")
			rel=""
			;;
		"$DESTINATIONDIR"/*)
			rel="${input#"$DESTINATIONDIR"/}"
			;;
		/*)
			die "path is outside \$HOME: $input"
			;;
		*)
			rel="$input"
			;;
	esac

	rel="${rel%/}"
	printf '%s\n' "$rel"
}

validate_relative_path() {
	local filepath="$1"

	if [ -z "$filepath" ]; then
		die "refusing to adopt \$HOME itself"
	fi

	case "$filepath" in
		/*|~|~/*)
			die "path must be relative to \$HOME after normalization: $filepath"
			;;
		.|..|../*|*/..|*/../*|./*|*/./*|*/.|*//*)
			die "path contains unsafe or ambiguous components: $filepath"
			;;
	esac

	if [[ "$filepath" =~ ^[[:space:]] ]] || [[ "$filepath" =~ [[:space:]]$ ]]; then
		die "path has leading or trailing whitespace: $filepath"
	fi
}

config_has_entry() {
	local filepath="$1"
	[ -f "$CONFIGFILE" ] || return 1
	grep -Fx -- "$filepath" "$CONFIGFILE" >/dev/null 2>&1
}

adopt_one() {
	local input="$1"
	local filepath home_path source_path

	filepath="$(normalize_home_path "$input")"
	validate_relative_path "$filepath"

	home_path="$DESTINATIONDIR/$filepath"
	source_path="$SOURCEDIR/$filepath"

	if ! path_exists "$home_path"; then
		die "home path does not exist: ~/$filepath"
	fi

	if [ -L "$home_path" ]; then
		die "refusing to adopt symlink: ~/$filepath"
	fi

	if path_exists "$source_path"; then
		die "source already exists: src/dotfiles/$filepath"
	fi

	mkdir -p "$(dirname "$source_path")"
	cp -pR "$home_path" "$source_path"
	printf "  ${GREEN}✓${NC} copied ~/%s -> src/dotfiles/%s\n" "$filepath" "$filepath"

	if config_has_entry "$filepath"; then
		printf "  ${YELLOW}⚠${NC} config already contains %s\n" "$filepath"
	else
		printf '%s\n' "$filepath" >> "$CONFIGFILE"
		printf "  ${GREEN}✓${NC} added %s to config\n" "$filepath"
	fi
}

main() {
	if [ "$#" -eq 0 ]; then
		usage
		exit 1
	fi

	case "$1" in
		-h|--help)
			usage
			exit 0
			;;
	esac

	printf "${BLUE}Adopting dotfiles...${NC}\n\n"
	for path in "$@"; do
		adopt_one "$path"
	done

	printf "\n${BLUE}Link preview:${NC}\n"
	"$BASEDIR/src/symlink-manager.sh" --dry-run install
}

main "$@"
