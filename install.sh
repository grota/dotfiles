#!/bin/bash

repohome=$( dirname $(readlink -f "${BASH_SOURCE[0]}") )
cd ${repohome}
git submodule update --init --recursive

# [bin]
 mkdir -p ~/local/bin
 ln -sf ${repohome}/bin/vimdirdiff.sh ~/local/bin/vimdirdiff.sh
 ln -sf ${repohome}/bin/rupa_v/v ~/local/bin/v
 ln -sf ${repohome}/bin/bd ~/local/bin/bd

# [Bash]
 ln -sf ${repohome}/bash/_bash_aliases ~/.bash_aliases
 ln -sf ${repohome}/bash/_bash_extras ~/.bash_extras
 ln -sf ${repohome}/bash/_inputrc ~/.inputrc
 ln -sf ${repohome}/bash/_git.scmbrc ~/.git.scmbrc

# [zsh]
 ln -sfT ${repohome}/zsh/oh-my-zsh ~/.oh-my-zsh
 ln -sf ${repohome}/zsh/_zshrc ~/.zshrc

# [autojump]
 cd ${repohome}/bin/autojump
 ./install.sh  --local > /dev/null

# [phpbuild]
 cd ${repohome}/bin/php-build/
 # bugfix of php-build
 mkdir -p $HOME/local/share/man/man1
 mkdir -p $HOME/local/share/man/man5
 PREFIX=$HOME/local ./install.sh > /dev/null

# [hub]
 cd ${repohome}
 [[ ! -f ~/local/bin/hub ]] && curl http://defunkt.io/hub/standalone -sLo ~/local/bin/hub && chmod +x ~/local/bin/hub

# [vim]
 ln -sf ${repohome}/vim/vimrc ~/.vimrc
 ln -sfT ${repohome}/vim/dotvim ~/.vim

# [git]
 ln -sf ${repohome}/git/_gitconfig ~/.gitconfig
 ln -sf ${repohome}/git/_global_gitignore ~/.global_gitignore
 ln -sf ${repohome}/git/_gitk ~/.gitk

# [tmux]
 ln -sf ${repohome}/tmux/_tmux.conf ~/.tmux.conf

# [drush]
 ln -sf ${repohome}/bash/_drush_bashrc ~/.drush_bashrc

# [ruby]
 ln -sf ${repohome}/ruby/_irbrc.rb ~/.irbrc
 ln -sf ${repohome}/ruby/_pryrc.rb ~/.pryrc
 ln -sf ${repohome}/ruby/_gemrc ~/.gemrc

# [dconf]
 cat ${repohome}/dconf/_org_gnome_libgnomekbd_keyboard | dconf load /org/gnome/libgnomekbd/keyboard/

# [gconf]
 # gconftool-2 --dump '/apps/gnome-terminal' > gconf/gnome-terminal_gconf_settings.xml
 gconftool-2 --load ${repohome}/gconf/gnome-terminal_gconf_settings.xml
 # gconftool-2 --dump '/desktop/gnome/keybindings/hamster-applet' > gconf/hamster-shortcut.xml
 gconftool-2 --load ${repohome}/gconf/hamster-shortcut.xml
 # gconftool-2 --dump '/apps/hamster-indicator' > gconf/hamster-settings.xml
 gconftool-2 --load ${repohome}/gconf/hamster-settings.xml

# [ssh]
 mkdir -p ~/.ssh
 chmod 700 ~/.ssh
 ln -sf private/ssh ${repohome}

# [pianobar]
 ln -sf ../private/_config/pianobar ${repohome}/_config/

# [drush]
 mkdir -p ~/.drush
 ln -sf private/drush ${repohome}

# [xmodmap]
# conf for laptop dv7-6190sl
 ln -sf ${repohome}/xmodmap/_Xmodmap ~/.Xmodmap

# [X]
 ln -sf ${repohome}/X/_Xdefaults ~/.Xdefaults
 # ubuntu lightdm does not consider ~/.xsession{,rc} nor ~/.xinitrc
 #ln -sf ${repohome}/X/_xinitrc ~/.xinitrc
 ln -sf ${repohome}/_config/autostart/xrdb.desktop ~/.config/autostart/xrdb.desktop
 ln -sf ${repohome}/_config/autostart/dropbox.desktop ~/.config/autostart/dropbox.desktop
 ln -sf ${repohome}/_config/autostart/hamster-indicator.desktop ~/.config/autostart/hamster-indicator.desktop
 ln -sf ${repohome}/_config/autostart/indicator-multiload.desktop ~/.config/autostart/indicator-multiload.desktop

# [Gnome]
 #mkdir -p $HOME/.config/gtk-3.0
 #ln -sf ${repohome}/_config/gtk-3.0/gtk.css ~/.config/gtk-3.0/gtk.css

# [mysql]
 ln -sf ${repohome}/mysql/_my.cnf ~/.my.cnf

# [ikiwiki]
 ln -sf private/ikiwiki ${repohome}

# [vimperator]
 ln -sf ${repohome}/vimperator/_vimperatorrc ~/.vimperatorrc
 mkdir -p ~/.vimperator/
 ln -sfT ${repohome}/vimperator/plugin ~/.vimperator/plugin

# [gnupg]
 ln -sf private/gnupg ${repohome}

# [lftp]
 ln -sf private/lftp ${repohome}

# [drush]
 ln -sf ${repohome}/bin/drush/drush ~/local/bin/drush

# [alsa]
 ln -sf ${repohome}/alsa/_asoundrc ~/.asoundrc

# [rtorrent]
 ln -sf private/rtorrent ${repohome}

# [ctags]
 ln -sf ${repohome}/ctags/_ctags ~/.ctags

# [mercurial]
 ln -sf  ${repohome}/mercurial/_hgrc ~/.hgrc

# [alsa]
 ln -sf ${repohome}/alsa/_asoundrc ~/.asoundrc

# [rtorrent]
 ln -sf private/rtorrent ${repohome}

# [libao]
 ln -sf ${repohome}/libao/_libao ~/.libao

# [mplayer]
 mkdir -p ~/.mplayer
 ln -sf ${repohome}/mplayer/config ~/.mplayer/config

# [private]
${repohome}/private/install.sh
