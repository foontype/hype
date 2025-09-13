#!/bin/bash

# HYPE CLI Main Entry Point
# Plugin discovery and command routing

# Plugin discovery variables
declare -A PLUGIN_REGISTRY
declare -A PLUGIN_HELP_FUNCTIONS

# Load plugins and register commands
load_plugins() {
    debug "Registering plugin commands..."
    
    # In a bundled binary, plugins are already loaded
    # We need to register them manually based on known plugin functions
    local known_plugins=(
        "init:init,deinit,check"
        "template:template"
        "parse:parse"
        "trait:trait"
        "task:task"
        "repo:repo"
        "helmfile:helmfile"
        "aliases:up,down,restart"
    )
    
    for plugin_def in "${known_plugins[@]}"; do
        local plugin_name="${plugin_def%%:*}"
        local commands="${plugin_def##*:}"
        
        IFS=',' read -ra cmd_array <<< "$commands"
        for cmd in "${cmd_array[@]}"; do
            if declare -f "cmd_$cmd" >/dev/null 2>&1; then
                PLUGIN_REGISTRY["$cmd"]="$plugin_name"
                debug "Registered command: $cmd -> $plugin_name"
                
                # Check for help function
                if declare -f "help_$cmd" >/dev/null 2>&1; then
                    PLUGIN_HELP_FUNCTIONS["$cmd"]="help_$cmd"
                    debug "Registered help function: help_$cmd"
                fi
            fi
        done
    done
}

# Generate dynamic help from plugins
generate_plugin_help() {
    cat <<EOF
HYPE CLI - Helmfile Wrapper Tool for Kubernetes AI Deployments

Usage:
  hype <hype-name> <command> [args...]                          Run command for hype deployment
  hype upgrade                                                   Upgrade HYPE CLI to latest version
  hype --version                                                 Show version
  hype --help                                                    Show this help

Available Commands:
EOF

    # Show commands from registered plugins
    for cmd in $(printf '%s\n' "${!PLUGIN_REGISTRY[@]}" | sort); do
        if [[ -n "${PLUGIN_HELP_FUNCTIONS[$cmd]:-}" ]]; then
            # Get brief description from help function
            local help_output
            help_output=$("${PLUGIN_HELP_FUNCTIONS[$cmd]}" 2>/dev/null || echo "")
            local brief_desc
            brief_desc=$(echo "$help_output" | grep -m1 "^[[:space:]]*$cmd" | head -1 || echo "  $cmd")
            echo "  $brief_desc"
        else
            echo "  $cmd                           (No help available)"
        fi
    done

    cat <<EOF

Options:
  --version                Show version information
  --help                   Show help information

Environment Variables:
  HYPEFILE                 Path to hypefile.yaml (default: hypefile.yaml)
  HYPE_DIR                 Directory containing hypefile.yaml (auto-set during hypefile discovery)
                           Searches upward from current directory like git does with .git
  DEBUG                    Enable debug output (default: false)
  TRACE                    Enable bash trace mode with set -x (default: false)
  HYPE_LOG                 Log output destination: false=no output, stdout=stdout (default), file=path to file

Task Variables (auto-set when running tasks):
  HYPE_NAME                Hype name passed to tasks
  HYPE_TRAIT               Current trait value (if set)
  HYPE_CURRENT_DIRECTORY   Current working directory

For detailed help on a specific command, use:
  hype <hype-name> <command> --help

Examples:
  hype my-nginx init                                             Create resources for my-nginx
  hype my-nginx template                                         Show rendered YAML for my-nginx
  hype my-nginx trait set production                             Set trait to production
  hype my-nginx up                                               Build and deploy my-nginx
EOF
}

# Show help
show_help() {
    generate_plugin_help
}

# Show version
show_version() {
    echo "HYPE CLI version $HYPE_VERSION"
}

# Main function
main() {
    # Load plugins first
    load_plugins
    
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    
    case "${1:-}" in
        "--help"|"-h")
            show_help
            ;;
        "--version"|"-v")
            show_version
            ;;
        "upgrade")
            cmd_upgrade
            ;;
        *)
            if [[ $# -lt 2 ]]; then
                error "Missing required arguments"
                show_help
                exit 1
            fi
            
            local hype_name="$1"
            local command="$2"
            shift 2
            
            # Check if command is registered in plugins
            if [[ -n "${PLUGIN_REGISTRY[$command]:-}" ]]; then
                load_config "$hype_name" "$command"
                debug "Command: $command, Hype name: $hype_name, Args: $*"
                
                check_dependencies
                
                # Execute the plugin command
                local cmd_function="cmd_$command"
                if declare -f "$cmd_function" >/dev/null 2>&1; then
                    "$cmd_function" "$hype_name" "$@"
                else
                    error "Command function $cmd_function not found in plugin"
                    exit 1
                fi
            else
                error "Unknown command: $command"
                show_help
                exit 1
            fi
            ;;
    esac
}

# Execute main function with all arguments
main "$@"