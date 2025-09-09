#!/bin/bash

# HYPE CLI Common Functions Module
# Logging, utility functions, and color constants

# Version information
HYPE_VERSION="0.7.0"

# Initialize logging variable early to avoid unbound variable errors
HYPE_LOG="${HYPE_LOG:-stdout}"

# Debug and trace modes (initialize early)
DEBUG="${DEBUG:-false}"
TRACE="${TRACE:-false}"

# Enable trace mode if requested
if [[ "$TRACE" == "true" ]]; then
    set -x
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
debug() {
    if [[ "$DEBUG" == "true" ]]; then
        if [[ "$HYPE_LOG" == "false" ]]; then
            return
        elif [[ "$HYPE_LOG" == "stdout" ]]; then
            echo -e "${BLUE}[DEBUG]${NC} $*" >&2
        else
            echo -e "${BLUE}[DEBUG]${NC} $*" >> "$HYPE_LOG"
        fi
    fi
}

info() {
    if [[ "$HYPE_LOG" == "false" ]]; then
        return
    elif [[ "$HYPE_LOG" == "stdout" ]]; then
        echo -e "${GREEN}[INFO]${NC} $*"
    else
        echo -e "${GREEN}[INFO]${NC} $*" >> "$HYPE_LOG"
    fi
}

warn() {
    if [[ "$HYPE_LOG" == "false" ]]; then
        return
    elif [[ "$HYPE_LOG" == "stdout" ]]; then
        echo -e "${YELLOW}[WARN]${NC} $*"
    else
        echo -e "${YELLOW}[WARN]${NC} $*" >> "$HYPE_LOG"
    fi
}

error() {
    if [[ "$HYPE_LOG" == "false" ]]; then
        return
    elif [[ "$HYPE_LOG" == "stdout" ]]; then
        echo -e "${RED}[ERROR]${NC} $*" >&2
    else
        echo -e "${RED}[ERROR]${NC} $*" >> "$HYPE_LOG"
    fi
}

die() {
    error "$@"
    exit 1
}

# Utility function to run commands silently
silent() {
    local original_hype_log="$HYPE_LOG"
    export HYPE_LOG="false"
    "$@"
    local exit_code=$?
    export HYPE_LOG="$original_hype_log"
    return $exit_code
}