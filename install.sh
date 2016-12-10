#!/bin/bash

set -e

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

# When running in Vagrant we need to get the right home path, and sudo does not
# expose this envvar automatically
if [ -n "$SUDO_USER"  ]; then
  export HOME=$(bash <<< "echo ~$SUDO_USER")
fi

# [bin]
 mkdir -p "$HOME"/local/bin
 #ln -sf ${repohome}/bin/rupa_v/v "$HOME"/local/bin/v

# [Bash]
 ln -sf "${repohome}"/bash/_bash_aliases "$HOME"/.bash_aliases
 ln -sf "${repohome}"/bash/_inputrc "$HOME"/.inputrc
 ln -sf "${repohome}"/bash/_git.scmbrc "$HOME"/.git.scmbrc
 if [[ ! -f "${repohome}"/bash/completions/docker-compose ]]; then
   curl https://raw.githubusercontent.com/docker/compose/master/contrib/completion/bash/docker-compose -o "${repohome}"/bash/completions/docker-compose
 fi

# [cheat] https://github.com/chrisallenlane/cheat
 ln -sfT "${repohome}"/cheat "$HOME"/.cheat

# [ranger]
 ln -sfT "${repohome}"/ranger "$HOME"/.config/ranger

# [zsh]
 ln -sfT "${repohome}"/zsh/oh-my-zsh "$HOME"/.oh-my-zsh
 ln -sf "${repohome}"/zsh/_zshrc "$HOME"/.zshrc

# [hub]
 cd "${repohome}"
 if [[ ! -f "$HOME"/local/bin/hub ]]; then
   cd vendor/hub
   rake install prefix="$HOME"/local
   cd "${repohome}"
 fi

 if [[ ! -f "$HOME"/local/bin/trans ]]; then
   wget git.io/trans -O "$HOME"/local/bin/trans
   chmod u+x "$HOME"/local/bin/trans
 fi

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
 if ! exists phpcs; then
   composer global install
 fi
 # phpcs config file is CodeSniffer.conf in phpcs global composer vendor dir.
 if ! phpcs --config-show|grep -q installed_paths; then
   phpcs --config-set installed_paths "$HOME"/.composer/vendor/drupal/coder/coder_sniffer
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

# [ruby]
 ln -sf "${repohome}"/ruby/_irbrc.rb "$HOME"/.irbrc
 ln -sf "${repohome}"/ruby/_pryrc.rb "$HOME"/.pryrc
 ln -sf "${repohome}"/ruby/_gemrc "$HOME"/.gemrc

# [dconf]
if exists dconf && [ -n "$DISPLAY" ]; then
  dconf load /org/gnome/libgnomekbd/keyboard/ < "${repohome}"/dconf/_org_gnome_libgnomekbd_keyboard
  dconf load /org/gnome/desktop/wm/keybindings/ < "${repohome}"/dconf/org_gnome_desktop_wm_keybindings.dconf
  # dconf dump /org/gnome/settings-daemon/plugins/media-keys/ > dconf/dconf_gnome_settings_daemon_keys.dconf
  dconf load /org/gnome/settings-daemon/plugins/media-keys/ < "${repohome}"/dconf/dconf_gnome_settings_daemon_keys.dconf
fi

 if [ ! -d "$HOME"/.fonts ]; then
   mkdir -p "$HOME"/.fonts
 fi
 if [ ! -f "$HOME"/.fonts/Sauce\ Code\ Powerline\ Semibold.otf ]; then
   curl https://raw.githubusercontent.com/powerline/fonts/master/SourceCodePro/Sauce%20Code%20Powerline%20Semibold.otf -o "$HOME"/.fonts/Sauce\ Code\ Powerline\ Semibold.otf
 fi

# [gconf]
if exists gconftool-2; then
  # gconftool-2 --dump '/apps/gnome-terminal' > gconf/gnome-terminal_gconf_settings.xml
  gconftool-2 --load "${repohome}"/gconf/gnome-terminal_gconf_settings.xml
  # gconftool-2 --dump '/desktop/gnome/keybindings/hamster-applet' > gconf/hamster-shortcut.xml
  #gconftool-2 --load "${repohome}"/gconf/hamster-shortcut.xml
  # gconftool-2 --dump '/apps/hamster-indicator' > gconf/hamster-settings.xml
  #gconftool-2 --load "${repohome}"/gconf/hamster-settings.xml
