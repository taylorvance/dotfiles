#!/usr/bin/env bash
# Validate dotfiles repo wiring without touching $HOME.

set -u

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
SOURCEDIR="$BASEDIR/src/dotfiles"
CONFIGFILE="$BASEDIR/config"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0
INFO=0

CONFIG_PATHS=()

path_exists() {
	[ -e "$1" ] || [ -L "$1" ]
}

error() {
	printf "${RED}✗${NC} %s\n" "$1"
	ERRORS=$((ERRORS + 1))
}

warn() {
	printf "${YELLOW}⚠${NC} %s\n" "$1"
	WARNINGS=$((WARNINGS + 1))
}

info() {
	printf "${BLUE}i${NC} %s\n" "$1"
	INFO=$((INFO + 1))
}

ok() {
	printf "${GREEN}✓${NC} %s\n" "$1"
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
		error "config contains an empty path after normalization"
		return 1
	fi

	case "$filepath" in
		/*)
			error "config path must be relative to \$HOME: $filepath"
			return 1
			;;
		~|~/*)
			error "config path must not use ~ expansion: $filepath"
			return 1
			;;
		.|..|../*|*/..|*/../*|./*|*/./*|*/.|*//*)
			error "config path contains unsafe or ambiguous path components: $filepath"
			return 1
			;;
	esac

	if [[ "$filepath" =~ ^[[:space:]] ]] || [[ "$filepath" =~ [[:space:]]$ ]]; then
		error "config path has leading or trailing whitespace: $filepath"
		return 1
	fi

	return 0
}

config_path_seen() {
	local needle="$1"
	local path
	[ "${#CONFIG_PATHS[@]}" -eq 0 ] && return 1
	for path in "${CONFIG_PATHS[@]}"; do
		[ "$path" = "$needle" ] && return 0
	done
	return 1
}

source_is_configured_or_covered() {
	local source_path="$1"
	local config_path
	[ "${#CONFIG_PATHS[@]}" -eq 0 ] && return 1
	for config_path in "${CONFIG_PATHS[@]}"; do
		if [ "$source_path" = "$config_path" ]; then
			return 0
		fi
		if [ -d "$SOURCEDIR/$config_path" ] && [[ "$source_path" == "$config_path/"* ]]; then
			return 0
		fi
	done
	return 1
}

check_required_files() {
	printf "\n${BLUE}Repository wiring${NC}\n"

	if [ -d "$SOURCEDIR" ]; then
		ok "source directory exists: src/dotfiles"
	else
		error "source directory missing: src/dotfiles"
	fi

	if [ -f "$CONFIGFILE" ]; then
		ok "config file exists"
	else
		error "config file missing"
	fi
}

check_config() {
	printf "\n${BLUE}Config entries${NC}\n"

	[ -f "$CONFIGFILE" ] || return
	[ -d "$SOURCEDIR" ] || return

	local had_entries=false
	local line filepath source

	while IFS= read -r line || [ -n "$line" ]; do
		is_skipped_config_line "$line" && continue
		had_entries=true

		filepath="$(normalize_config_path "$line")"
		validate_relative_path "$filepath" || continue

		if config_path_seen "$filepath"; then
			error "duplicate config entry: $filepath"
			continue
		fi
		CONFIG_PATHS+=("$filepath")

		source="$SOURCEDIR/$filepath"
		if path_exists "$source"; then
			ok "$filepath"
		else
			error "configured source is missing: $filepath"
		fi
	done < "$CONFIGFILE"

	if [ "$had_entries" = false ]; then
		warn "config has no active entries"
	fi
}

check_unconfigured_sources() {
	printf "\n${BLUE}Unconfigured source files${NC}\n"

	[ -d "$SOURCEDIR" ] || return

	local found=false
	local rel
	while IFS= read -r rel; do
		source_is_configured_or_covered "$rel" && continue
		info "$rel is present in src/dotfiles but not linked by config"
		found=true
	done < <(cd "$SOURCEDIR" && find . -type f | sed 's#^\./##' | sort)

	[ "$found" = true ] || ok "all source files are configured or covered by a configured directory"
}

check_executable_bits() {
	printf "\n${BLUE}Executable bits${NC}\n"

	local file
	for file in "$BASEDIR"/src/*.sh "$SOURCEDIR"/.local/bin/* "$BASEDIR"/tests/test-runner.sh "$BASEDIR"/.githooks/*; do
		[ -f "$file" ] || continue
		if [ -x "$file" ]; then
			ok "${file#"$BASEDIR"/}"
		else
			error "script is not executable: ${file#"$BASEDIR"/}"
		fi
	done
}

check_one_syntax() {
	local checker="$1" file="$2"
	if "$checker" -n "$file" 2>/dev/null; then
		ok "$checker -n ${file#"$BASEDIR"/}"
	else
		error "$checker syntax check failed: ${file#"$BASEDIR"/}"
	fi
}

check_shell_syntax() {
	printf "\n${BLUE}Shell syntax${NC}\n"

	local file shebang

	for file in "$BASEDIR"/src/*.sh "$BASEDIR"/tests/test-runner.sh "$BASEDIR"/.githooks/*; do
		[ -f "$file" ] || continue
		check_one_syntax bash "$file"
	done

	# Extensionless bin scripts: pick the checker from the shebang so new
	# scripts are covered automatically
	for file in "$SOURCEDIR"/.local/bin/*; do
		[ -f "$file" ] || continue
		shebang=$(head -n1 "$file")
		case "$shebang" in
			'#!'*bash*)           check_one_syntax bash "$file" ;;
			'#!'*zsh*)            : ;; # handled with the zsh section below
			'#!'*/sh*|'#!'*' sh'*) check_one_syntax sh "$file" ;;
			*)          warn "no recognizable shebang, syntax not checked: ${file#"$BASEDIR"/}" ;;
		esac
	done

	if command -v zsh >/dev/null 2>&1; then
		for file in "$SOURCEDIR"/.zshrc "$SOURCEDIR"/.zsh/functions.zsh; do
			[ -f "$file" ] || continue
			check_one_syntax zsh "$file"
		done
	else
		info "zsh not installed; skipped zsh syntax checks"
	fi
}

main() {
	printf "${BLUE}Dotfiles doctor${NC}\n"

	check_required_files
	check_config
	check_unconfigured_sources
	check_executable_bits
	check_shell_syntax

	printf "\n"
	if [ "$ERRORS" -gt 0 ]; then
		printf "${RED}Doctor found %d error(s), %d warning(s), %d info item(s).${NC}\n" "$ERRORS" "$WARNINGS" "$INFO"
		exit 1
	fi

	if [ "$WARNINGS" -gt 0 ]; then
		printf "${YELLOW}Doctor passed with %d warning(s) and %d info item(s).${NC}\n" "$WARNINGS" "$INFO"
	else
		printf "${GREEN}Doctor passed with %d info item(s).${NC}\n" "$INFO"
	fi
}

main "$@"
