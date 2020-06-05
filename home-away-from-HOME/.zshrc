# If antigen doesn't exist, download it.
if [[ ! -f $HOME/.zsh/antigen.zsh ]]
then
	mkdir -p $HOME/.zsh
	curl -L git.io/antigen > $HOME/.zsh/antigen.zsh
fi

ADOTDIR=$HOME/.zsh/antigen
source $HOME/.zsh/antigen.zsh

antigen use oh-my-zsh

antigen bundle zsh-users/zsh-syntax-highlighting

antigen apply

ZSH_THEME_GIT_PROMPT_PREFIX="%F{blue}[%f%F{magenta}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%f%F{blue}]%f"
ZSH_THEME_GIT_PROMPT_DIRTY="%F{red}*%f"

# blue brackets. cyan and magenta text. format: [user@host] [~/path/from/home] [git info]
# green or red % prompt
PROMPT='%F{blue}[%f%F{magenta}%n%f%F{blue}@%f%F{magenta}%m%f%F{blue}]%f %F{blue}[%f%F{cyan}%~%f%F{blue}]%f $(git_prompt_info)
%F{blue}└─%f%(?.%F{green}.%F{red}) %#%f '
# green √ or red X. current time.
RPROMPT='%B%(?.%F{green}√%f.%F{red}X%f)%b %*'
