#!/bin/bash
# TODO add node ubuntu repo and npm -g install instant-markdown-d

set -e

exists() {
  if command -v $1 >/dev/null 2>&1
  then
    return 0
  else
    return 1
  fi
}

repohome=$( dirname $(readlink -f "${BASH_SOURCE[0]}") )
cd ${repohome}
git submodule update --init --recursive

# When running in Vagrant we need to get the right home path, and sudo does not
# expose this envvar automatically
if [ -n $SUDO_USER  ]; then
  export HOME=$(bash <<< "echo ~$SUDO_USER")
fi

# [bin]
 mkdir -p $HOME/local/bin
 ln -sf ${repohome}/bin/vimdirdiff.sh $HOME/local/bin/vimdirdiff.sh
 ln -sf ${repohome}/bin/rupa_v/v $HOME/local/bin/v
 ln -sf ${repohome}/bin/bd $HOME/local/bin/bd

# [Bash]
 ln -sf ${repohome}/bash/_bash_aliases $HOME/.bash_aliases
 ln -sf ${repohome}/bash/_bash_extras $HOME/.bash_extras
 ln -sf ${repohome}/bash/_inputrc $HOME/.inputrc
 ln -sf ${repohome}/bash/_git.scmbrc $HOME/.git.scmbrc

# [zsh]
 ln -sfT ${repohome}/zsh/oh-my-zsh $HOME/.oh-my-zsh
 ln -sf ${repohome}/zsh/_zshrc $HOME/.zshrc

# [autojump]
 cd ${repohome}/bin/autojump
# hardcoded installation to $HOME/.autojump
 ./install.sh --local > /dev/null

# [hub]
 cd ${repohome}
 if [[ ! -f $HOME/local/bin/hub ]]; then
   cd vendor/hub
   rake install prefix=$HOME/local
   cd ${repohome}
 fi

# [composer]
 if ! exists composer; then
   curl -sS https://getcomposer.org/installer | php
   mv composer.phar $HOME/local/bin/composer
 fi
 # php's psysh https://github.com/bobthecow/psysh
 if [ ! -d $HOME/.psysh ]; then
   mkdir $HOME/.psysh
 fi
 if [ ! -f $HOME/.psysh/php_manual.sqlite ]; then
   curl -sS http://psysh.org/manual/en/php_manual.sqlite > $HOME/.psysh/php_manual.sqlite
 fi

# [vim]
 ln -sf ${repohome}/vim/vimrc $HOME/.vimrc
 ln -sfT ${repohome}/vim/dotvim $HOME/.vim
 [[ ! -d $HOME/Documents/git_repos/spf13_PIV ]] && git clone git@github.com:spf13/PIV.git $HOME/Documents/git_repos/spf13_PIV

# [git]
 ln -sf ${repohome}/git/_gitconfig $HOME/.gitconfig
 ln -sf ${repohome}/git/_global_gitignore $HOME/.global_gitignore
 ln -sf ${repohome}/git/_gitk $HOME/.gitk

# [tmux]
 ln -sf ${repohome}/tmux/_tmux.conf $HOME/.tmux.conf

# [drush]
 ln -sf ${repohome}/bash/_drush_bashrc $HOME/.drush_bashrc

# [ruby]
 ln -sf ${repohome}/ruby/_irbrc.rb $HOME/.irbrc
 ln -sf ${repohome}/ruby/_pryrc.rb $HOME/.pryrc
 ln -sf ${repohome}/ruby/_gemrc $HOME/.gemrc

# [dconf]
if exists dconf && [ -n "$DISPLAY" ]; then
  cat ${repohome}/dconf/_org_gnome_libgnomekbd_keyboard | dconf load /org/gnome/libgnomekbd/keyboard/
fi

# [gconf]
 mkdir -p $HOME/.fonts
 ln -sf ${repohome}/_fonts/SourceCodePro-Semibold-Powerline.otf $HOME/.fonts/
