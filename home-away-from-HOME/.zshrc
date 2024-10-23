# Taylor Vance


# Use Homebrew before system default.
export PATH=/usr/local/bin:$PATH

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
# newline and down-right line thing
PROMPT+=$'\n'
PROMPT+='%F{blue}└─%f'
# green or red % prompt
PROMPT+=' %(?.%F{green}%#%f.%F{red}%#%f) '

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

# Before executing a command, store these variables for the prompt
ZSH_THEME_PROMPT_CMD_TIME=$(date +"%H:%M:%S")
preexec () {
	ZSH_THEME_PROMPT_CMD_TIME=$(date +"%H:%M:%S")
}


# MISC
alias python='python3'
export PATH="/Users/taylorvance/.local/bin:$PATH"
#poetry completions zsh > ~/.zfunc/_poetry
#fpath+=~/.zfunc
#autoload -Uz compinit && compinit


# These lines were added by serverless framework setup (I opted for tab completion).
# tabtab source for packages
# uninstall by removing these lines
[[ -f ~/.config/tabtab/__tabtab.zsh ]] && . ~/.config/tabtab/__tabtab.zsh || true

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_DEFAULT_OPTS='--multi'
