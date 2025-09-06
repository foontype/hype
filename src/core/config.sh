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
HYPE_LOG="${HYPE_LOG:-stdout}"

# Enable trace mode if requested
if [[ "$TRACE" == "true" ]]; then
    set -x
fi

# Skip hypefile checks for version and help commands
skip_hypefile_check=false
if [[ $# -eq 0 ]]; then
    skip_hypefile_check=true
else
    for arg in "$@"; do
        if [[ "$arg" == "--version" || "$arg" == "-v" || "$arg" == "--help" || "$arg" == "-h" ]]; then
            skip_hypefile_check=true
            break
        fi
    done
fi

# Default configuration
# Try to find hypefile.yaml by searching upward from current directory
if [[ "$skip_hypefile_check" == "false" ]]; then
    if [[ -z "${HYPEFILE:-}" ]]; then
        if HYPEFILE=$(find_hypefile 2>/dev/null); then
            debug "Found hypefile at: $HYPEFILE"
        else
            echo "Error: hypefile.yaml not found in current or parent directories" >&2
            exit 1
        fi
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
else
    # For version/help commands, set minimal defaults
    HYPEFILE="${HYPEFILE:-hypefile.yaml}"
    export HYPE_DIR="$PWD"
fi
}