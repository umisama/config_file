#!/bin/zsh

# file copy(symbolic)
FILE_NAMES=( ".vimrc" ".vimrc.command" ".vimrc.office" ".zshrc_myconfigs" ".gitconfig" )
for file in ${FILE_NAMES[@]}
	ln -s $HOME/config_file/$file $HOME/$file

mkdir ~/.vim_backup
mkdir ~/.vim_swap

# oh my zsh
sh -c "$(wget https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"
echo "source .zshrc_myconfigs" >> ~/.zshrc

# change default shell (->zsh)
chsh -s /bin/zsh
