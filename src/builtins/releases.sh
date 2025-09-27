#!/bin/bash

# HYPE CLI Releases Builtin
# 
# This builtin provides release management capabilities for HYPE components

# Builtin metadata (required)
BUILTIN_NAME="releases"
BUILTIN_VERSION="1.0.0"
BUILTIN_DESCRIPTION="Releases builtin for HYPE CLI"
# Note: releases command is now registered in aliases.sh

# Builtin initialization function (optional)
builtin_releases_init() {
    debug "Builtin $BUILTIN_NAME initialized"
}

# Check if helm release exists (regardless of status)
check_helm_release_exists() {
    local release_name="$1"
    
    debug "Checking if helm release exists: $release_name"
    
    # Use helm list with filter to check if release exists
    local result
    if result=$(helm list --filter="^${release_name}$" --short 2>/dev/null) && [[ -n "$result" ]]; then
        debug "Helm release found: $release_name"
        return 0
    else
        debug "Helm release not found: $release_name"
        return 1
    fi
}

# Check command - check if all releases in releases list exist
cmd_releases_check() {
    local hype_name="$1"
    
    debug "Checking releases for hype: $hype_name"
    
    # Parse hypefile to get access to hype section
    parse_hypefile "$hype_name"
    
    # Get releases list
    local release_list
    if ! release_list=$(get_releases_list); then
        error "Failed to get releases list from hypefile"
        return 1
    fi
    
    # Check if release list is empty
    if [[ -z "$release_list" ]]; then
        info "No releases to check - releases list is empty"
        return 0
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
        return 0
    else
        error "Missing releases: ${failed_releases[*]}"
        return 1
    fi
}

# Main command function
cmd_releases() {
    local hype_name="$1"
    local subcommand="${2:-}"
    shift 2
    
    case "$subcommand" in
        "check")
            cmd_releases_check "$hype_name" "$@"
            ;;
        "help"|"-h"|"--help"|"")
            help_releases
            ;;
        *)
            error "Unknown releases subcommand: $subcommand"
            help_releases
            return 1
            ;;
    esac
}

# Help function for this builtin
help_releases_builtin() {
    cat << EOF
Usage: hype <hype-name> releases <subcommand> [options...]

Releases builtin for HYPE CLI - manage and check status of releases

Subcommands:
  check                   Check if all releases in releases list exist
  help, -h, --help       Show this help message

Examples:
  hype my-hype releases check     Check if all releases are present
  hype my-hype releases help      Show this help

The 'check' subcommand checks if all helm releases listed in the 
hypefile.yaml releases section exist, regardless of their status.
Returns exit code 0 if all releases exist, 1 if any are missing.
EOF
}

# Brief help for main help display
help_releases_brief() {
    echo "Manage and check status of HYPE releases"
}

# Builtin cleanup function (optional)
builtin_releases_cleanup() {
    debug "Builtin $BUILTIN_NAME cleaned up"
}