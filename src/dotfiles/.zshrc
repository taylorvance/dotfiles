# Taylor Vance


# Use Homebrew before system default.
export PATH=/opt/homebrew/bin:$PATH

# Fix for less v633+ treating Nerd Font icons (private-use Unicode) as non-printable
# See: https://github.com/sharkdp/bat/issues/2578
export LESSUTFCHARDEF=E000-F8FF:p,F0000-FFFFD:p,100000-10FFFD:p
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

# Starship prompt (config in ~/.config/starship.toml)
if command -v starship >/dev/null 2>&1; then
	eval "$(starship init zsh)"
fi


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

alias ytaudio='yt-dlp -x --audio-format mp3 --audio-quality 0 --embed-metadata --embed-thumbnail'
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


# NVM install (supports both standard install and Homebrew)
export NVM_DIR="$HOME/.nvm"
# Standard nvm install location
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
# Homebrew nvm location (macOS)
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"

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