if exists gconftool-2; then
  # gconftool-2 --dump '/apps/gnome-terminal' > gconf/gnome-terminal_gconf_settings.xml
  gconftool-2 --load ${repohome}/gconf/gnome-terminal_gconf_settings.xml
  # gconftool-2 --dump '/desktop/gnome/keybindings/hamster-applet' > gconf/hamster-shortcut.xml
  gconftool-2 --load ${repohome}/gconf/hamster-shortcut.xml
  # gconftool-2 --dump '/apps/hamster-indicator' > gconf/hamster-settings.xml
  gconftool-2 --load ${repohome}/gconf/hamster-settings.xml
fi

# [ssh]
 mkdir -p $HOME/.ssh
 chmod 700 $HOME/.ssh
 ln -sf private/ssh ${repohome}

# [pianobar]
 ln -sfT ../private/_config/pianobar ${repohome}/_config/pianobar

# [drush]
 mkdir -p $HOME/.drush
 ln -sf private/drush ${repohome}

# [X]
 # xproperties, old stuff
 ln -sf ${repohome}/X/_Xdefaults $HOME/.Xdefaults
 # ubuntu lightdm does not consider $HOME/.xsession{,rc} nor $HOME/.xinitrc
 #ln -sf ${repohome}/X/_xinitrc $HOME/.xinitrc
 ln -sf ${repohome}/X/_xbindkeysrc  $HOME/.xbindkeysrc
 # xmodmap, switch a couple of keys, for laptop dv7-6190sl, disabled by default
 ln -sf ${repohome}/X/_Xmodmap $HOME/.Xmodmap
 # what to autostart in X
 [[ ! -d $HOME/.config/autostart ]] && mkdir -p $HOME/.config/autostart
 ln -sf ${repohome}/_config/autostart/xrdb.desktop $HOME/.config/autostart/xrdb.desktop
 ln -sf ${repohome}/_config/autostart/dropbox.desktop $HOME/.config/autostart/dropbox.desktop
 ln -sf ${repohome}/_config/autostart/hamster-indicator.desktop $HOME/.config/autostart/hamster-indicator.desktop
 ln -sf ${repohome}/_config/autostart/indicator-multiload.desktop $HOME/.config/autostart/indicator-multiload.desktop

# [Gnome]
 #mkdir -p $HOME/.config/gtk-3.0
 #ln -sf ${repohome}/_config/gtk-3.0/gtk.css $HOME/.config/gtk-3.0/gtk.css

# [mysql]
 ln -sf ${repohome}/mysql/_my.cnf $HOME/.my.cnf

# [ikiwiki]
 ln -sf private/ikiwiki ${repohome}

# [vimperator]
 ln -sf ${repohome}/vimperator/_vimperatorrc $HOME/.vimperatorrc
 mkdir -p $HOME/.vimperator/
 ln -sfT ${repohome}/vimperator/plugin $HOME/.vimperator/plugin

# [gnupg]
 ln -sf private/gnupg ${repohome}

# [lftp]
 ln -sf private/lftp ${repohome}

# [drush]
 ln -sf ${repohome}/bin/drush/drush $HOME/local/bin/drush

# [alsa]
 ln -sf ${repohome}/alsa/_asoundrc $HOME/.asoundrc

# [rtorrent]
 ln -sf private/rtorrent ${repohome}

# [ctags]
 ln -sf ${repohome}/ctags/_ctags $HOME/.ctags

# [mercurial]
 ln -sf  ${repohome}/mercurial/_hgrc $HOME/.hgrc

# [alsa]
 ln -sf ${repohome}/alsa/_asoundrc $HOME/.asoundrc

# [rtorrent]
 ln -sf private/rtorrent ${repohome}

# [libao]
 ln -sf ${repohome}/libao/_libao $HOME/.libao

# [mplayer]
 mkdir -p $HOME/.mplayer
 ln -sf ${repohome}/mplayer/config $HOME/.mplayer/config

# [private]
${repohome}/private/install.sh
echo "dotfiles installed"

# NOTES:
# The old vimperator stuff has been removed but can be found in the git history, see commit after 8b619de
