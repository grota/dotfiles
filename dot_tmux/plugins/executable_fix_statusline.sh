#!/usr/bin/env bash
tmux_option() {
    local -r value=$(tmux show-option -gqv "$1")
    local -r default="$2"

    if [ -n "$value" ]; then
        echo "$value"
    else
        echo "$default"
    fi
}

main() {
    local -r status_left_value="$(tmux_option "status-left")"
    tmux set-option -gq "status-left" "${status_left_value}#{prefix_highlight}"

    local -r status_right_value="$(tmux_option "status-right" | sed -e 's/[[:space:]]*$//')"
    tmux set-option -gq "status-right" "${status_right_value}"

    $DOTFILESREPO/tmux/plugins/tmux-prefix-highlight/prefix_highlight.tmux
}
main
