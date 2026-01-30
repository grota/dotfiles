# Volume utility functions for pactl scripts
# This file should be sourced, not executed directly

# Validate volume value
# Args: $1 = volume value (with or without % suffix)
# Returns: validated volume (integer) or exits with error
validate_volume() {
    local vol="$1"
    local max_allowed="${MAX_ALLOWED:-300}"

    # Strip '%' suffix if provided
    vol="${vol%\%}"

    if ! [[ "$vol" =~ ^[0-9]+$ ]]; then
        echo "Error: Volume must be a positive integer (got: '$vol')" >&2
        return 1
    fi

    if (( vol > max_allowed )); then
        echo "Error: Volume cannot exceed ${max_allowed}% (got: ${vol}%)" >&2
        return 1
    fi

    if (( vol < 1 )); then
        echo "Error: Volume must be at least 1% (got: ${vol}%)" >&2
        return 1
    fi

    echo "$vol"
}
