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

# Version information
HYPE_VERSION="0.6.2"

# Debug and trace modes (initialize early)
DEBUG="${DEBUG:-false}"
TRACE="${TRACE:-false}"
HYPE_LOG="${HYPE_LOG:-stdout}"

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
        HYPEFILE="hypefile.yaml"
        debug "No hypefile found, using default: $HYPEFILE"
    fi
fi

# Set HYPE_DIR based on hypefile location
if [[ -f "$HYPEFILE" ]]; then
    HYPE_DIR=$(dirname "$(realpath "$HYPEFILE")")
    export HYPE_DIR
    debug "Set HYPE_DIR to hypefile directory: $HYPE_DIR"
else
    export HYPE_DIR="$PWD"
    debug "Set HYPE_DIR to current directory: $HYPE_DIR"
fi