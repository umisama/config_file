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

# nodejs
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.29.0/install.sh | bash

# Ruby version manager
gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
curl -sSL https://get.rvm.io | bash -s stable --ruby


# change default shell (->zsh)
chsh -s /bin/zsh
