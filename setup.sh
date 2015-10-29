#!/bin/zsh

sudo apt-get install -y byobu zsh gvim

# file copy(symbolic)
FILE_NAMES=( ".vimrc" ".vimrc.command" ".vimrc.office" ".zshrc" ".gitconfig" )
for file in ${FILE_NAMES[@]}
	ln -s $HOME/config_file/$file $HOME/$file

# install neobundle
git clone https://github.com/Shougo/neobundle.vim.git $HOME/.vim/bundle

# change default shell (->zsh)
chsh -s /bin/zsh
