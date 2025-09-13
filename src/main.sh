#!/bin/bash

# HYPE CLI Main Entry Point
# Builtin command discovery and routing

# Global arrays for builtin commands and their help functions
declare -a BUILTIN_COMMANDS=()
declare -A BUILTIN_HELP_FUNCTIONS=()

# Register a builtin command
register_builtin_command() {
    local command="$1"
    local help_function="$2"
    
    if [[ ! " ${BUILTIN_COMMANDS[*]} " =~ [[:space:]]${command}[[:space:]] ]]; then
        BUILTIN_COMMANDS+=("$command")
    fi
    
    if [[ -n "$help_function" ]]; then
        BUILTIN_HELP_FUNCTIONS["$command"]="$help_function"
    fi
}

# Load builtin metadata - since builtins are already loaded in the bundled script,
# we just need to register the commands that are available
load_builtin_metadata() {
    debug "Loading builtin metadata from existing functions"
    
    # Register all known builtin commands by checking if their cmd_ functions exist
    local known_commands=("init" "deinit" "check" "template" "parse" "trait" "task" "repo" "helmfile" "up" "down" "restart")
    
    for cmd in "${known_commands[@]}"; do
        if declare -f "cmd_${cmd}" > /dev/null; then
            register_builtin_command "$cmd" "help_${cmd}"
            debug "Registered builtin command: $cmd"
        fi
    done
}

# Execute a builtin command dynamically
execute_builtin_command() {
    local command="$1"
    local hype_name="$2"
    shift 2
    
    debug "Executing builtin command: $command with args: $*"
    
    # Check for help option first
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || "${1:-}" == "help" ]]; then
        local help_function="help_${command}"
        if declare -f "$help_function" > /dev/null; then
            "$help_function"
            return 0
        else
            error "Help not available for command: $command"
            return 1
        fi
    fi
    
    # Check if command exists in registered commands
    if [[ " ${BUILTIN_COMMANDS[*]} " =~ [[:space:]]${command}[[:space:]] ]]; then
        local cmd_function="cmd_${command}"
        
        # Check if the function exists
        if declare -f "$cmd_function" > /dev/null; then
            "$cmd_function" "$hype_name" "$@"
        else
            error "Command function $cmd_function not found for command: $command"
            exit 1
        fi
    else
        error "Unknown command: $command"
        show_help
        exit 1
    fi
}

# Generate dynamic help from builtin modules
generate_dynamic_help() {
    cat <<EOF
HYPE CLI - Helmfile Wrapper Tool for Kubernetes AI Deployments

Usage:
  hype <hype-name> <command> [options...]                       Run builtin command
  hype upgrade                                                   Upgrade HYPE CLI to latest version
  hype --version                                                 Show version
  hype --help                                                    Show this help

Options:
  --version                Show version information
  --help                   Show help information

Available Commands:
EOF

    # Show builtin commands
    if [[ ${#BUILTIN_COMMANDS[@]} -gt 0 ]]; then
        for command in "${BUILTIN_COMMANDS[@]}"; do
            if [[ "$command" != "upgrade" ]]; then
                local help_func="${BUILTIN_HELP_FUNCTIONS[$command]:-}"
                if [[ -n "$help_func" ]] && declare -f "$help_func" > /dev/null; then
                    echo "  $command"
                    # Get brief description from help function if available
                    if declare -f "help_${command}_brief" > /dev/null; then
                        "help_${command}_brief" | sed 's/^/    /'
                    fi
                else
                    echo "  $command"
                fi
            fi
        done
    fi

    cat <<EOF

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
EOF
}

# Show help
show_help() {
    generate_dynamic_help
}

# Show version
show_version() {
    echo "HYPE CLI version $HYPE_VERSION"
}

# Main function
main() {
    # Load builtin metadata first
    load_builtin_metadata
    
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
            # Check for help option for upgrade command
            if [[ "${2:-}" == "--help" || "${2:-}" == "-h" || "${2:-}" == "help" ]]; then
                if declare -f "help_upgrade" > /dev/null; then
                    help_upgrade
                else
                    echo "Usage: hype upgrade"
                    echo ""
                    echo "Upgrade HYPE CLI to latest version"
                fi
            else
                cmd_upgrade
            fi
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
            
            load_config "$hype_name" "$command"
            
            debug "Command: $command, Hype name: $hype_name, Args: $*"
            
            # Check dependencies for all commands except upgrade
            if [[ "$command" != "upgrade" ]]; then
                check_dependencies
            fi
            
            # Execute builtin command dynamically
            execute_builtin_command "$command" "$hype_name" "$@"
            ;;
    esac
}

# Execute main function with all arguments
main "$@"