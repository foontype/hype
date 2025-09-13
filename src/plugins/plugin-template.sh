#!/bin/bash

# HYPE CLI Plugin Template
# 
# This file serves as a template for creating new HYPE CLI plugins.
# Copy this file and modify it to create your own plugin.

# Plugin metadata (required)
PLUGIN_NAME="template"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Template plugin for HYPE CLI"
PLUGIN_COMMANDS=("template")

# Plugin initialization function (optional)
# Called when the plugin is loaded
plugin_template_init() {
    debug "Plugin $PLUGIN_NAME initialized"
}

# Main command function
# This is called when the user runs: hype template
# shellcheck disable=SC2317
cmd_template() {
    local subcommand="${1:-}"
    
    case "$subcommand" in
        "")
            # Default behavior when no subcommand is provided
            info "Template plugin executed"
            ;;
        "help"|"-h"|"--help")
            show_template_help
            ;;
        *)
            error "Unknown template subcommand: $subcommand"
            show_template_help
            exit 1
            ;;
    esac
}

# Help function for this plugin
show_template_help() {
    cat << EOF
Usage: hype template [COMMAND]

Template plugin for HYPE CLI

Commands:
  help, -h, --help    Show this help message

Examples:
  hype template       Execute template plugin
  hype template help  Show this help
EOF
}

# Plugin cleanup function (optional)
# Called when the plugin is unloaded
plugin_template_cleanup() {
    debug "Plugin $PLUGIN_NAME cleaned up"
}