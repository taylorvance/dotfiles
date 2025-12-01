# Taylor Vance


# Use Homebrew before system default.
export PATH=/opt/homebrew/bin:$PATH
#export PATH=/usr/local/bin:$PATH
export PATH=/opt/homebrew/opt/python@3.12/libexec/bin:$PATH
# Custom scripts
export PATH=$HOME/.local/bin:$PATH

# Auto-install Antigen
if [[ ! -f $HOME/.zsh/antigen.zsh ]]; then
	mkdir -p $HOME/.zsh
	curl -L git.io/antigen > $HOME/.zsh/antigen.zsh
fi

# Load antigen within ~/.zsh/
ADOTDIR=$HOME/.zsh/antigen
source $HOME/.zsh/antigen.zsh

# Set oh-my-zsh as the default library
antigen use oh-my-zsh

# Load oh-my-zsh plugins
#antigen bundle vi-mode

# Load other plugins
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle mfaerevaag/wd

antigen apply


# Use vi keys
bindkey -v
# Lower latency (for switching modes etc)
export KEYTIMEOUT=10

# Filter command history
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search
bindkey -M vicmd k up-line-or-beginning-search
bindkey -M vicmd j down-line-or-beginning-search

# Fix for undeletable text - https://github.com/denysdovhan/spaceship-prompt/issues/91
bindkey "^?" backward-delete-char
# Enable forward delete - https://stackoverflow.com/a/41885766/1718474
bindkey "^[[3~" delete-char

# Use jk or kj to exit INSERT (as with my .vimrc)
bindkey -M viins 'jk' vi-cmd-mode
bindkey -M viins 'kj' vi-cmd-mode

# Terminal history search
bindkey -M viins '^r' history-incremental-search-backward
bindkey -M vicmd '^r' history-incremental-search-backward

# CUSTOM THEME

# NORMAL or INSERT mode
function vi_prompt_info {
	echo "${${KEYMAP/vicmd/$ZSH_THEME_VI_PROMPT_NORMAL}/(main|viins)/$ZSH_THEME_VI_PROMPT_INSERT}"
}

# hostname or nickname (set this up in ~/.zprofile)
function hostnickname {
	echo "$([ -z "$HOSTNICKNAME" ] && echo "$(hostname)" || echo "$HOSTNICKNAME")"
}

# Left prompt
PROMPT=''
# user@host
PROMPT+='%F{blue}[%f%F{magenta}%n%f%F{blue}@%f%F{magenta}$(hostnickname)%f%F{blue}]%f'
# ~/path/from/home
PROMPT+='%F{blue} [%f%F{cyan}%~%f%F{blue}]%f'
# git branch
ZSH_THEME_GIT_PROMPT_PREFIX=" %F{blue}[%f%F{magenta}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%f%F{blue}]%f"
ZSH_THEME_GIT_PROMPT_DIRTY="*"
PROMPT+='$(git_prompt_info)'
# vi mode
ZSH_THEME_VI_PROMPT_INSERT=""
ZSH_THEME_VI_PROMPT_NORMAL=" %B%F{cyan}-- NORMAL --%f%b"
PROMPT+='$(vi_prompt_info)'
# command duration
PROMPT+='$ZSH_THEME_PROMPT_DURATION'
# newline and down-right line thing
PROMPT+=$'\n'
PROMPT+='%F{blue}└─%f'
# green or red % prompt (red shows last exit code)
PROMPT+=' %(?.%F{green}%#%f.%F{red}%# [%?]%f) '

# Secondary prompt arrow
PROMPT2='   %F{cyan}>%f '

# Right prompt
#RPROMPT=''
# green √ or red X (last cmd's status)
#RPROMPT+='%B%(?.%F{green}√%f.%F{red}X%f)%b'
# timestamp of previous command
#RPROMPT+=' $ZSH_THEME_PROMPT_CMD_TIME'

# Reset prompt when switching modes
function zle-line-init zle-keymap-select {
	zle reset-prompt
	zle -R
}
zle -N zle-line-init
zle -N zle-keymap-select

# Before executing a command, store start time for duration calculation
preexec() {
	local cmd="$1"
	local interactive=(vim nvim e man less bat r top htop btop claude)

	# Get first command (or command after sudo)
	local first="${cmd%% *}"
	[[ "$first" == "sudo" ]] && first="${${cmd#sudo }%% *}"

	# Skip if first cmd or anything after a pipe is interactive
	for prog in $interactive; do
		[[ "$first" == "$prog" ]] && return
		# Glob pattern: append space to cmd so "| prog" at end becomes "| prog "
		[[ "$cmd " == *"| $prog "* || "$cmd " == *"|$prog "* ]] && return
	done

	# Git pagers
	[[ "$cmd" =~ ^git\ (diff|di|log|lg|show) ]] && return
	# Package managers with prompts
	[[ "$cmd" =~ ^sudo\ (apt|dnf|yum|pacman)\ install ]] && return

	ZSH_THEME_PROMPT_CMD_START=$SECONDS
}

