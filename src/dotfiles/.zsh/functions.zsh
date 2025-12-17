# Shell functions
# Sourced by .zshrc

# -----------------------------------------------------------------------------
# Script wrappers (need parent shell to modify state)
# -----------------------------------------------------------------------------

# tmp - wrapper to handle cd and editor invocation
tmp() {
	local output
	output=$($HOME/.local/bin/tmp "$@")
	local exit_code=$?

	if [ $exit_code -eq 0 ]; then
		# Extract the cd command and eval it
		local cd_cmd=$(echo "$output" | grep '^cd ' | tail -n 1)
		if [ -n "$cd_cmd" ]; then
			eval "$cd_cmd"

			# Check if editor should be opened (-e flag)
			local editor_line=$(echo "$output" | grep '^EDITOR_CMD:')
			if [ -n "$editor_line" ]; then
				# Extract filename after colon
				local filename="${editor_line#EDITOR_CMD:}"
				${EDITOR:-nvim} "$filename"
			fi

			# Show any other output (excluding cd and EDITOR_CMD)
			echo "$output" | grep -v '^cd ' | grep -v '^EDITOR_CMD:'
		else
			# No cd command, just show output (like -d flag)
			echo "$output"
		fi
	else
		echo "$output"
		return $exit_code
	fi
}

# proj - wrapper to handle cd in detach mode
proj() {
	# If in detach mode (-d), capture the cd command and eval it
	if [[ "$*" == *"-d"* ]] || [[ "$*" == *"--detach"* ]]; then
		local output=$($HOME/.local/bin/proj "$@")
		if [ $? -eq 0 ] && [[ "$output" == cd\ * ]]; then
			eval "$output"
		else
			echo "$output"
		fi
	else
		# Otherwise, just run the script (tmux handles the context)
		$HOME/.local/bin/proj "$@"
	fi
}

# -----------------------------------------------------------------------------
# Utility functions
# -----------------------------------------------------------------------------

# raw - bypass shell aliases/functions
raw() {
	command "$@"
}

# mkcd - create directory and cd into it
mkcd() {
	mkdir -p "$1" && cd "$1"
}

# extract - extract any archive type
extract() {
	if [ -f "$1" ]; then
		case "$1" in
			*.tar.bz2)   tar xjf "$1"     ;;
			*.tar.gz)    tar xzf "$1"     ;;
			*.bz2)       bunzip2 "$1"     ;;
			*.rar)       unrar e "$1"     ;;
			*.gz)        gunzip "$1"      ;;
			*.tar)       tar xf "$1"      ;;
			*.tbz2)      tar xjf "$1"     ;;
			*.tgz)       tar xzf "$1"     ;;
			*.zip)       unzip "$1"       ;;
			*.Z)         uncompress "$1"  ;;
			*.7z)        7z x "$1"        ;;
			*)     echo "'$1' cannot be extracted via extract()" ;;
		esac
	else
		echo "'$1' is not a valid file"
	fi
}

# backup - quick backup of a file
backup() {
	cp "$1" "$1.backup-$(date +%Y%m%d-%H%M%S)"
}

# fcd - cd to a directory using fzf (requires fd and fzf)
fcd() {
	if ! command -v fd >/dev/null 2>&1 || ! command -v fzf >/dev/null 2>&1; then
		echo "fcd requires 'fd' and 'fzf' to be installed" >&2
		return 1
	fi

	local dir
	local preview_cmd
	if command -v eza >/dev/null 2>&1; then
		preview_cmd='eza --tree --level=1 --icons {}'
	else
		preview_cmd='ls -la {}'
	fi

	dir=$(fd --type d --hidden --exclude .git | fzf --preview "$preview_cmd")
	if [ -n "$dir" ]; then
		cd "$dir"
	fi
}

# lt - tree view with configurable depth (requires eza)
# Usage: lt [level] [path]
#   lt        → unlimited depth
#   lt 3      → level 3
#   lt 3 dir  → level 3 for specific directory
lt() {
	if ! command -v eza >/dev/null 2>&1; then
		echo "lt requires 'eza' to be installed" >&2
		return 1
	fi

	local level=0
	# If first arg is a digit, use it as level
	if [[ "$1" =~ ^[0-9]+$ ]]; then
		level=$1
		shift
	fi

	# Ignore common directories and build artifacts
	local ignore_patterns='node_modules|__pycache__|*.pyc|*.pyo|*.pyd|*.egg-info|*.egg|.git|.DS_Store|.venv|.env|build|dist|target|.pytest_cache|.mypy_cache|vendor|.next|.nuxt|*.swp|*.swo'

	# level=0 means unlimited (omit the --level flag)
	if [[ $level -eq 0 ]]; then
		eza --tree --all --icons=always --group-directories-first --git-ignore --color=always --ignore-glob="$ignore_patterns" "$@" | r
	else
		eza --tree --all --icons=always --group-directories-first --git-ignore --color=always --level=$level --ignore-glob="$ignore_patterns" "$@" | r
	fi
}
