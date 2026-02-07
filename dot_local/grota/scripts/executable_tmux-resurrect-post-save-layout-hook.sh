#!/usr/bin/env bash
# Post-save hook for tmux-resurrect to keep only the current session
# This script is called by tmux-resurrect during save process
# First argument is the path to the saved session file

set -e

RESURRECT_FILE="$1"

if [ -z "$RESURRECT_FILE" ] || [ ! -f "$RESURRECT_FILE" ]; then
    exit 0
fi

# Get current session name from tmux
CURRENT_SESSION="$(tmux display-message -p '#S')"

if [ -z "$CURRENT_SESSION" ]; then
    exit 0
fi

# Create a temporary file for filtered content
TEMP_FILE="$(mktemp)"

# Filter the resurrect file to keep only current session data
# Format: type<tab>session_name<tab>...
# For pane and window lines, session_name is field 2
# For state lines, we need to update client_session to current session
# For grouped_session lines, check both session_name and original_session

awk -v session="$CURRENT_SESSION" -F '\t' '{
    type = $1
    if (type == "pane" || type == "window") {
        if ($2 == session) {
            print
        }
    } else if (type == "grouped_session") {
        # Format: grouped_session<tab>session_name<tab>original_session<tab>...
        if ($2 == session || $3 == session) {
            print
        }
    } else if (type == "state") {
        # Format: state<tab>client_session<tab>client_last_session
        # Update client_session to current, preserve client_last_session
        print "state\t" session "\t" $3
    } else {
        # Keep any other lines (shouldnt be any, but just in case)
        print
    }
}' "$RESURRECT_FILE" > "$TEMP_FILE"

# Replace original file with filtered content
mv "$TEMP_FILE" "$RESURRECT_FILE"
