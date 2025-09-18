#!/bin/bash

# HYPE CLI Repository Plugin
# Handles repository binding, unbinding, and management operations

# Builtin metadata (standardized)
BUILTIN_NAME="repo"
BUILTIN_VERSION="1.0.0"
BUILTIN_DESCRIPTION="Repository binding and management builtin"

# Register commands in global BUILTIN_COMMANDS array
BUILTIN_COMMANDS+=("repo")

# Help functions
help_repo() {
    cat <<EOF
Usage: hype <hype-name> repo [SUBCOMMAND]

Repository binding operations

Subcommands:
  bind <url>      Bind repository to hype name
  unbind          Unbind repository from hype name
  update          Update repository binding
  validate <url>  Validate repository binding matches specification
  info            Show repository binding information
  list            List all repository bindings

Examples:
  hype my-nginx repo bind user/repo                              Bind repository (shorthand)
  hype my-nginx repo bind https://github.com/user/repo.git      Bind repository (full URL)
  hype my-nginx repo info                                        Show binding info
  hype my-nginx repo unbind                                      Remove binding
EOF
}

help_repo_brief() {
    echo "Repository binding operations"
}

# Plugin initialization function
plugin_repo_init() {
    debug "Plugin $PLUGIN_NAME initialized"
}

# Main command function
# Called when the user runs: hype <name> repo <subcommand>
cmd_repo() {
    local hype_name="$1"
    local subcommand="${2:-}"
    shift 1  # Remove hype_name from arguments
    if [[ -n "$subcommand" ]]; then
        shift 1  # Remove subcommand if it exists
    fi
    
    case "$subcommand" in
        "bind")
            cmd_repo_bind "$hype_name" "$@"
            ;;
        "unbind")
            cmd_repo_unbind "$hype_name" "$@"
            ;;
        "update")
            cmd_repo_update "$hype_name" "$@"
            ;;
        "validate")
            cmd_repo_validate "$hype_name" "$@"
            ;;
        "list")
            cmd_repo_list
            ;;
        ""|"info")
            cmd_repo_info "$hype_name" "$@"
            ;;
        "help"|"-h"|"--help")
            show_repo_help
            ;;
        *)
            error "Unknown repo subcommand: $subcommand"
            show_repo_help
            exit 1
            ;;
    esac
}

# Bind repository to hype name
cmd_repo_bind() {
    local hype_name="$1"
    shift  # Remove hype_name from arguments
    local repo_url=""
    local branch=""
    local path=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --branch)
                branch="$2"
                shift 2
                ;;
            --path)
                path="$2"
                shift 2
                ;;
            *)
                if [[ -z "$repo_url" ]]; then
                    repo_url="$1"
                else
                    error "Unknown argument: $1"
                    show_repo_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    if [[ -z "$hype_name" ]]; then
        error "Hype name is required"
        show_repo_help
        exit 1
    fi
    
    if [[ -z "$repo_url" ]]; then
        error "Repository URL is required"
        show_repo_help
        exit 1
    fi
    
    # Set defaults
    branch="${branch:-main}"
    path="${path:-.}"
    
    # Expand GitHub shorthand if applicable
    local original_url="$repo_url"
    repo_url=$(expand_github_shorthand "$repo_url")
    
    # Show expansion if shorthand was used
    if [[ "$original_url" != "$repo_url" ]]; then
        info "Expanding GitHub shorthand: $original_url -> $repo_url"
    fi
    
    # Validate repository URL
    if ! validate_repo_url "$original_url"; then
        error "Invalid repository URL: $original_url"
        error "Supported formats:"
        error "  - user/repo (GitHub shorthand)"
        error "  - https://github.com/user/repo"
        error "  - https://github.com/user/repo.git"
        error "  - git@github.com:user/repo.git"
        exit 1
    fi
    
    info "Binding repository to hype name '$hype_name'"
    info "Repository: $repo_url"
    info "Branch: $branch"
    info "Path: $path"
    
    # Store binding in ConfigMap
    if store_repo_binding "$hype_name" "$repo_url" "$branch" "$path"; then
        # Clone repository to cache
        local cache_dir
        cache_dir=$(get_repo_cache_dir "$hype_name")
        
        info "Caching repository..."
        if clone_repo_to_cache "$repo_url" "$branch" "$cache_dir"; then
            info "Repository binding completed successfully"
        else
            warn "Repository binding saved, but caching failed"
            warn "You can update the cache later with: hype $hype_name repo update"
        fi
    else
        error "Failed to bind repository"
        exit 1
    fi
}

