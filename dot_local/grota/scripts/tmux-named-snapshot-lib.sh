#!/usr/bin/env bash

get_snapshot_name() {
  local name="$1"
  if [ -z "$name" ]; then
    local provider
    provider="ls -1 $(snapshot_dir)"
    local OPTS
    OPTS="
    $FZF_DEFAULT_OPTS
    --preview-window='down,wrap,border-rounded'
    --preview=\"bat $(snapshot_dir)/{} | grep '^pane'|cut -d'	' -f8\"
    --ansi
    --bind=\"ctrl-r:execute(read -r -p 'new name: ' -i '{}' -e newname; mv $(snapshot_dir)/'{}' $(snapshot_dir)/\$newname)+reload($provider)\"
    --bind=\"ctrl-d:execute(rm $(snapshot_dir)/'{}')+reload($provider)\"
    "
    name=$($provider | FZF_DEFAULT_OPTS="$OPTS" fzf)
  fi
  echo "$name"
}
