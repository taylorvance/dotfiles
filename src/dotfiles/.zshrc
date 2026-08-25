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

# Plugins are vendored as commit-pinned git submodules in the dotfiles repo
# (symlinked to ~/.zsh/plugins). Upgrade via `make bump-plugins` there.
# wd - named directory bookmarks (`wd add foo`, `wd foo`)
if [[ -f $HOME/.zsh/plugins/wd/wd.plugin.zsh ]]; then
	source $HOME/.zsh/plugins/wd/wd.plugin.zsh
fi
# zsh-autosuggestions and zsh-syntax-highlighting are sourced at the END of
# this file - syntax-highlighting must load after all custom widgets exist.


# History
HISTFILE=$HOME/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt INC_APPEND_HISTORY HIST_IGNORE_DUPS

# Use vi keys
bindkey -v
# Lower latency (for switching modes etc)
export KEYTIMEOUT=10

# Filter command history
# These widgets ship with zsh but aren't registered by default
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

# Load custom shell functions (tmp wrapper, mkcd, fcd, lt, gw, ...)
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

zstyle ':completion:*' menu select                        # arrow-key completion menu
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' # case-insensitive matching
setopt interactive_comments                               # allow # comments at the prompt
setopt auto_cd                                            # a bare dir path cd's to it


# MODERN CLI TOOLS

# zoxide - smarter cd that learns your habits
# Usage: z <partial-path>  (e.g., "z dot" jumps to ~/dotfiles)
if command -v zoxide >/dev/null 2>&1; then
	eval "$(zoxide init zsh)"
fi

# eza - modern ls replacement (with fallback to regular ls)
# See also: lt() in ~/.zsh/functions.zsh
if command -v eza >/dev/null 2>&1; then
	alias ls='eza --icons=auto --group-directories-first'
	alias l='eza -la --icons=auto --group-directories-first --git'
else
	# Fallback to regular ls with some useful flags
	alias l='ls -lAh'
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

# Vendored plugins that must load late: syntax-highlighting only decorates
# widgets that already exist when it is sourced, so it stays at the bottom
if [[ -f $HOME/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
	source $HOME/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
if [[ -f $HOME/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
	source $HOME/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Load local customizations if they exist
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