fi

# [ssh]
 mkdir -p "$HOME"/.ssh
 chmod 700 "$HOME"/.ssh
 ln -sf private/ssh "${repohome}"

# [pianobar]
 ln -sfT ../private/_config/pianobar "${repohome}"/_config/pianobar

# [drush]
 mkdir -p "$HOME"/.drush
 ln -sf private/drush "${repohome}"

# [X]
 # xproperties, old stuff
 ln -sf "${repohome}"/X/_Xdefaults "$HOME"/.Xdefaults
 # ubuntu lightdm does not consider "$HOME"/.xsession{,rc} nor "$HOME"/.xinitrc
 ln -sf "${repohome}"/X/_xinitrc "$HOME"/.xinitrc
 ln -sf "${repohome}"/X/_xbindkeysrc  "$HOME"/.xbindkeysrc
 ln -sf "${repohome}"/X/_Xmodmap "$HOME"/.Xmodmap
 # what to autostart in X
 [[ ! -d "$HOME"/.config/autostart ]] && mkdir -p "$HOME"/.config/autostart
 ln -sf "${repohome}"/_config/autostart/xinitrc.desktop "$HOME"/.config/autostart/xinitrc.desktop
 ln -sf "${repohome}"/_config/autostart/xrdb.desktop "$HOME"/.config/autostart/xrdb.desktop
 ln -sf "${repohome}"/_config/autostart/dropbox.desktop "$HOME"/.config/autostart/dropbox.desktop
 #ln -sf "${repohome}"/_config/autostart/hamster-indicator.desktop "$HOME"/.config/autostart/hamster-indicator.desktop
 ln -sf "${repohome}"/_config/autostart/indicator-multiload.desktop "$HOME"/.config/autostart/indicator-multiload.desktop
 ln -sf "${repohome}"/_config/autostart/shutter.desktop "$HOME"/.config/autostart/shutter.desktop
 ln -sf "${repohome}"/_config/autostart/gnome-terminal.desktop "$HOME"/.config/autostart/gnome-terminal.desktop

# [beets] https://github.com/sampsyo/beets/
 ln -sfT "${repohome}"/_config/beets "$HOME"/.config/beets

# [Gnome]
 #mkdir -p "$HOME"/.config/gtk-3.0
 #ln -sf "${repohome}"/_config/gtk-3.0/gtk.css "$HOME"/.config/gtk-3.0/gtk.css

# [mysql]
 ln -sf "${repohome}"/mysql/_my.cnf "$HOME"/.my.cnf

# [ikiwiki]
 ln -sf private/ikiwiki "${repohome}"

# [vimperator]
 ln -sf "${repohome}"/vimperator/_vimperatorrc "$HOME"/.vimperatorrc
 mkdir -p "$HOME"/.vimperator/
 ln -sfT "${repohome}"/vimperator/plugin "$HOME"/.vimperator/plugin

# [gnupg]
 ln -sf private/gnupg "${repohome}"

# [lftp]
 ln -sf private/lftp "${repohome}"

# [drush]
 ln -sf "${repohome}"/bin/drush/drush "$HOME"/local/bin/drush

# [alsa]
 ln -sf "${repohome}"/alsa/_asoundrc "$HOME"/.asoundrc

# [rtorrent]
 ln -sf private/rtorrent "${repohome}"

# [ctags]
 ln -sf "${repohome}"/ctags/_ctags "$HOME"/.ctags

# [alsa]
 ln -sf "${repohome}"/alsa/_asoundrc "$HOME"/.asoundrc

# [rtorrent]
 ln -sf private/rtorrent "${repohome}"

# [libao]
 ln -sf "${repohome}"/libao/_libao "$HOME"/.libao

# [mplayer]
 mkdir -p "$HOME"/.mplayer
 ln -sf "${repohome}"/mplayer/config "$HOME"/.mplayer/config

 gsettings set com.canonical.desktop.interface scrollbar-mode normal
# [private]
"${repohome}"/private/install.sh
echo "dotfiles installed"

# NOTES:
# The old vimperator stuff has been removed but can be found in the git history, see commit after 8b619de
