#!/usr/bin/env bash

dconf dump / > "${DOTFILESREPO}/chezmoi_ignored/dconf/saved_dconf.dconf"
