#!/bin/bash

# HYPE CLI Main Entry Point
# Plugin discovery and command routing

# Show help
show_help() {
    cat <<EOF
HYPE CLI - Helmfile Wrapper Tool for Kubernetes AI Deployments

Usage:
  hype <hype-name> init                                          Create default resources
  hype <hype-name> deinit                                        Delete default resources  
  hype <hype-name> check                                         List default resources status
  hype <hype-name> template                                      Show rendered hype section YAML
  hype <hype-name> template state-values <configmap-name>        Show state-values file content
  hype <hype-name> parse section <hype|helmfile|taskfile>       Show raw section without headers
  hype <hype-name> trait                                         Show current trait
  hype <hype-name> trait set <trait-type>                       Set trait type
  hype <hype-name> trait unset                                   Remove trait
  hype <hype-name> task <task-name> [args...]                   Run task from taskfile section
  hype <hype-name> helmfile <helmfile-options>                  Run helmfile command
  hype upgrade                                                   Upgrade HYPE CLI to latest version
  hype --version                                                 Show version
  hype --help                                                    Show this help

Options:
  --version                Show version information
  --help                   Show help information

Environment Variables:
  HYPEFILE                 Path to hypefile.yaml (default: hypefile.yaml)
  DEBUG                    Enable debug output (default: false)
  TRACE                    Enable bash trace mode with set -x (default: false)
  HYPE_LOG                 Log output destination: false=no output, stdout=stdout (default), file=path to file

Task Variables (auto-set when running tasks):
  HYPE_NAME                Hype name passed to tasks
  HYPE_TRAIT               Current trait value (if set)
  HYPE_CURRENT_DIRECTORY   Current working directory

Examples:
  hype my-nginx init                                             Create resources for my-nginx
  hype my-nginx template                                         Show rendered YAML for my-nginx
  hype my-nginx template state-values my-nginx-state-values      Show state-values content
  hype my-nginx parse section hype                              Show raw hype section
  hype my-nginx parse section helmfile                          Show raw helmfile section
  hype my-nginx trait set production                             Set trait to production
  hype my-nginx task deploy                                      Run deploy task
  hype my-nginx helmfile sync                                    Sync with helmfile
EOF
}

# Show version
show_version() {
    echo "HYPE CLI version $HYPE_VERSION"
}

# Main function
main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 1
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
            
            debug "Command: $command, Hype name: $hype_name, Args: $*"
            
            case "$command" in
                "init")
                    check_dependencies
                    cmd_init "$hype_name"
                    ;;
                "deinit")
                    check_dependencies
                    cmd_deinit "$hype_name"
                    ;;
                "check")
                    check_dependencies
                    cmd_check "$hype_name"
                    ;;
                "template")
                    check_dependencies
                    cmd_template "$hype_name" "$@"
                    ;;
                "parse")
                    check_dependencies
                    cmd_parse "$hype_name" "$@"
                    ;;
                "trait")
                    check_dependencies
                    cmd_trait "$hype_name" "$@"
                    ;;
                "task")
                    check_dependencies
                    cmd_task "$hype_name" "$@"
                    ;;
                "helmfile")
                    check_dependencies
                    cmd_helmfile "$hype_name" "$@"
                    ;;
                *)
                    error "Unknown command: $command"
                    show_help
                    exit 1
                    ;;
            esac
            ;;
    esac
}

# Execute main function with all arguments
main "$@"