# Unbind repository from hype name
cmd_repo_unbind() {
    local hype_name="$1"
    
    if [[ -z "$hype_name" ]]; then
        error "Hype name is required"
        show_repo_help
        exit 1
    fi
    
    # Check if binding exists
    if ! has_repo_binding "$hype_name"; then
        warn "No repository binding found for '$hype_name'"
        exit 1
    fi
    
    info "Removing repository binding for '$hype_name'"
    
    # Remove binding from ConfigMap
    if remove_repo_binding "$hype_name"; then
        # Optionally remove cache
        local cache_dir
        cache_dir=$(get_repo_cache_dir "$hype_name")
        
        if [[ -d "$cache_dir" ]]; then
            info "Removing repository cache..."
            remove_repo_cache "$cache_dir"
        fi
        
        info "Repository unbinding completed successfully"
    else
        error "Failed to unbind repository"
        exit 1
    fi
}

# Validate repository binding matches specification
cmd_repo_validate() {
    local hype_name="$1"
    shift  # Remove hype_name from arguments
    local repo_url=""
    local branch=""
    local path=""
    
    # Parse arguments (same as bind command)
    while [[ $# -gt 0 ]]; do
        case $1 in
            --branch)
                branch="$2"
                shift 2
                ;;
            --path)
                path="$2"
                shift 2
                ;;
            *)
                if [[ -z "$repo_url" ]]; then
                    repo_url="$1"
                else
                    error "Unknown argument: $1"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    if [[ -z "$hype_name" ]]; then
        exit 1
    fi
    
    if [[ -z "$repo_url" ]]; then
        exit 1
    fi
    
    # Set defaults (same as bind command)
    branch="${branch:-main}"
    path="${path:-.}"
    
    # Expand GitHub shorthand if applicable
    repo_url=$(expand_github_shorthand "$repo_url")
    
    # Get current repository binding
    local binding_data
    if ! binding_data=$(get_repo_binding "$hype_name"); then
        # No binding exists
        exit 1
    fi
    
    # Parse current binding data
    # shellcheck disable=SC2034
    eval "$binding_data"  # Sets REPO_URL, REPO_BRANCH, REPO_PATH variables
    
    # Compare specified parameters with current binding
    # shellcheck disable=SC2153
    if [[ "$repo_url" == "$REPO_URL" ]] && \
       [[ "$branch" == "$REPO_BRANCH" ]] && \
       [[ "$path" == "$REPO_PATH" ]]; then
        # Binding matches
        exit 0
    else
        # Binding does not match
        exit 1
    fi
}

# Update repository cache
cmd_repo_update() {
    local hype_name="$1"
    
    if [[ -z "$hype_name" ]]; then
        error "Hype name is required"
        show_repo_help
        exit 1
    fi
    
    # Get repository binding
    local binding_data
    if ! binding_data=$(get_repo_binding "$hype_name"); then
        error "No repository binding found for '$hype_name'"
        error "Use 'hype $hype_name repo bind <url>' to bind a repository first"
        exit 1
    fi
    
    # Parse binding data
    # shellcheck disable=SC2034
    eval "$binding_data"  # Sets REPO_URL, REPO_BRANCH, REPO_PATH variables
    
    local cache_dir
    cache_dir=$(get_repo_cache_dir "$hype_name")
    
    info "Updating repository cache for '$hype_name'"
    # shellcheck disable=SC2153
    info "Repository: $REPO_URL"
    # shellcheck disable=SC2153
    info "Branch: $REPO_BRANCH"
    
    # Check if cache exists and is valid
    if is_valid_cache "$cache_dir"; then
        # Update existing cache
        if update_repo_cache "$cache_dir" "$REPO_BRANCH"; then
            info "Repository cache updated successfully"
        else
            warn "Cache update failed, re-cloning repository"
            if clone_repo_to_cache "$REPO_URL" "$REPO_BRANCH" "$cache_dir"; then
                info "Repository re-cached successfully"
            else
                error "Failed to update repository cache"
                exit 1
            fi
        fi
    else
        # Clone fresh cache
        info "Cloning repository cache..."
        if clone_repo_to_cache "$REPO_URL" "$REPO_BRANCH" "$cache_dir"; then
            info "Repository cached successfully"
        else
            error "Failed to cache repository"
            exit 1
        fi
    fi
}

