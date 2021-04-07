#!/bin/bash

set -euo pipefail

exists() {
  if command -v "$1" >/dev/null 2>&1
  then
    return 0
  else
    return 1
  fi
}

repohome=$( dirname "$(readlink -f "${BASH_SOURCE[0]}")" )
cd "${repohome}"
git submodule update --init --recursive

# [bin]
 mkdir -p "$HOME"/local/bin
 curl -s https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy -o ~/local/bin/diff-so-fancy
 cp /usr/share/doc/git/contrib/diff-highlight/diff-highlight ~/local/bin/
 ln -s "${repohome}"/vim/dotvim/plugged/phpactor/bin/phpactor ~/local/bin/

# [Bash]
 ln -sf "${repohome}"/bash/_bash_aliases "$HOME"/.bash_aliases
 ln -sf "${repohome}"/bash/_inputrc "$HOME"/.inputrc
 ln -sf "${repohome}"/bash/_git.scmbrc "$HOME"/.git.scmbrc
 if [[ ! -f "${repohome}"/bash/completions/docker-compose ]]; then
   curl https://raw.githubusercontent.com/docker/compose/master/contrib/completion/bash/docker-compose -o "${repohome}"/bash/completions/docker-compose
 fi

# [kitty]
 ln -sfT "${repohome}"/kitty "$HOME"/.config/kitty

 ln -sfT "${repohome}"/sxiv "$HOME"/.config/sxiv

# [cheat] https://github.com/chrisallenlane/cheat
 ln -sfT "${repohome}"/cheat "$HOME"/.cheat

# [composer]
 if ! exists composer; then
   curl -sS https://getcomposer.org/installer | php
   mv composer.phar "$HOME"/local/bin/composer
 fi
 # php's psysh https://github.com/bobthecow/psysh
 if [ ! -d "$HOME"/.psysh ]; then
   mkdir "$HOME"/.psysh
 fi
 if [ ! -f "$HOME"/.psysh/php_manual.sqlite ]; then
   curl -sS http://psysh.org/manual/en/php_manual.sqlite > "$HOME"/.psysh/php_manual.sqlite
 fi

# [vim]
 ln -sfT "${repohome}"/vim/dotvim "$HOME"/.vim
 [[ ! -d "$HOME"/Documents/git_repos/spf13_PIV ]] && git clone git@github.com:spf13/PIV.git "$HOME"/Documents/git_repos/spf13_PIV

# [git]
 ln -sf "${repohome}"/git/_gitconfig "$HOME"/.gitconfig
 ln -sf "${repohome}"/git/_global_gitignore "$HOME"/.global_gitignore
 ln -sf "${repohome}"/git/_gitk "$HOME"/.gitk

# [tmux]
 ln -sf "${repohome}"/tmux/_tmux.conf "$HOME"/.tmux.conf
 ln -sfT "${repohome}"/tmux "$HOME"/.tmux
 ln -sfT ../private/tmux/tmuxinator "${repohome}"/tmux/tmuxinator

# [dconf]
#if exists dconf && [ -n "$DISPLAY" ]; then
#  dconf load /org/gnome/libgnomekbd/keyboard/ < "${repohome}"/dconf/_org_gnome_libgnomekbd_keyboard
#  dconf load /org/gnome/desktop/wm/keybindings/ < "${repohome}"/dconf/org_gnome_desktop_wm_keybindings.dconf
#  # dconf dump /org/gnome/settings-daemon/plugins/media-keys/ > dconf/dconf_gnome_settings_daemon_keys.dconf
#  dconf load /org/gnome/settings-daemon/plugins/media-keys/ < "${repohome}"/dconf/dconf_gnome_settings_daemon_keys.dconf
#fi
# gsettings set com.canonical.desktop.interface scrollbar-mode normal

 if [ ! -d "$HOME"/.fonts ]; then
   mkdir -p "$HOME"/.fonts
 fi
# Outdated, use https://github.com/ryanoasis/nerd-fonts
 #if [ ! -f "$HOME"/.fonts/Sauce\ Code\ Powerline\ Semibold.otf ]; then
   #curl https://raw.githubusercontent.com/powerline/fonts/master/SourceCodePro/Sauce%20Code%20Powerline%20Semibold.otf -o "$HOME"/.fonts/Sauce\ Code\ Powerline\ Semibold.otf
 #fi

# [gconf]
#if exists gconftool-2; then
#  gconftool-2 --load "${repohome}"/gconf/gnome-terminal_gconf_settings.xml
#fi

# [ssh]
 mkdir -p "$HOME"/.ssh
 chmod 700 "$HOME"/.ssh
 ln -sf private/ssh "${repohome}"

# [X]
 # what to autostart in X
 [[ ! -d "$HOME"/.config/autostart ]] && mkdir -p "$HOME"/.config/autostart
 ln -sf "${repohome}"/_config/autostart/xinitrc.desktop "$HOME"/.config/autostart/xinitrc.desktop
 ln -sf "${repohome}"/_config/autostart/xrdb.desktop "$HOME"/.config/autostart/xrdb.desktop
 ln -sf "${repohome}"/_config/autostart/dropbox.desktop "$HOME"/.config/autostart/dropbox.desktop
 ln -sf "${repohome}"/_config/autostart/indicator-multiload.desktop "$HOME"/.config/autostart/indicator-multiload.desktop
 ln -sf "${repohome}"/_config/autostart/shutter.desktop "$HOME"/.config/autostart/shutter.desktop
 #ln -sf "${repohome}"/_config/autostart/gnome-terminal.desktop "$HOME"/.config/autostart/gnome-terminal.desktop

# [beets] https://github.com/sampsyo/beets/
 ln -sfT "${repohome}"/_config/beets "$HOME"/.config/beets

# [mysql]
 ln -sf "${repohome}"/mysql/_my.cnf "$HOME"/.my.cnf

# [gnupg]
 ln -sf private/gnupg "${repohome}"

# [lftp]
 ln -sf private/lftp "${repohome}"

# [alsa]
 ln -sf "${repohome}"/alsa/_asoundrc "$HOME"/.asoundrc

# [rtorrent]
 ln -sf private/rtorrent "${repohome}"

# [ctags]
 ln -sf "${repohome}"/ctags/_ctags "$HOME"/.ctags

# [rtorrent]
 ln -sf private/rtorrent "${repohome}"

# [libao]
 ln -sf "${repohome}"/libao/_libao "$HOME"/.libao

# [mpd]
 mkdir -p ~/.config/mpd
 ln -sf "${repohome}"/mpd/mpd.conf "$HOME"/.config/mpd/mpd.conf

# [ncmpcpp]
 mkdir ~/.config/ncmpcpp
 ln -sf "${repohome}"/ncmpcpp/config "$HOME"/.config/ncmpcpp/config
 ln -sf "${repohome}"/ncmpcpp/bindings "$HOME"/.config/ncmpcpp/bindings

# [private]
"${repohome}"/private/install.sh
echo "dotfiles installed"
