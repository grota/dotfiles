#!/usr/bin/env bash
# fzflib -- shared library for fzf-based tools (fzfllm, ob, etc.)
# Source this file; do not execute directly.
#
# Usage:
#   source "$(dirname -- "${BASH_SOURCE[0]}")/fzflib"
#
# Vault-Tec is not responsible for any unforeseen data corruption,
# ghoulification, or existential dread arising from sourcing this file.

# ---------------------------------------------------------------------------
# Color helpers
# ---------------------------------------------------------------------------
_bgreen() { printf "%b%s%b" '\e[1;32m' "$@" '\e[0m'; }
_bwhite() { printf "%b%s%b" '\e[1;37m' "$@" '\e[0m'; }
_white()  { printf "%b%s%b" '\e[0;37m' "$@" '\e[0m'; }

# ---------------------------------------------------------------------------
# Shared environment defaults
# ---------------------------------------------------------------------------
FZF_MARKDOWN_PREVIEW_COMMAND="${FZF_MARKDOWN_PREVIEW_COMMAND:-bat --language markdown --color always --plain}"

# ---------------------------------------------------------------------------
# Shared key bindings (callers may override before sourcing or after)
# ---------------------------------------------------------------------------
KEY_TOGGLE_HEADER="${KEY_TOGGLE_HEADER:-alt-/}"
KEY_SHOW_HELP="${KEY_SHOW_HELP:-?}"
KEY_CHANGE_PREVIEW_PRESET="${KEY_CHANGE_PREVIEW_PRESET:-ctrl-g}"
KEY_PREVIEW_UP_1="${KEY_PREVIEW_UP_1:-alt-k}"
KEY_PREVIEW_UP_2="${KEY_PREVIEW_UP_2:-alt-p}"
KEY_PREVIEW_DOWN_1="${KEY_PREVIEW_DOWN_1:-alt-j}"
KEY_PREVIEW_DOWN_2="${KEY_PREVIEW_DOWN_2:-alt-n}"
KEY_PAGE_UP="${KEY_PAGE_UP:-page-up}"
KEY_PAGE_DOWN="${KEY_PAGE_DOWN:-page-down}"

# ---------------------------------------------------------------------------
# Graphical fzf options shared by all tools.
# Call _fzflib_graphical_opts <HEADER_TEXT> <HELP_CMD> to get the option string.
# ---------------------------------------------------------------------------
_fzflib_graphical_opts() {
  local header_text="$1"
  local help_cmd="$2"
  echo "
--layout=reverse --height='100%'
--preview-window='right,60%,wrap,border-rounded'
--bind='$KEY_CHANGE_PREVIEW_PRESET:change-preview-window:right,76%,wrap|right,60%,wrap'
--border=\"bold\" --color=gutter:-1,border:#4e440c,preview-border:#1d077d,preview-scrollbar:bright-black
--header '$header_text' --header-first
--info=hidden
--cycle --no-sort --exit-0 --tiebreak=index
--listen --bind='start:execute-silent:{ sleep 2 && curl -XPOST localhost:\$FZF_PORT -d hide-header ; }&'
--bind='$KEY_TOGGLE_HEADER:toggle-header'
--bind='$KEY_SHOW_HELP:preview($help_cmd)'
--bind='$KEY_PREVIEW_UP_1:preview-up,$KEY_PREVIEW_UP_2:preview-up'
--bind='$KEY_PREVIEW_DOWN_1:preview-down,$KEY_PREVIEW_DOWN_2:preview-down'
--bind='$KEY_PAGE_UP:preview-page-up'
--bind='$KEY_PAGE_DOWN:preview-page-down'
"
}

# ---------------------------------------------------------------------------
# Open stdin in editor (writes to a temp file, opens EDITOR, then removes it)
# Optional first arg: a label used in the temp filename.
# ---------------------------------------------------------------------------
_fzflib_open_stdin_in_editor() {
  local label="${1:-fzflib}"
  local FILE
  FILE=$(mktemp "${label}_XXX.md" --tmpdir)
  cat > "$FILE"
  "${EDITOR:-nvim}" "$FILE"
  rm -f "$FILE"
}

# ---------------------------------------------------------------------------
# create_box -- draw a UTF-8 box around text, honouring FZF_PREVIEW_COLUMNS.
# Requires a writable fifo path in $FZFLIB_FIFO (set by the calling script).
# ---------------------------------------------------------------------------
create_box() {
  local text="$1"
  local padding=2
  local max_overall_width="${FZF_PREVIEW_COLUMNS}"
  local longest_text_width_found=0
  local formatted_text=""
  local line
  local max_text_width
  local width_of_text_plus_padding

  # 2 is for the 2 external vertical lines; padding * 2 for left + right
  (( max_text_width = max_overall_width - 2 - padding * 2 ))

  # Wrap lines longer than max_text_width
  while IFS= read -r line; do
    while [[ ${#line} -gt $((max_text_width)) ]]; do
      formatted_text+="${line:0:$((max_text_width))}"'\0'
      line=${line:$((max_text_width))}
    done
    formatted_text+="$line"'\0'
  done <<< "$text"

  # Calculate longest_text_width_found via fifo
  {
    echo -E "$formatted_text" | sed -e 's/\\0/\x00/g' > "$FZFLIB_FIFO"
  } &
  while IFS= read -d '' -r line; do
    (( ${#line} > longest_text_width_found )) && longest_text_width_found=${#line}
  done < "$FZFLIB_FIFO"

  (( width_of_text_plus_padding = longest_text_width_found + (padding * 2) ))

  printf "┌"
  printf "%${width_of_text_plus_padding}s" "" | sed "s/ /─/g"
  printf "┐\n"

  echo -E "$formatted_text" | sed -e 's/\\0/\x00/g' | while IFS= read -d '' -r line; do
    printf "│%${padding}s%-${longest_text_width_found}s%${padding}s│\n" "" "$line" ""
  done

  printf "└"
  printf "%${width_of_text_plus_padding}s" | sed "s/ /─/g"
  printf "┘\n"
}
