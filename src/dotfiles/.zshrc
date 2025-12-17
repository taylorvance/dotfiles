# Taylor Vance


# Use Homebrew before system default.
export PATH=/opt/homebrew/bin:$PATH

# Fix for less v633+ treating Nerd Font icons (private-use Unicode) as non-printable
# See: https://github.com/sharkdp/bat/issues/2578
export LESSUTFCHARDEF=E000-F8FF:p,F0000-FFFFD:p,100000-10FFFD:p
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
# command duration (shown if >= CMD_DURATION_THRESHOLD seconds)
CMD_DURATION_THRESHOLD=2
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
	local interactive=(vim nvim e man less bat r lt top htop btop claude)

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
		if [ $duration -ge $CMD_DURATION_THRESHOLD ]; then
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

# Load custom wrapper functions (tmp, proj, raw)
source $HOME/.zsh/functions.zsh

alias python='python3'
#poetry completions zsh > ~/.zfunc/_poetry
#fpath+=~/.zfunc

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
# See also: lt() in ~/.zsh/functions.zsh
if command -v eza >/dev/null 2>&1; then
	alias ls='eza --icons=always --group-directories-first --color=always'
	alias ll='eza -l --icons=always --group-directories-first --git --color=always'
	alias la='eza -la --icons=always --group-directories-first --git --color=always'
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


# Command not found handler (suggest packages)
if [[ -f /opt/homebrew/Library/Taps/homebrew/homebrew-command-not-found/handler.sh ]]; then
	source /opt/homebrew/Library/Taps/homebrew/homebrew-command-not-found/handler.sh
fi

# Load local customizations if they exist
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
