#!/bin/bash

repohome=$( dirname $(readlink -f "${BASH_SOURCE[0]}") )
cd ${repohome}
git submodule update --init --recursive

# [bin]
 mkdir -p ~/local/bin
 ln -sf ${repohome}/bin/git-diffall/git-diffall ~/local/bin/git-diffall
 ln -sf ${repohome}/bin/vimdirdiff.sh ~/local/bin/vimdirdiff.sh
 ln -sf ${repohome}/bin/git-archive-all/git-archive-all.sh ~/local/bin/git-archive-all.sh
 ln -sf ${repohome}/bin/rupa_v/v ~/local/bin/v

 cd ${repohome}/bin/autojump
 ./install.sh  --local --prefix ~/local/ > /dev/null

 cd ${repohome}/bin/php-build/
 # bugfix of php-build
 mkdir -p $HOME/local/share/man/man1
 mkdir -p $HOME/local/share/man/man5
 PREFIX=$HOME/local ./install.sh > /dev/null

 cd ${repohome}
 [[ ! -f ~/local/bin/hub ]] && curl http://defunkt.io/hub/standalone -sLo ~/local/bin/hub && chmod +x ~/local/bin/hub

# [Bash]
 ln -sf ${repohome}/bash/_bash_aliases ~/.bash_aliases
 ln -sf ${repohome}/bash/_bash_extras ~/.bash_extras
 ln -sf ${repohome}/bash/_inputrc ~/.inputrc
 ln -sf ${repohome}/bash/_git.scmbrc ~/.git.scmbrc

# [vim]
 ln -sf ${repohome}/vim/vimrc ~/.vimrc
 ln -sfT ${repohome}/vim/dotvim ~/.vim

# [git]
 ln -sf ${repohome}/git/_gitconfig ~/.gitconfig
 ln -sf ${repohome}/git/_global_gitignore ~/.global_gitignore
 ln -sf ${repohome}/git/_gitk ~/.gitk

# [tmux]
 ln -sf ${repohome}/tmux/_tmux.conf ~/.tmux.conf

# [dconf]
 cat ${repohome}/dconf/_org_gnome_libgnomekbd_keyboard | dconf load /org/gnome/libgnomekbd/keyboard/

# [gconf]
 # gconftool-2 --dump '/apps/gnome-terminal' > gconf/gnome-terminal_gconf_settings.xml
 gconftool-2 --load ${repohome}/gconf/gnome-terminal_gconf_settings.xml

# [ssh]
 mkdir -p ~/.ssh
 chmod 700 ~/.ssh
 ln -sf private/ssh ${repohome}

# [gnupg]
 ln -sf private/gnupg ${repohome}

# [pianobar]
 ln -sf ../private/_config/pianobar ${repohome}/_config/

# [drush]
 mkdir -p ~/.drush
 ln -sf private/drush ${repohome}

# [mysql]
 ln -sf ${repohome}/mysql/_my.cnf ~/.my.cnf

# [ikiwiki]
 ln -sf private/ikiwiki ${repohome}

# [lftp]
 ln -sf private/lftp ${repohome}

# [alsa]
 ln -sf ${repohome}/alsa/_asoundrc ~/.asoundrc

# [rtorrent]
 ln -sf private/rtorrent ${repohome}

# [ctags]
 ln -sf ${repohome}/ctags/_ctags ~/.ctags

# [mercurial]
 ln -sf  ${repohome}/mercurial/_hgrc ~/.hgrc

# [xmodmap]
# conf for laptop dv7-6190sl
 ln -sf ${repohome}/xmodmap/_Xmodmap ~/.Xmodmap

# [X]
 ln -sf ${repohome}/X/_Xdefaults ~/.Xdefaults
 ln -sf ${repohome}./X/_xinitrc ~/.xinitrc

${repohome}/private/install.sh
