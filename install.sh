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
 curl -s https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy -o "$HOME"/local/bin/diff-so-fancy
 cp /usr/share/doc/git/contrib/diff-highlight/diff-highlight "$HOME"/local/bin/
 ln -sf "${repohome}"/vim/dotvim/plugged/phpactor/bin/phpactor "$HOME"/local/bin/
 ln -sf "${repohome}"/bin/git-fuzzy/bin/fit-fuzzy "$HOME"/local/bin/

# [Bash]
 ln -sf "${repohome}"/bash/_bash_aliases "$HOME"/.bash_aliases
 ln -sf "${repohome}"/bash/_inputrc "$HOME"/.inputrc
 ln -sf "${repohome}"/bash/_git.scmbrc "$HOME"/.git.scmbrc
 if [[ ! -f "${repohome}"/bash/completions/docker-compose ]]; then
   curl https://raw.githubusercontent.com/docker/compose/master/contrib/completion/bash/docker-compose -o "${repohome}"/bash/completions/docker-compose
 fi
 if [[ ! -f "${repohome}"/bash/kube-ps1.sh ]]; then
   curl https://raw.githubusercontent.com/jonmosco/kube-ps1/master/kube-ps1.sh -o "${repohome}"/bash/kube-ps1.sh
 fi
 if ! exists chezmoi; then
   cd "$HOME"/local/bin
   sh -c "$(curl -fsLS git.io/chezmoi)"
   cd -
 fi
 if [[ ! -f "${repohome}"/bash/completions/chezmoi ]]; then
   chezmoi completion bash --output="${repohome}"/bash/completions/chezmoi
 fi

 ln -sfT "${repohome}"/sxiv "$HOME"/.config/sxiv

# [cheat] https://github.com/cheat/cheat
 if ! exists cheat; then
  go get -u github.com/cheat/cheat/cmd/cheat
 fi
 ln -sfT "${repohome}"/cheat "$HOME"/.config/cheat
 if [[ ! -f "${repohome}"/bash/completions/cheat.bash ]]; then
   curl https://github.com/cheat/cheat/raw/master/scripts/cheat.bash -o "${repohome}"/bash/completions/cheat.bash
 fi
 if [[ ! -f "${repohome}"/bash/completions/fz.sh ]]; then
   curl https://github.com/changyuheng/fz/raw/master/fz.sh -o "${repohome}"/bash/completions/fz.sh
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

# [vim]
 ln -sfT "${repohome}"/vim/dotvim "$HOME"/.vim

# [git]
 ln -sf "${repohome}"/git/_gitconfig "$HOME"/.gitconfig
 ln -sf "${repohome}"/git/_global_gitignore "$HOME"/.global_gitignore
 ln -sf "${repohome}"/git/_gitk "$HOME"/.gitk

# [tmux]
 ln -sf "${repohome}"/tmux/_tmux.conf "$HOME"/.tmux.conf
 ln -sfT "${repohome}"/tmux "$HOME"/.tmux
 ln -sfT ../private/tmux/tmuxinator "${repohome}"/tmux/tmuxinator

 if ! exists lsd; then
   echo "download from https://github.com/Peltoche/lsd/releases"
 fi
 if ! exists bat; then
   echo "download from https://github.com/sharkdp/bat/releases"
 fi

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

# [beets] https://github.com/sampsyo/beets/
 ln -sfT "${repohome}"/_config/beets "$HOME"/.config/beets

# [ctags]
 ln -sf "${repohome}"/ctags/_ctags "$HOME"/.ctags

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
