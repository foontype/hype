#!/bin/bash

# HYPE Repository Management Module
# Provides repository binding, cloning, and working directory management

set -euo pipefail

# Constants
readonly HYPE_REPOS_BASE_DIR="/tmp/hype-repos"
readonly HYPE_CONFIGMAP_NAME="hype-repository-config"
readonly DEFAULT_BRANCH="main"

# Ensure repositories base directory exists
ensure_repos_dir() {
    if [[ ! -d "$HYPE_REPOS_BASE_DIR" ]]; then
        mkdir -p "$HYPE_REPOS_BASE_DIR"
        debug "Created repositories base directory: $HYPE_REPOS_BASE_DIR"
    fi
}

# Get current kubectl namespace
get_current_namespace() {
    kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null || echo "default"
}

# Check if ConfigMap exists
configmap_exists() {
    local namespace
    namespace=$(get_current_namespace)
    kubectl get configmap "$HYPE_CONFIGMAP_NAME" -n "$namespace" >/dev/null 2>&1
}

# Create empty ConfigMap if it doesn't exist
ensure_configmap() {
    if ! configmap_exists; then
        local namespace
        namespace=$(get_current_namespace)
        kubectl create configmap "$HYPE_CONFIGMAP_NAME" -n "$namespace"
        debug "Created ConfigMap: $HYPE_CONFIGMAP_NAME in namespace: $namespace"
    fi
}

# Get repository binding for hype name
get_repo_binding() {
    local hype_name="$1"
    local namespace
    namespace=$(get_current_namespace)
    
    if ! configmap_exists; then
        echo ""
        return
    fi
    
    kubectl get configmap "$HYPE_CONFIGMAP_NAME" -n "$namespace" -o jsonpath="{.data['$hype_name']}" 2>/dev/null || echo ""
}

# Set repository binding for hype name
set_repo_binding() {
    local hype_name="$1"
    local repository="$2"
    local branch="${3:-$DEFAULT_BRANCH}"
    local path="${4:-}"
    local namespace
    
    namespace=$(get_current_namespace)
    ensure_configmap
    
    local binding_json
    binding_json=$(jq -n -c \
        --arg repo "$repository" \
        --arg branch "$branch" \
        --arg path "$path" \
        '{repository: $repo, branch: $branch, path: $path}')
    
    kubectl patch configmap "$HYPE_CONFIGMAP_NAME" -n "$namespace" \
        --patch "{\"data\":{\"$hype_name\":\"$binding_json\"}}"
    
    debug "Set repository binding for $hype_name: $repository (branch: $branch, path: $path)"
}

# Remove repository binding for hype name
remove_repo_binding() {
    local hype_name="$1"
    local namespace
    
    namespace=$(get_current_namespace)
    
    if ! configmap_exists; then
        return
    fi
    
    kubectl patch configmap "$HYPE_CONFIGMAP_NAME" -n "$namespace" \
        --patch "{\"data\":{\"$hype_name\":null}}"
    
    debug "Removed repository binding for $hype_name"
}

# Parse repository binding JSON
parse_binding() {
    local binding_json="$1"
    local field="$2"
    
    if [[ -z "$binding_json" ]]; then
        echo ""
        return
    fi
    
    echo "$binding_json" | jq -r ".$field // \"\"" 2>/dev/null || echo ""
}

# Get repository name from URL
get_repo_name() {
    local repository="$1"
    basename "$repository" .git
}

# Get working directory for hype name
get_working_directory() {
    local hype_name="$1"
    local binding
    local repository
    local branch
    local path
    local repo_name
    local work_dir
    
    binding=$(get_repo_binding "$hype_name")
    
    if [[ -z "$binding" ]]; then
        pwd
        return
    fi
    
    repository=$(parse_binding "$binding" "repository")
    branch=$(parse_binding "$binding" "branch")
    path=$(parse_binding "$binding" "path")
    
    if [[ -z "$repository" ]]; then
        pwd
        return
    fi
    
    repo_name=$(get_repo_name "$repository")
    work_dir="$HYPE_REPOS_BASE_DIR/$hype_name/$repo_name/$branch"
    
    if [[ -n "$path" ]]; then
        work_dir="$work_dir/$path"
    fi
    
    echo "$work_dir"
}

