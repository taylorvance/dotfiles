# If antigen doesn't exist, download it.
if [[ ! -f $HOME/.zsh/antigen.zsh ]]
then
	mkdir -p $HOME/.zsh
	curl -L git.io/antigen > $HOME/.zsh/antigen.zsh
fi

ADOTDIR=$HOME/.zsh/antigen
source $HOME/.zsh/antigen.zsh

antigen use oh-my-zsh

antigen theme gentoo

antigen bundle zsh-users/zsh-syntax-highlighting

antigen apply
