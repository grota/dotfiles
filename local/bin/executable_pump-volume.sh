#!/bin/bash
# Pump volume for playing audio streams
# Requires: jq, fzf (for interactive mode)

set -euo pipefail

DEFAULT_VOLUME=170
MAX_ALLOWED=300

# Blacklist: application names to skip (regex patterns for jq's test())
BLACKLIST_PATTERN="speech-dispatcher"

# ============================================================================
# Help
# ============================================================================
show_help() {
    cat <<'EOF'
pump-volume.sh - Set volume for playing audio streams

USAGE:
    pump-volume.sh [OPTIONS] [VOLUME] [APP_QUERY]

SCENARIOS:
    pump-volume.sh
        Interactive mode: prompt for volume (default 170%), then select
        sink(s) with fzf (multi-select enabled).

    pump-volume.sh <volume>
        Set volume to <volume>%, then interactively select sink(s) with fzf.

    pump-volume.sh <volume> <app_query>
        Set volume to <volume>%, open fzf with <app_query> pre-filled
        for quick confirmation.

    pump-volume.sh --no-interactive
        Non-interactive: apply default volume (170%) to ALL playing sinks.

OPTIONS:
    -n, --no-interactive    Apply to all playing sinks without prompts
    -h, --help              Show this help message

EXAMPLES:
    pump-volume.sh                  # Interactive, ask everything
    pump-volume.sh 200              # 200% volume, select sinks with fzf
    pump-volume.sh 150 firefox      # 150% volume, fzf pre-filtered to "firefox"
    pump-volume.sh --no-interactive # 170% to all playing sinks

NOTES:
    - Volume range: 1-300%
    - Streams matching "speech-dispatcher" are always excluded
    - Multi-select in fzf: use TAB to select multiple sinks
EOF
}

# ============================================================================
# Utility functions
# ============================================================================

# Get all playing sink-inputs as JSON (filtered by blacklist)
get_playing_sinks() {
    pactl --format=json list sink-inputs 2>/dev/null | jq -c --arg blacklist "$BLACKLIST_PATTERN" '
        .[]
        | select(.corked == false)
        | select(.properties."application.name" | test($blacklist) | not)
        | {
            index: .index,
            app: .properties."application.name",
            media: .properties."media.name"
          }
    ' 2>/dev/null
}

# Validate volume value
validate_volume() {
    local vol="$1"
    # Strip '%' suffix if provided
    vol="${vol%\%}"
    
    if ! [[ "$vol" =~ ^[0-9]+$ ]]; then
        echo "Error: Volume must be a positive integer (got: '$vol')" >&2
        exit 1
    fi
    
    if (( vol > MAX_ALLOWED )); then
        echo "Error: Volume cannot exceed ${MAX_ALLOWED}% (got: ${vol}%)" >&2
        exit 1
    fi
    
    if (( vol < 1 )); then
        echo "Error: Volume must be at least 1% (got: ${vol}%)" >&2
        exit 1
    fi
    
    echo "$vol"
}

# Prompt user for volume with default
prompt_volume() {
    local input
    read -rp "Volume % [${DEFAULT_VOLUME}]: " input
    if [[ -z "$input" ]]; then
        echo "$DEFAULT_VOLUME"
    else
        validate_volume "$input"
    fi
}

# Format sink for fzf display: "index | app | media"
format_sink_for_fzf() {
    local json="$1"
    local index app media
    index=$(echo "$json" | jq -r '.index')
    app=$(echo "$json" | jq -r '.app')
    media=$(echo "$json" | jq -r '.media // "(no media)"')
    echo "${index}|${app}|${media}"
}