# Show repository binding information
cmd_repo_info() {
    local hype_name="$1"
    local configmap_name
    configmap_name=$(get_repo_configmap_name "$hype_name")
    
    if [[ -z "$hype_name" ]]; then
        error "Hype name is required"
        show_repo_help
        exit 1
    fi
    
    # Check if binding exists
    if has_repo_binding "$hype_name"; then
        info "Repository binding information for '$hype_name':"
        echo "  ConfigMap: $configmap_name"
        
        # Get individual fields
        local url branch path bound_at last_updated
        url=$(kubectl get configmap "$configmap_name" -o jsonpath='{.data.url}' 2>/dev/null)
        branch=$(kubectl get configmap "$configmap_name" -o jsonpath='{.data.branch}' 2>/dev/null)
        path=$(kubectl get configmap "$configmap_name" -o jsonpath='{.data.path}' 2>/dev/null)
        bound_at=$(kubectl get configmap "$configmap_name" -o jsonpath='{.data.bound_at}' 2>/dev/null)
        last_updated=$(kubectl get configmap "$configmap_name" -o jsonpath='{.data.last_updated}' 2>/dev/null)
        
        echo "  Repository URL: $url"
        echo "  Branch: ${branch:-main}"
        echo "  Path: ${path:-.}"
        [[ -n "$bound_at" ]] && echo "  Bound at: $bound_at"
        [[ -n "$last_updated" ]] && echo "  Last updated: $last_updated"
        
    else
        info "No repository binding found for '$hype_name'"
        info "This hype name is using local configuration only."
        info ""
        info "To bind a repository, use:"
        info "  hype $hype_name repo bind <repository-url>"
        return 0
    fi
    
    # Check cache status
    local cache_dir
    cache_dir=$(get_repo_cache_dir "$hype_name")
    
    echo ""
    if is_valid_cache "$cache_dir"; then
        info "Cache status: Available"
        echo "  Cache directory: $cache_dir"
        
        # Show repository status
        local status
        if status=$(get_repo_status "$cache_dir"); then
            echo ""
            echo "Repository status:"
            while IFS= read -r line; do
                echo "  $line"
            done <<< "$status"
        fi
    else
        warn "Cache status: Missing or invalid"
        info "Run 'hype $hype_name repo update' to update the cache"
    fi
}


# List all repository bindings
cmd_repo_list() {
    info "Repository bindings:"
    echo ""
    
    if ! list_repo_bindings; then
        warn "No repository bindings found"
        info "Use 'hype <name> repo bind <url>' to create bindings"
    fi
}

# Help function for repo plugin
show_repo_help() {
    cat << 'EOF'
Usage: hype <name> repo [COMMAND] [OPTIONS]

Repository binding and management commands

Commands:
  bind <url> [--branch <branch>] [--path <path>]
                        Bind repository to hype name
  unbind                Remove repository binding
  update                Update repository cache
  validate <url> [--branch <branch>] [--path <path>]
                        Validate repository binding matches specification
  info                  Show binding information (default)
  list                  List all repository bindings
  help, -h, --help      Show this help message

Options:
  --branch <branch>     Specify branch (default: main)
  --path <path>         Specify path within repository (default: .)

Examples:
  # Bind a GitHub repository using shorthand
  hype myapp repo bind foontype/hype

  # Bind a GitHub repository with full URL
  hype myapp repo bind https://github.com/user/repo.git

  # Bind with specific branch and path
  hype myapp repo bind user/repo --branch develop --path deploy

  # Validate repository binding
  hype myapp repo validate user/repo --branch develop --path deploy

  # Show binding information
  hype myapp repo

  # Update repository cache
  hype myapp repo update

  # List all repository bindings
  hype myapp repo list

  # Remove binding
  hype myapp repo unbind
EOF
}

# Plugin cleanup function
plugin_repo_cleanup() {
    debug "Plugin $PLUGIN_NAME cleaned up"
}