# After command completes, calculate duration
precmd() {
	if [ -n "$ZSH_THEME_PROMPT_CMD_START" ]; then
		local duration=$((SECONDS - ZSH_THEME_PROMPT_CMD_START))
		if [ $duration -ge 1 ]; then
			ZSH_THEME_PROMPT_DURATION=" %F{yellow}[${duration}s]%f"
		else
			ZSH_THEME_PROMPT_DURATION=""
		fi
		unset ZSH_THEME_PROMPT_CMD_START
	else
		ZSH_THEME_PROMPT_DURATION=""
	fi
}


# MISC

# `r` for "read" - smart pager that handles both files and piped colored output
# bat config sets theme and options via ~/.config/bat/config
if command -v bat >/dev/null; then
	# Auto-download bat themes if missing (self-healing setup)
	if [ ! -f "$HOME/.config/bat/themes/tokyonight_moon.tmTheme" ]; then
		mkdir -p "$HOME/.config/bat/themes"
		if command -v curl >/dev/null; then
			curl -fsSL -o "$HOME/.config/bat/themes/tokyonight_moon.tmTheme" \
				"https://raw.githubusercontent.com/folke/tokyonight.nvim/main/extras/sublime/tokyonight_moon.tmTheme" >/dev/null 2>&1 && \
				bat cache --build >/dev/null 2>&1
		fi
	fi
	alias r='bat'
	export PAGER=bat
else
	alias r='less'
fi
# `e` for "edit" has a more sophisticated implementation in ~/.local/bin/e

# `tmp` (see ~/.local/bin/tmp) wrapper function to properly cd into temp directory
tmp() {
	local output
	output=$($HOME/.local/bin/tmp "$@")
	if [ $? -eq 0 ]; then
		# Extract the cd command and eval it
		local cd_cmd=$(echo "$output" | grep '^cd ' | tail -n 1)
		if [ -n "$cd_cmd" ]; then
			eval "$cd_cmd"
			# Show any other output (excluding the cd command)
			echo "$output" | grep -v '^cd '
		else
			# No cd command, just show output (like -l flag)
			echo "$output"
		fi
	else
		echo "$output"
	fi
}

alias python='python3'
#poetry completions zsh > ~/.zfunc/_poetry
#fpath+=~/.zfunc

# Show hidden files and ignore common directories
# alias tree2='tree -a -I "node_modules|__pycache__|*.pyc|*.pyo|*.pyd|*.egg-info|*.egg|*.git|*.DS_Store|*.venv|*.env|obj|bin|lib|include|share|var|tmp|temp|cache|log|logs|backup|backups|build|dist"'

# Use nvim as default editor
export EDITOR=nvim
export VISUAL=nvim


# These lines were added by serverless framework setup (I opted for tab completion).
# tabtab source for packages
# uninstall by removing these lines
[[ -f ~/.config/tabtab/__tabtab.zsh ]] && . ~/.config/tabtab/__tabtab.zsh || true

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_DEFAULT_OPTS='--multi'


# NVM install
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# Initialize completion system (must be after all fpath modifications)
# Force rebuild of completion cache
autoload -Uz compinit && compinit -i


# MODERN CLI TOOLS

# zoxide - smarter cd that learns your habits
# Usage: z <partial-path>  (e.g., "z dot" jumps to ~/dotfiles)
if command -v zoxide >/dev/null 2>&1; then
	eval "$(zoxide init zsh)"
fi

# eza - modern ls replacement (with fallback to regular ls)
if command -v eza >/dev/null 2>&1; then
	alias ls='eza --icons=always --group-directories-first --color=always'
	alias ll='eza -l --icons=always --group-directories-first --git --color=always'
	alias la='eza -la --icons=always --group-directories-first --git --color=always'
	# lt - tree view with configurable depth (defaults to full depth)
	# Usage: lt [level] [path]
	#   lt        → unlimited depth (default)
	#   lt 3      → level 3
	#   lt 3 dir  → level 3 for specific directory
	lt() {
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
			eza --tree --all --icons=always --group-directories-first --git-ignore --color=always --ignore-glob="$ignore_patterns" "$@"
		else
			eza --tree --all --icons=always --group-directories-first --git-ignore --color=always --level=$level --ignore-glob="$ignore_patterns" "$@"
		fi
	}
else
	# Fallback to regular ls with some useful flags
	alias ll='ls -lh'
	alias la='ls -lAh'
fi

# fd - modern find replacement (keep original find available)
if command -v fd >/dev/null 2>&1; then
	# Don't alias 'find' to avoid breaking scripts, provide 'f' shortcut instead
	alias f='fd'
fi

# ripgrep - add convenient alias if installed
if command -v rg >/dev/null 2>&1; then
	alias rg='rg --smart-case --hidden --glob "!.git/*"'
fi

# atuin - magical shell history
if command -v atuin >/dev/null 2>&1; then
	eval "$(atuin init zsh --disable-up-arrow)"
	# Note: Use Ctrl-r for atuin search, up-arrow still does prefix search
fi


# USEFUL SHELL FUNCTIONS

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


# Load local customizations if they exist
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
