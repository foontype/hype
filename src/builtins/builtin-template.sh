#!/bin/bash

# HYPE CLI Builtin Template
# 
# This file serves as a template for creating new HYPE CLI builtins.
# Copy this file and modify it to create your own builtin.

# Builtin metadata (required)
BUILTIN_NAME="template"
BUILTIN_VERSION="1.0.0"
BUILTIN_DESCRIPTION="Template builtin for HYPE CLI"
# BUILTIN_COMMANDS+=("example") # Uncomment and replace "example" with your command name

# Builtin initialization function (optional)
# Called when the builtin is loaded
builtin_template_init() {
    debug "Builtin $BUILTIN_NAME initialized"
}

# Main command function
# This is called when the user runs: hype template
# shellcheck disable=SC2317
cmd_template() {
    local subcommand="${1:-}"
    
    case "$subcommand" in
        "")
            # Default behavior when no subcommand is provided
            info "Template builtin executed"
            ;;
        "help"|"-h"|"--help")
            show_template_help
            ;;
        *)
            error "Unknown template subcommand: $subcommand"
            show_template_help
            return 1
            ;;
    esac
}

# Help function for this plugin
show_template_help() {
    cat << EOF
Usage: hype template [COMMAND]

Template builtin for HYPE CLI

Commands:
  help, -h, --help    Show this help message

Examples:
  hype template       Execute template builtin
  hype template help  Show this help
EOF
}

# Builtin cleanup function (optional)
# Called when the builtin is unloaded
builtin_template_cleanup() {
    debug "Builtin $BUILTIN_NAME cleaned up"
}