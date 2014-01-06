#!/bin/zsh

# file copy(symbolic)
FILE_NAMES=( ".vimrc" ".vimrc.command" ".vimrc.office" ".zshrc" ".gitconfig" )
for file in ${FILE_NAMES[@]}
	ln -s $HOME/config_file/$file $HOME/$file

# change default shell (->zsh)
chsh -s /bin/zsh
