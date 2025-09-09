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
    local hype_name="${1:-}"
    local command="${2:-}"
    
    # For repo commands, we don't need a local hypefile
    if [[ "$command" == "repo" ]]; then
        # Set default cache directory for repo operations
        if [[ -z "${HYPE_CACHE_DIR:-}" ]]; then
            HYPE_CACHE_DIR="$HOME/.hype/cache"
            export HYPE_CACHE_DIR
            debug "Set HYPE_CACHE_DIR to global cache for repo operations: $HYPE_CACHE_DIR"
        fi
        return 0
    fi
    
    # First, try repository binding if hype_name is provided
    if [[ -n "$hype_name" ]]; then
        if setup_repo_workdir_if_bound "$hype_name"; then
            debug "Using repository working directory for $hype_name"
            return 0
        fi
    fi
    
    # Default configuration - try to find hypefile.yaml by searching upward
    if [[ -z "${HYPEFILE:-}" ]]; then
        if HYPEFILE=$(find_hypefile 2>/dev/null); then
            debug "Found hypefile at: $HYPEFILE"
        else
            echo "Error: hypefile.yaml not found in current or parent directories" >&2
            exit 1
        fi
    else
        debug "Using specified HYPEFILE: $HYPEFILE"
    fi

    # Verify hypefile exists and set HYPE_DIR
    if [[ -f "$HYPEFILE" ]]; then
        HYPE_DIR=$(dirname "$(realpath "$HYPEFILE")")
        export HYPE_DIR
        debug "Set HYPE_DIR to hypefile directory: $HYPE_DIR"
        
        # Set default HYPE_CACHE_DIR if not already defined
        if [[ -z "${HYPE_CACHE_DIR:-}" ]]; then
            HYPE_CACHE_DIR="${HYPE_DIR}/.hype"
            export HYPE_CACHE_DIR
            debug "Set HYPE_CACHE_DIR to default: $HYPE_CACHE_DIR"
        fi
    else
        echo "Error: hypefile not found at: $HYPEFILE" >&2
        exit 1
    fi
}

# Setup repository working directory if bound
setup_repo_workdir_if_bound() {
    local hype_name="$1"
    
    # Check if repository binding exists
    local binding_data
    if ! binding_data=$(get_repo_binding "$hype_name" 2>/dev/null); then
        debug "No repository binding found for '$hype_name'"
        return 1
    fi
    
    debug "Repository binding found for '$hype_name', setting up working directory"
    
    # Parse binding data
    local repo_info
    repo_info=$(parse_repo_binding "$binding_data")
    eval "$repo_info"  # Sets URL, BRANCH, PATH variables
    
    local cache_dir
    cache_dir=$(get_repo_cache_dir "$hype_name")
    
    # Ensure repository is cached
    if ! is_valid_cache "$cache_dir"; then
        info "Cloning repository for '$hype_name'..."
        if ! clone_repo_to_cache "$URL" "$BRANCH" "$cache_dir"; then
            warn "Failed to clone repository, falling back to current directory"
            return 1
        fi
    fi
    
    # Setup working directory
    local work_dir
    if ! work_dir=$(setup_repo_workdir "$cache_dir" "$PATH"); then
        warn "Failed to setup repository working directory, falling back to current directory"
        return 1
    fi
    
    # Change to repository working directory
    if ! cd "$work_dir"; then
        warn "Failed to change to repository working directory, falling back to current directory"
        return 1
    fi
    
    debug "Changed working directory to: $work_dir"
    
    # Find hypefile in repository
    if HYPEFILE=$(find_hypefile 2>/dev/null); then
        HYPE_DIR=$(dirname "$(realpath "$HYPEFILE")")
        export HYPE_DIR
        debug "Found hypefile in repository at: $HYPEFILE"
        debug "Set HYPE_DIR to: $HYPE_DIR"
        
        # Set HYPE_CACHE_DIR for repository context
        if [[ -z "${HYPE_CACHE_DIR:-}" ]]; then
            HYPE_CACHE_DIR="$HOME/.hype/cache"
            export HYPE_CACHE_DIR
            debug "Set HYPE_CACHE_DIR to global cache: $HYPE_CACHE_DIR"
        fi
        
        return 0
    else
        warn "No hypefile.yaml found in repository, falling back to current directory"
        return 1
    fi
}