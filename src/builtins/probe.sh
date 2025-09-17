#!/bin/bash

# HYPE CLI Probe Builtin
# 
# This builtin provides probing capabilities for various HYPE components

# Builtin metadata (required)
BUILTIN_NAME="probe"
BUILTIN_VERSION="1.0.0"
BUILTIN_DESCRIPTION="Probe builtin for HYPE CLI"
BUILTIN_COMMANDS+=("probe")

# Builtin initialization function (optional)
builtin_probe_init() {
    debug "Builtin $BUILTIN_NAME initialized"
}

# Check if helm release exists (regardless of status)
check_helm_release_exists() {
    local release_name="$1"
    
    debug "Checking if helm release exists: $release_name"
    
    # Use helm list with filter to check if release exists
    if helm list --filter="^${release_name}$" --short --quiet >/dev/null 2>&1; then
        debug "Helm release found: $release_name"
        return 0
    else
        debug "Helm release not found: $release_name"
        return 1
    fi
}

# Probe release command - check if all releases in releaseProbe list exist
cmd_probe_release() {
    local hype_name="$1"
    
    debug "Probing releases for hype: $hype_name"
    
    # Parse hypefile to get access to hype section
    parse_hypefile "$hype_name"
    
    # Get release probe list
    local release_list
    if ! release_list=$(get_release_probe_list); then
        error "Failed to get release probe list from hypefile"
        exit 1
    fi
    
    # Check if release list is empty
    if [[ -z "$release_list" ]]; then
        info "No releases to probe - releaseProbe list is empty"
        exit 0
    fi
    
    # Check each release
    local failed_releases=()
    while IFS= read -r release_name; do
        if [[ -n "$release_name" ]]; then
            debug "Checking release: $release_name"
            if ! check_helm_release_exists "$release_name"; then
                failed_releases+=("$release_name")
            fi
        fi
    done <<< "$release_list"
    
    # Report results
    if [[ ${#failed_releases[@]} -eq 0 ]]; then
        info "All releases are present"
        exit 0
    else
        error "Missing releases: ${failed_releases[*]}"
        exit 1
    fi
}

# Main command function
cmd_probe() {
    local hype_name="$1"
    local subcommand="${2:-}"
    shift 2
    
    case "$subcommand" in
        "release")
            cmd_probe_release "$hype_name" "$@"
            ;;
        "help"|"-h"|"--help"|"")
            help_probe
            ;;
        *)
            error "Unknown probe subcommand: $subcommand"
            help_probe
            exit 1
            ;;
    esac
}

# Help function for this builtin
help_probe() {
    cat << EOF
Usage: hype <hype-name> probe <subcommand> [options...]

Probe builtin for HYPE CLI - check status of various components

Subcommands:
  release                 Check if all releases in releaseProbe list exist
  help, -h, --help       Show this help message

Examples:
  hype my-hype probe release      Check if all releases are present
  hype my-hype probe help         Show this help

The 'release' subcommand checks if all helm releases listed in the 
hypefile.yaml hype.releaseProbe section exist, regardless of their status.
Returns exit code 0 if all releases exist, 1 if any are missing.
EOF
}

# Brief help for main help display
help_probe_brief() {
    echo "Check status of various HYPE components"
}

# Builtin cleanup function (optional)
builtin_probe_cleanup() {
    debug "Builtin $BUILTIN_NAME cleaned up"
}