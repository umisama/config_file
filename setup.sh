#!/bin/zsh

sudo apt-get install -y byobu zsh vim-gnome make gcc

# file copy(symbolic)
FILE_NAMES=( ".vimrc" ".vimrc.command" ".vimrc.office" ".zshrc_myconfigs" ".gitconfig" )
for file in ${FILE_NAMES[@]}
	ln -s $HOME/config_file/$file $HOME/$file

# install NeoBundle for vim
curl https://raw.githubusercontent.com/Shougo/neobundle.vim/master/bin/install.sh > install.sh
sh install.sh
rm install.sh

# oh my zsh
sh -c "$(wget https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"
echo "source .zshrc_myconfigs" >> ~/.zshrc

# change default shell (->zsh)
chsh -s /bin/zsh
