#!/bin/bash

# HYPE CLI Releases Plugin
# Provides release validation and checking functionality

# Builtin metadata (standardized)
BUILTIN_NAME="releases"
BUILTIN_VERSION="1.0.0"
BUILTIN_DESCRIPTION="Release validation and checking"

# Register commands in global BUILTIN_COMMANDS array
BUILTIN_COMMANDS+=("releases")

# Help functions
help_releases() {
    cat <<EOF
Usage: hype <hype-name> releases <subcommand>

Release management and validation commands

Subcommands:
  check       Validate all configured releases

Examples:
  hype my-nginx releases check         Check all releases for my-nginx
EOF
}

help_releases_brief() {
    echo "Release management and validation commands"
}

# Main command function
cmd_releases() {
    local hype_name="$1"
    local subcommand="$2"

    case "$subcommand" in
        "check")
            # This functionality is implemented in aliases.sh
            echo "Error: releases check command is now handled by aliases.sh"
            echo "Use: hype $hype_name releases check"
            return 1
            ;;
        *)
            help_releases
            ;;
    esac
}