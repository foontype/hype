#!/bin/bash

# HYPE CLI Configuration Module
# Core configuration settings and environment variables

# Find hypefile.yaml by searching upward from current directory
find_hypefile() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/hypefile.yaml" ]]; then
            echo "$dir/hypefile.yaml"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    return 1
}

# Configuration loading function
load_config() {
    # Debug and trace modes (initialize early)
DEBUG="${DEBUG:-false}"
TRACE="${TRACE:-false}"

# Enable trace mode if requested
if [[ "$TRACE" == "true" ]]; then
    set -x
fi

# Default configuration
# Try to find hypefile.yaml by searching upward from current directory
if [[ -z "${HYPEFILE:-}" ]]; then
    if HYPEFILE=$(find_hypefile 2>/dev/null); then
        debug "Found hypefile at: $HYPEFILE"
    else
        echo "Error: hypefile.yaml not found in current or parent directories" >&2
        exit 1
    fi
else
    debug "Using specified HYPEFILE: $HYPEFILE"
fi

# Verify hypefile exists and set HYPE_DIR
if [[ -f "$HYPEFILE" ]]; then
    HYPE_DIR=$(dirname "$(realpath "$HYPEFILE")")
    export HYPE_DIR
    debug "Set HYPE_DIR to hypefile directory: $HYPE_DIR"
else
    echo "Error: hypefile not found at: $HYPEFILE" >&2
    exit 1
fi
}