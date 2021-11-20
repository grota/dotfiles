#!/usr/bin/env bash
# execute with bash -c "$(wget -O - https://raw.githubusercontent.com/grota/dotfiles/master/install.sh)"

set -e

exists() {
  if command -v "$1" >/dev/null 2>&1
  then
    return 0
  else
    return 1
  fi
}

BIN_DIR="$HOME/local/bin"

if [ ! -d "$BIN_DIR" ]; then
  mkdir -p "$BIN_DIR"
fi

export PATH="$PATH:$BIN_DIR"

if ! exists chezmoi; then
  if exists curl; then
    sh -c "$(curl -fsSL https://git.io/chezmoi)" -- -b "$BIN_DIR"
  elif exists wget; then
    sh -c "$(wget -qO- https://git.io/chezmoi)" -- -b "$BIN_DIR"
  else
    echo "To install chezmoi, you must have curl or wget installed." >&2
    exit 1
  fi
  echo "Installed chezmoi in $BIN_DIR"
fi

if [ ! "$(command -v bw)" ]; then
  TMPFILE=$(mktemp)
  if exists wget; then
    wget -q -O "$TMPFILE" "https://vault.bitwarden.com/download/?app=cli&platform=linux"
  else
    curl -fsSL -o "$TMPFILE" "https://vault.bitwarden.com/download/?app=cli&platform=linux"
  fi
  unzip "$TMPFILE" -d "$BIN_DIR"
  rm "$TMPFILE"
  chmod u+x "$BIN_DIR/bw"
  echo "Installed bitwarden cli bw in $BIN_DIR"
fi

echo "Login with bitwarden cli."
read -p "Your Bitwarden email: " BW_EMAIL
read -p "Your Bitwarden master password: " BW_PASSWORD
bw login "$BW_EMAIL" "$BW_PASSWORD"
echo "These dotfiles assume ~/.bash_aliases is sourced by ~/.bashrc, fix it if it is not so."