# Check if repository is accessible
validate_repository() {
    local repository="$1"
    
    if [[ "$repository" == "." ]]; then
        return 0
    fi
    
    git ls-remote "$repository" >/dev/null 2>&1
}

# Clone or update repository
sync_repository() {
    local hype_name="$1"
    local binding
    local repository
    local branch
    local path
    local repo_name
    local clone_dir
    local branch_dir
    
    binding=$(get_repo_binding "$hype_name")
    
    if [[ -z "$binding" ]]; then
        error "No repository binding found for $hype_name"
        exit 12
    fi
    
    repository=$(parse_binding "$binding" "repository")
    branch=$(parse_binding "$binding" "branch")
    path=$(parse_binding "$binding" "path")
    
    if [[ -z "$repository" ]]; then
        error "No repository specified in binding for $hype_name"
        exit 12
    fi
    
    repo_name=$(get_repo_name "$repository")
    clone_dir="$HYPE_REPOS_BASE_DIR/$hype_name/$repo_name"
    branch_dir="$clone_dir/$branch"
    
    ensure_repos_dir
    
    if [[ ! -d "$clone_dir/.git" ]]; then
        info "Cloning repository: $repository"
        git clone "$repository" "$clone_dir"
    else
        info "Repository already cloned: $repository"
    fi
    
    # Create or update branch-specific working directory
    if [[ ! -d "$branch_dir" ]]; then
        mkdir -p "$branch_dir"
        debug "Created branch directory: $branch_dir"
    fi
    
    # Copy repository contents to branch-specific directory
    (
		# NOTE: 'cd' need to keep single bash session for multiple comands.
        #.      This is some Coding Agent restriction.
        cd "$clone_dir" \
          && git fetch origin \
          && git checkout "$branch" 2>/dev/null || git checkout -b "$branch" "origin/$branch" \
          && git pull origin "$branch" \
          && rsync -av --exclude='.git' ./ "$branch_dir/"
    )
    
    # Validate path exists if specified
    if [[ -n "$path" ]]; then
        local full_path="$branch_dir/$path"
        if [[ ! -d "$full_path" ]]; then
            error "Specified path does not exist: $path"
            exit 15
        fi
    fi
    
    info "Repository synced: $repository (branch: $branch)"
}

# List all repository bindings
list_repo_bindings() {
    local namespace
    local bindings
    local hype_name
    local binding_json
    local repository
    local branch
    local path
    local status
    local work_dir
    
    namespace=$(get_current_namespace)
    
    if ! configmap_exists; then
        echo "No repository bindings found."
        return
    fi
    
    echo "HYPE NAME          REPOSITORY                     BRANCH    PATH              STATUS"
    echo "----------------   ----------------------------   -------   ---------------   ------------"
    
    bindings=$(kubectl get configmap "$HYPE_CONFIGMAP_NAME" -n "$namespace" -o json 2>/dev/null | jq -r '.data // {} | to_entries[] | .key + "|" + .value')
    
    while IFS='|' read -r hype_name binding_json; do
        if [[ -z "$binding_json" || "$binding_json" == "null" ]]; then
            printf "%-16s   %-28s   %-7s   %-15s   %s\n" "$hype_name" "." "." "." "current-dir"
            continue
        fi
        
        repository=$(parse_binding "$binding_json" "repository")
        branch=$(parse_binding "$binding_json" "branch")
        path=$(parse_binding "$binding_json" "path")
        
        work_dir=$(get_working_directory "$hype_name")
        
        if [[ -d "$work_dir" ]]; then
            status="cloned"
        else
            status="not-cloned"
        fi
        
        # Truncate long values for display
        local display_repo="${repository:0:28}"
        local display_branch="${branch:0:7}"
        local display_path="${path:0:15}"
        
        printf "%-16s   %-28s   %-7s   %-15s   %s\n" "$hype_name" "$display_repo" "$display_branch" "$display_path" "$status"
    done <<< "$bindings"
}

