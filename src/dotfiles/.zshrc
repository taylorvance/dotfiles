# Taylor Vance


# Homebrew prefix: Apple Silicon = /opt/homebrew, Intel = /usr/local, Linux = /home/linuxbrew/.linuxbrew
if [[ -x /opt/homebrew/bin/brew ]]; then
	HOMEBREW_PREFIX=/opt/homebrew
elif [[ -x /usr/local/bin/brew ]]; then
	HOMEBREW_PREFIX=/usr/local
elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
	HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew
fi

# Use Homebrew before system default.
[[ -n $HOMEBREW_PREFIX ]] && export PATH=$HOMEBREW_PREFIX/bin:$PATH

# Fix for less v633+ treating Nerd Font icons (private-use Unicode) as non-printable
# See: https://github.com/sharkdp/bat/issues/2578
export LESSUTFCHARDEF=E000-F8FF:p,F0000-FFFFD:p,100000-10FFFD:p
# Custom scripts
export PATH=$HOME/.local/bin:$PATH

# Load antigen (installed via `brew install antigen`)
# Falls back to ~/.zsh/antigen.zsh for non-Homebrew setups
ADOTDIR=$HOME/.zsh/antigen
ANTIGEN_MUTEX=false  # Disable file locking (prevents hangs if a prior session left a lock)
if [[ -n $HOMEBREW_PREFIX && -f $HOMEBREW_PREFIX/share/antigen/antigen.zsh ]]; then
	source $HOMEBREW_PREFIX/share/antigen/antigen.zsh
elif [[ -f $HOME/.zsh/antigen.zsh ]]; then
	source $HOME/.zsh/antigen.zsh
fi

# Only configure plugins if antigen loaded successfully
if typeset -f antigen >/dev/null 2>&1; then
	# Set oh-my-zsh as the default library
	antigen use oh-my-zsh

	# Load oh-my-zsh plugins
	#antigen bundle vi-mode

	# Load other plugins
	antigen bundle zsh-users/zsh-syntax-highlighting
	antigen bundle zsh-users/zsh-autosuggestions
	antigen bundle mfaerevaag/wd

	antigen apply
fi


# History (oh-my-zsh sets similar values; explicit so they hold without antigen)
HISTFILE=$HOME/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt INC_APPEND_HISTORY HIST_IGNORE_DUPS

# Use vi keys
bindkey -v
# Lower latency (for switching modes etc)
export KEYTIMEOUT=10

# Filter command history
# These widgets ship with zsh but aren't registered by default (oh-my-zsh does
# it; do it ourselves so arrow keys still work without antigen)
autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
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

# Starship prompt (config in ~/.config/starship.toml)
if command -v starship >/dev/null 2>&1; then
	eval "$(starship init zsh)"
fi


# MISC

# `r` for "read" - smart pager that handles both files and piped colored output
# bat config sets theme and options via ~/.config/bat/config
if command -v bat >/dev/null; then
	alias r='bat'
	export PAGER=bat
else
	alias r='less'
fi
# `e` for "edit" has a more sophisticated implementation in ~/.local/bin/e

# Load custom shell functions (tmp wrapper, mkcd, extract, fcd, lt, gw, ...)
source $HOME/.zsh/functions.zsh

alias python='python3'
#poetry completions zsh > ~/.zfunc/_poetry
#fpath+=~/.zfunc

alias ytaudio='yt-dlp -x --audio-format m4a --audio-quality 0 --embed-metadata --embed-thumbnail --parse-metadata "%(playlist_title)s:%(album)s" --parse-metadata "%(playlist_index)s/%(playlist_count)s:%(track_number)s" -o "%(playlist_index&{} - |)s%(title)s [%(id)s].%(ext)s"'
alias ytvideo='yt-dlp -f "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/b" --merge-output-format mp4 --embed-metadata --embed-thumbnail'

# Use nvim as default editor
export EDITOR=nvim
export VISUAL=nvim


# These lines were added by serverless framework setup (I opted for tab completion).
# tabtab source for packages
# uninstall by removing these lines
[[ -f ~/.config/tabtab/__tabtab.zsh ]] && . ~/.config/tabtab/__tabtab.zsh || true

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_DEFAULT_OPTS='--multi'


# Runtime versions (node, ...) via mise — global defaults in
# ~/.config/mise/config.toml; auto-switches per project from
# .nvmrc/.node-version/mise.toml on cd
if command -v mise >/dev/null 2>&1; then
	eval "$(mise activate zsh)"
elif [[ -s "$HOME/.nvm/nvm.sh" ]]; then
	# Fallback: plain nvm (slow to load; install mise for fast startup)
	export NVM_DIR="$HOME/.nvm"
	source "$NVM_DIR/nvm.sh"
elif [[ -n $HOMEBREW_PREFIX && -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ]]; then
	export NVM_DIR="$HOME/.nvm"
	source "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"
fi

# Initialize completion system (must be after all fpath modifications)
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
if [[ -n $HOMEBREW_PREFIX && -f $HOMEBREW_PREFIX/Library/Taps/homebrew/homebrew-command-not-found/handler.sh ]]; then
	source $HOMEBREW_PREFIX/Library/Taps/homebrew/homebrew-command-not-found/handler.sh
fi

# Load local customizations if they exist
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