# Select sinks using fzf (multi-select)
# $1 = optional query to pre-fill fzf
select_sinks_fzf() {
    local query="${1:-}"
    local sinks_json
    sinks_json=$(get_playing_sinks)
    
    if [[ -z "$sinks_json" ]]; then
        echo "No audio streams currently playing." >&2
        exit 0
    fi
    
    # Build fzf input: one line per sink
    local fzf_input=""
    while read -r line; do
        fzf_input+="$(format_sink_for_fzf "$line")"$'\n'
    done <<< "$sinks_json"
    
    # Remove trailing newline
    fzf_input="${fzf_input%$'\n'}"
    
    # Run fzf with multi-select
    local fzf_args=(
        --multi
        --header="Select sink(s) - TAB to multi-select, ENTER to confirm"
        --delimiter='|'
        --with-nth=2,3
        --preview-window=hidden
    )
    
    if [[ -n "$query" ]]; then
        fzf_args+=(--query="$query")
    fi
    
    local selected
    selected=$(echo "$fzf_input" | fzf "${fzf_args[@]}") || {
        echo "No sinks selected." >&2
        exit 0
    }
    
    # Return selected indices (first field)
    echo "$selected" | cut -d'|' -f1
}

# Apply volume to given sink indices
apply_volume() {
    local volume="$1"
    shift
    local indices=("$@")
    
    echo "Setting volume to ${volume}%:"
    echo
    
    for index in "${indices[@]}"; do
        # Get sink info for display
        local info
        info=$(pactl --format=json list sink-inputs 2>/dev/null | jq -r --argjson idx "$index" '
            .[] | select(.index == $idx) |
            "\(.properties."application.name") | \(.properties."media.name" // "(no media)")"
        ' 2>/dev/null)
        
        echo "  Sink Input #$index: $info"
        pactl set-sink-input-volume "$index" "${volume}%"
    done
    
    echo
    echo "Done!"
}

# Apply volume to all playing sinks (non-interactive)
apply_to_all() {
    local volume="$1"
    local sinks_json
    sinks_json=$(get_playing_sinks)
    
    if [[ -z "$sinks_json" ]]; then
        echo "No audio streams currently playing."
        exit 0
    fi
    
    echo "Setting volume to ${volume}% for all playing streams:"
    echo
    
    while read -r line; do
        local index app media
        index=$(echo "$line" | jq -r '.index')
        app=$(echo "$line" | jq -r '.app')
        media=$(echo "$line" | jq -r '.media // "(no media)"')
        
        echo "  Sink Input #$index: $app | $media"
        pactl set-sink-input-volume "$index" "${volume}%"
    done <<< "$sinks_json"
    
    echo
    echo "Done!"
}

# ============================================================================
# Main
# ============================================================================

main() {
    local interactive=true
    local volume=""
    local app_query=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -n|--no-interactive)
                interactive=false
                shift
                ;;
            *)
                # First positional arg = volume, second = app_query
                if [[ -z "$volume" ]]; then
                    volume="$1"
                elif [[ -z "$app_query" ]]; then
                    app_query="$1"
                else
                    echo "Error: Too many arguments" >&2
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Scenario 4: --no-interactive
    if [[ "$interactive" == false ]]; then
        if [[ -n "$volume" ]]; then
            volume=$(validate_volume "$volume")
        else
            volume="$DEFAULT_VOLUME"
        fi
        apply_to_all "$volume"
        exit 0
    fi
    
    # Interactive scenarios
    
    # Scenario 1: No params - ask for volume, then select sinks
    if [[ -z "$volume" ]]; then
        volume=$(prompt_volume)
    else
        # Scenario 2 & 3: Volume provided
        volume=$(validate_volume "$volume")
    fi
    
    # Select sinks with fzf (optionally with pre-filled query)
    local selected_indices
    selected_indices=$(select_sinks_fzf "$app_query")
    
    # Convert newline-separated indices to array
    local indices_array=()
    while read -r idx; do
        [[ -n "$idx" ]] && indices_array+=("$idx")
    done <<< "$selected_indices"
    
    if [[ ${#indices_array[@]} -eq 0 ]]; then
        echo "No sinks selected."
        exit 0
    fi
    
    apply_volume "$volume" "${indices_array[@]}"
}

main "$@"
