#!/usr/bin/env bash

source "$HOME/.tmux/plugins/tmux-named-snapshot/scripts/helpers.sh"
source "$HOME/.tmux/plugins/tmux-named-snapshot/scripts/variables.sh"

main() {
  local name="$1"
  local resurrect_save_script_path="$(get_tmux_option "$resurrect_save_path_option" "")"
  if [ -n "$resurrect_save_script_path" ] && [ -n "$name" ]; then
    tmux display-message "Saving snapshot '$name'..."
    local _last_resurrect_symlink="$(last_resurrect_file)"
    # actual resurrect file pointed by last symlink
    local _before_save_pointed="$(readlink -e "$_last_resurrect_symlink")"
    local _snapshot_file_full_path="$(snapshot_dir)/$name"

    "$resurrect_save_script_path" "quiet" >/dev/null 2>&1
    # actual resurrect file pointed by last symlink
    local _after_save_pointed="$(readlink -e "$_last_resurrect_symlink")"

    if files_differ "$_snapshot_file_full_path" "$_after_save_pointed "; then
      mv "$_after_save_pointed" "$_snapshot_file_full_path"
    fi

    # might be a dead link on very first
    if [ -n "$_before_save_pointed" ]; then
      ln -sf "$_before_save_pointed" "$_last_resurrect_symlink"
    fi

    tmux display-message "Snapshot '$name' saved."
  fi
}

main "$@"