# Update all repositories
update_all_repositories() {
    local namespace
    local bindings
    local hype_name
    local binding_json
    local repository
    local updated_count=0
    local failed_count=0
    
    namespace=$(get_current_namespace)
    
    if ! configmap_exists; then
        info "No repository bindings found."
        return
    fi
    
    info "Updating all bound repositories..."
    
    bindings=$(kubectl get configmap "$HYPE_CONFIGMAP_NAME" -n "$namespace" -o json 2>/dev/null | jq -r '.data // {} | to_entries[] | .key + "|" + .value')
    
    while IFS='|' read -r hype_name binding_json; do
        if [[ -z "$binding_json" || "$binding_json" == "null" ]]; then
            continue
        fi
        
        repository=$(parse_binding "$binding_json" "repository")
        
        if [[ -z "$repository" ]]; then
            continue
        fi
        
        info "Updating repository for $hype_name..."
        
        if sync_repository "$hype_name"; then
            ((updated_count++))
        else
            error "Failed to update repository for $hype_name"
            ((failed_count++))
        fi
    done <<< "$bindings"
    
    info "Update complete. Updated: $updated_count, Failed: $failed_count"
}

# Command: use repo
cmd_use_repo() {
    local hype_name="$1"
    shift
    
    local repository=""
    local branch="$DEFAULT_BRANCH"
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
                if [[ -z "$repository" ]]; then
                    repository="$1"
                    shift
                else
                    error "Unexpected argument: $1"
                    exit 1
                fi
                ;;
        esac
    done
    
    if [[ -z "$repository" ]]; then
        error "Repository URL is required"
        exit 1
    fi
    
    info "Validating repository access: $repository"
    if ! validate_repository "$repository"; then
        error "Repository not accessible: $repository"
        exit 10
    fi
    
    set_repo_binding "$hype_name" "$repository" "$branch" "$path"
    sync_repository "$hype_name"
    
    info "Repository bound to $hype_name: $repository (branch: $branch, path: $path)"
}

# Command: unuse
cmd_unuse() {
    local hype_name="$1"
    local binding
    local work_dir
    
    binding=$(get_repo_binding "$hype_name")
    
    if [[ -z "$binding" ]]; then
        warn "No repository binding found for $hype_name"
        return
    fi
    
    work_dir=$(get_working_directory "$hype_name")
    
    if [[ -d "$work_dir" ]]; then
        echo -n "Remove working directory $work_dir? [y/N] "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            rm -rf "$work_dir"
            info "Removed working directory: $work_dir"
        fi
    fi
    
    remove_repo_binding "$hype_name"
    info "Repository unbound from $hype_name"
}

# Command: list
cmd_list_repos() {
    list_repo_bindings
}

# Command: update
cmd_update_repos() {
    update_all_repositories
}

# Execute command in working directory
exec_in_work_dir() {
    local work_dir="$1"
    shift
    
    if [[ ! -d "$work_dir" ]]; then
        error "Working directory does not exist: $work_dir"
        return 1
    fi
    
    debug "Executing command in working directory: $work_dir"
    (cd "$work_dir" && "$@")
}

# Execute multiple commands in working directory with bash -c
exec_commands_in_work_dir() {
    local work_dir="$1"
    local command_string="$2"
    
    if [[ ! -d "$work_dir" ]]; then
        error "Working directory does not exist: $work_dir"
        return 1
    fi
    
    debug "Executing commands in working directory: $work_dir"
    (cd "$work_dir" && bash -c "$command_string")
}

# Get current working directory for hype name (replaces change_to_working_directory)
get_work_dir_for_hype() {
    local hype_name="$1"
    local work_dir
    
    work_dir=$(get_working_directory "$hype_name")
    
    if [[ "$work_dir" != "$(pwd)" ]]; then
        if [[ ! -d "$work_dir" ]]; then
            # Try to sync repository if working directory doesn't exist
            local binding
            binding=$(get_repo_binding "$hype_name")
            if [[ -n "$binding" ]]; then
                sync_repository "$hype_name"
            fi
        fi
        
        if [[ -d "$work_dir" ]]; then
            debug "Working directory available: $work_dir"
            echo "$work_dir"
        else
            warn "Working directory does not exist: $work_dir"
            pwd
        fi
    else
        echo "$work_dir"
    fi
}

# Legacy function for backward compatibility - now uses wrapper functions
change_to_working_directory() {
    local hype_name="$1"
    local work_dir
    
    work_dir=$(get_work_dir_for_hype "$hype_name")
    debug "Working directory for $hype_name: $work_dir"
}