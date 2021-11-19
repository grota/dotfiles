#!/usr/bin/env bash

if [ "$(lsb_release -si)" != Ubuntu ]; then
  echo Only Ubuntu handled ATM.
  exit 0;
fi
sudo apt install curl build-essential git bash-completion universal-ctags php8.0-cli

exists() {
  if command -v "$1" >/dev/null 2>&1
  then
    return 0
  else
    return 1
  fi
}

function install_from_gh() {
  if ! exists "$1"; then
    wget https://github.com/"$2"/releases/download/"$3"/"$4"
    sudo dpkg -i "$4"
    rm "$4"
  fi
}
install_from_gh lsd Peltoche/lsd 0.20.1 lsd_0.20.1_amd64.deb
install_from_gh bat sharkdp/bat v0.18.3 bat_0.18.3_amd64.deb
install_from_gh gh cli/cli v2.2.0 gh_2.2.0_linux_amd64.deb

if ! exists nvim; then
  sudo apt install neovim
fi

if ! exists ag; then
  sudo apt install silversearcher-ag
fi

if ! exists go; then
  GOVERSION=go1.17.3.linux-amd64.tar.gz
  wget https://golang.org/dl/"$GOVERSION"
  sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf "$GOVERSION"
fi

if ! exists cheat; then
  /usr/local/go/bin/go get -u github.com/cheat/cheat/cmd/cheat
fi

if ! exists navi; then
  wget -q -O- https://github.com/denisidoro/navi/releases/download/v2.17.0/navi-v2.17.0-x86_64-unknown-linux-musl.tar.gz | tar -C ~/local/bin -xzv
fi

if ! exists shellcheck; then
  wget -q -O-  https://github.com/koalaman/shellcheck/releases/download/stable/shellcheck-stable.linux.x86_64.tar.xz | tar xv -J --strip-components 1  -C ~/local/bin shellcheck-stable/shellcheck
fi

if [ ! -f ~/local/bin/composer ]; then
  wget -O ~/local/bin/composer https://github.com/composer/composer/releases/download/2.1.12/composer.phar
  chmod a+x ~/local/bin/composer
fi
