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

			# Open any requested files in the editor (one EDITOR_CMD line each)
			local editor_files=() editor_line
			while IFS= read -r editor_line; do
				editor_files+=("${editor_line#EDITOR_CMD:}")
			done < <(echo "$output" | grep '^EDITOR_CMD:')
			if [ ${#editor_files[@]} -gt 0 ]; then
				${EDITOR:-nvim} "${editor_files[@]}"
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

# backup - timestamped copy of a file, saved next to the original
# Usage: backup FILE  (prints the backup path)
backup() {
	if [ $# -ne 1 ]; then
		echo "Usage: backup FILE" >&2
		return 2
	fi
	if [ ! -e "$1" ]; then
		echo "backup: no such file: $1" >&2
		return 1
	fi
	if [ -d "$1" ]; then
		echo "backup: $1 is a directory; backup handles single files" >&2
		return 1
	fi

	local dest="$1.backup-$(date +%Y%m%d-%H%M%S)"
	if [ -e "$dest" ]; then
		echo "backup: $dest already exists" >&2
		return 1
	fi

	# Deliberately no -R/-P: a deployed dotfile is usually a symlink into this
	# repo, and its backup has to capture the content, not a link that follows
	# every later edit.
	cp -p -- "$1" "$dest" && echo "$dest"
}

# ytaudio - download a video or playlist as high-quality M4A audio
ytaudio() {
	if ! command -v yt-dlp >/dev/null 2>&1 || ! command -v ffmpeg >/dev/null 2>&1; then
		echo "ytaudio requires yt-dlp and ffmpeg. Install them with your package manager (for example: brew install yt-dlp ffmpeg)." >&2
		return 127
	fi

	command yt-dlp -x --audio-format m4a --audio-quality 0 --embed-metadata --embed-thumbnail \
		--parse-metadata '%(playlist_title)s:%(album)s' \
		--parse-metadata '%(playlist_index)s/%(playlist_count)s:%(track_number)s' \
		-o '%(playlist_index&{} - |)s%(title)s [%(id)s].%(ext)s' "$@"
}

# ytvideo - download a video or playlist as MP4
ytvideo() {
	if ! command -v yt-dlp >/dev/null 2>&1 || ! command -v ffmpeg >/dev/null 2>&1; then
		echo "ytvideo requires yt-dlp and ffmpeg. Install them with your package manager (for example: brew install yt-dlp ffmpeg)." >&2
		return 127
	fi

	command yt-dlp -f 'bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/b' --merge-output-format mp4 --embed-metadata --embed-thumbnail "$@"
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
# Usage: lt [-a] [level] [path]
#   lt           → unlimited depth, respects .gitignore
#   lt -a        → show gitignored files (e.g., build output)
#   lt 3         → level 3
#   lt -a 2 dir  → level 2, show gitignored, specific directory
lt() {
	if ! command -v eza >/dev/null 2>&1; then
		echo "lt requires 'eza' to be installed" >&2
		return 1
	fi

	local level=0
	local use_gitignore=true

	# Parse flags
	while [[ "$1" == -* ]]; do
		case "$1" in
			-a) use_gitignore=false; shift ;;
			*) break ;;
		esac
	done

	# If first arg is a digit, use it as level
	if [[ "$1" =~ ^[0-9]+$ ]]; then
		level=$1
		shift
	fi

	# Ignore dependency/install artifacts and caches (always hidden - use eza directly to see these)
	local ignore_patterns='node_modules|vendor|.venv|__pycache__|*.pyc|*.pyo|*.pyd|*.egg-info|.git|.DS_Store|Thumbs.db|.cache|.pytest_cache|.mypy_cache|.next|.nuxt|*.swp|*.swo|*~'

	local git_flag=""
	[[ "$use_gitignore" == true ]] && git_flag="--git-ignore"

	# level=0 means unlimited (omit the --level flag)
	# Page via $PAGER rather than the `r` alias: aliases only expand here if
	# this file is sourced after they're defined, which is easy to break.
	# --icons/--color must stay `always` (unlike the ls aliases): eza sees a
	# pipe to the pager as non-TTY and would strip them under `auto`
	if [[ $level -eq 0 ]]; then
		eza --tree --all --icons=always --group-directories-first $git_flag --color=always --ignore-glob="$ignore_patterns" "$@" | ${PAGER:-less}
	else
		eza --tree --all --icons=always --group-directories-first $git_flag --color=always --level=$level --ignore-glob="$ignore_patterns" "$@" | ${PAGER:-less}
	fi
}

# lsrepos - list all cloned git repos under a directory
# Usage: lsrepos [dir]  (defaults to current directory)
lsrepos() {
	local dir="${1:-$PWD}"
	local configs=()
	while IFS= read -r gitdir; do
		[[ -f "$gitdir/config" ]] && configs+=("$gitdir/config")
	done < <(find "$dir" -maxdepth 5 \( -name "node_modules" -o -name ".venv" -o -name "venv" -o -name "__pycache__" \) -prune -o -name ".git" -type d -prune -print 2>/dev/null)
	[[ ${#configs[@]} -eq 0 ]] && return
	awk -v base="${dir%/}/" '
	/url = / {
		url = $3
		gh = ""
		if (url ~ /github\.com/) {
			gh = url
			gsub(/^git@github\.com:|^https:\/\/[^@]*github\.com\//, "", gh)
			gsub(/\.git$/, "", gh)
		}
		path = FILENAME
		sub(/\/config$/, "", path)
		sub(/\/.git$/, "", path)
		sub(base, "", path)
		n++; paths[n]=path; ghs[n]=gh; urls[n]=url
		if (length(path) > w1) w1 = length(path)
		if (length(gh)   > w2) w2 = length(gh)
	}
	END {
		for (i=1; i<=n; i++)
			printf "%-*s  %-*s  %s\n", w1, paths[i], w2, ghs[i], urls[i]
	}
	' "${configs[@]}"
}

# gw - cd to a git worktree
# Usage: gw         → cd to main worktree (repo root)
#        gw <query> → cd to worktree matching query
#        gw -l      → fzf picker to browse all worktrees
gw() {
	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		echo "Not in a git repository" >&2
		return 1
	fi

	local dir

	if [[ "$1" == "-l" ]]; then
		if ! command -v fzf >/dev/null 2>&1; then
			git worktree list
			return 0
		fi
		dir=$(git worktree list | fzf --height=40% | awk '{print $1}')
	elif [[ -n "$1" ]]; then
		dir=$(git worktree list | awk -v q="$1" '$0 ~ q {print $1; exit}')
		if [[ -z "$dir" ]]; then
			echo "No worktree matching '$1'" >&2
			git worktree list >&2
			return 1
		fi
	else
		# No args: go to main worktree (first listed)
		dir=$(git worktree list | head -1 | awk '{print $1}')
	fi

	if [[ -n "$dir" ]]; then
		cd "$dir"
	fi
}
