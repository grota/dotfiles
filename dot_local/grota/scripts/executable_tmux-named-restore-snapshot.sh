#!/usr/bin/env bash

source "$HOME/.tmux/plugins/tmux-named-snapshot/scripts/helpers.sh"
source "$HOME/.tmux/plugins/tmux-named-snapshot/scripts/variables.sh"

main() {
  local name="$1"
  local resurrect_restore_script_path="$(get_tmux_option "$resurrect_restore_path_option" "")"
  if [ -n "$resurrect_restore_script_path" ] && [ -n "$name" ]; then
    tmux display-message "Restoring snapshot '$name'..."
    local _last_resurrect_symlink="$(last_resurrect_file)"
    # actual resurrect file pointed by last symlink
    local _before_load_pointed="$(readlink -e "$_last_resurrect_symlink")"
    local _snapshot_file_full_path="$(snapshot_dir)/$name"

    if [[ -f "$_snapshot_file_full_path" ]]; then
      ln -fs "$_snapshot_file_full_path" "$_last_resurrect_symlink"
      "$resurrect_restore_script_path" "quiet" >/dev/null 2>&1
      ln -fs "$_before_load_pointed" "$_last_resurrect_symlink"
    else
      tmux display-message "Snapshot '$name' not found"
    fi
  fi
}

main "$@"
