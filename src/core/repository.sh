#!/bin/bash

# HYPE CLI Repository Management Core Module
# Handles repository binding, working directory management, and ConfigMap operations

set -euo pipefail

# Constants
readonly HYPE_CONFIGMAP_NAME="hype-repository-config"
readonly HYPE_REPOS_DIR="/tmp/hype-repos"

# Get current kubectl namespace
get_current_namespace() {
    kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null || echo "default"
}

# Create ConfigMap if it doesn't exist
ensure_configmap_exists() {
    local namespace
    namespace=$(get_current_namespace)
    
    if ! kubectl get configmap "$HYPE_CONFIGMAP_NAME" -n "$namespace" >/dev/null 2>&1; then
        debug "Creating ConfigMap $HYPE_CONFIGMAP_NAME in namespace $namespace"
        kubectl create configmap "$HYPE_CONFIGMAP_NAME" -n "$namespace" --dry-run=client -o yaml | kubectl apply -f -
    fi
}

# Get repository binding for a hype name
get_repository_binding() {
    local hype_name="$1"
    local namespace
    namespace=$(get_current_namespace)
    
    ensure_configmap_exists
    
    local binding
    binding=$(kubectl get configmap "$HYPE_CONFIGMAP_NAME" -n "$namespace" -o jsonpath="{.data.$hype_name}" 2>/dev/null || echo "")
    
    if [[ -n "$binding" ]]; then
        echo "$binding"
    fi
}

# Set repository binding for a hype name
set_repository_binding() {
    local hype_name="$1"
    local repository="$2"
    local branch="${3:-}"
    local path="${4:-}"
    local namespace
    namespace=$(get_current_namespace)
    
    ensure_configmap_exists
    
    # If no branch specified, try to detect default branch
    if [[ -z "$branch" ]]; then
        branch=$(get_default_branch "$repository" || echo "main")
    fi
    
    # Default path is root directory
    if [[ -z "$path" ]]; then
        path="."
    fi
    
    local binding_json
    binding_json=$(printf '{"repository": "%s", "branch": "%s", "path": "%s"}' "$repository" "$branch" "$path")
    
    debug "Setting repository binding: $hype_name -> $binding_json"
    kubectl patch configmap "$HYPE_CONFIGMAP_NAME" -n "$namespace" --patch "{\"data\":{\"$hype_name\":\"$binding_json\"}}"
}

# Remove repository binding for a hype name
remove_repository_binding() {
    local hype_name="$1"
    local namespace
    namespace=$(get_current_namespace)
    
    ensure_configmap_exists
    
    debug "Removing repository binding for $hype_name"
    kubectl patch configmap "$HYPE_CONFIGMAP_NAME" -n "$namespace" --patch "{\"data\":{\"$hype_name\":null}}"
}

# Get all repository bindings
get_all_bindings() {
    local namespace
    namespace=$(get_current_namespace)
    
    ensure_configmap_exists
    
    kubectl get configmap "$HYPE_CONFIGMAP_NAME" -n "$namespace" -o json | jq -r '.data // {} | to_entries[] | "\(.key)=\(.value)"'
}

# Parse repository binding JSON
parse_binding() {
    local binding="$1"
    local field="$2"
    
    if [[ -n "$binding" ]] && [[ "$binding" != "null" ]]; then
        echo "$binding" | jq -r ".$field // empty"
    fi
}

# Get default branch of a repository
get_default_branch() {
    local repository="$1"
    
    # Try to get default branch using git ls-remote
    git ls-remote --symref "$repository" HEAD 2>/dev/null | \
        awk '/^ref: refs\/heads\// {sub(/^ref: refs\/heads\//, ""); print; exit}' || \
        echo "main"
}

# Get working directory for a hype name
get_working_directory() {
    local hype_name="$1"
    
    local binding
    binding=$(get_repository_binding "$hype_name")
    
    if [[ -z "$binding" ]]; then
        # No binding, use current directory
        pwd
        return
    fi
    
    local repository branch repo_name path
    repository=$(parse_binding "$binding" "repository")
    branch=$(parse_binding "$binding" "branch")
    path=$(parse_binding "$binding" "path")
    
    if [[ -z "$repository" ]]; then
        # Invalid binding, use current directory
        pwd
        return
    fi
    
    # Extract repository name from URL
    repo_name=$(basename "$repository" .git)
    
    # Default path is root directory
    if [[ -z "$path" ]] || [[ "$path" == "." ]]; then
        echo "$HYPE_REPOS_DIR/$hype_name/$repo_name/$branch"
    else
        echo "$HYPE_REPOS_DIR/$hype_name/$repo_name/$branch/$path"
    fi
}

# Ensure working directory exists and is up to date
ensure_working_directory() {
    local hype_name="$1"
    
    local binding
    binding=$(get_repository_binding "$hype_name")
    
    if [[ -z "$binding" ]]; then
        # No binding, nothing to do
        return 0
    fi
    
    local repository branch repo_name path base_work_dir work_dir
    repository=$(parse_binding "$binding" "repository")
    branch=$(parse_binding "$binding" "branch")
    path=$(parse_binding "$binding" "path")
    
    if [[ -z "$repository" ]]; then
        error "Invalid repository binding for $hype_name"
        return 1
    fi
    
    repo_name=$(basename "$repository" .git)
    base_work_dir="$HYPE_REPOS_DIR/$hype_name/$repo_name/$branch"
    
    # Create base directory
    mkdir -p "$HYPE_REPOS_DIR/$hype_name"
    
    # Clone or update repository
    if [[ -d "$base_work_dir" ]]; then
        debug "Updating repository in $base_work_dir"
        (
            cd "$base_work_dir"
            git fetch origin
            git reset --hard "origin/$branch"
        )
    else
        debug "Cloning repository $repository to $base_work_dir"
        git clone "$repository" "$base_work_dir"
        (
            cd "$base_work_dir"
            git checkout "$branch" || git checkout -b "$branch" "origin/$branch"
        )
    fi
    
    # Create path subdirectory if specified and doesn't exist
    if [[ -n "$path" ]] && [[ "$path" != "." ]]; then
        work_dir="$base_work_dir/$path"
        if [[ ! -d "$work_dir" ]]; then
            debug "Creating path directory: $work_dir"
            mkdir -p "$work_dir"
        fi
    fi
}

# Change to working directory for a hype name
change_to_working_directory() {
    local hype_name="$1"
    
    local work_dir
    work_dir=$(get_working_directory "$hype_name")
    
    # If it's a repository binding, ensure it's up to date
    local binding
    binding=$(get_repository_binding "$hype_name")
    if [[ -n "$binding" ]]; then
        ensure_working_directory "$hype_name"
    fi
    
    debug "Changing to working directory: $work_dir"
    cd "$work_dir"
}

# Check if directory exists
directory_exists() {
    local hype_name="$1"
    
    local binding
    binding=$(get_repository_binding "$hype_name")
    
    if [[ -z "$binding" ]]; then
        echo "current-dir"
        return 0
    fi
    
    local work_dir
    work_dir=$(get_working_directory "$hype_name")
    
    if [[ -d "$work_dir" ]]; then
        echo "cloned"
    else
        echo "not-cloned"
    fi
}

# Remove working directory
remove_working_directory() {
    local hype_name="$1"
    
    local work_dir
    work_dir=$(get_working_directory "$hype_name")
    
    if [[ "$work_dir" != "$(pwd)" ]] && [[ -d "$work_dir" ]]; then
        debug "Removing working directory: $work_dir"
        rm -rf "$work_dir"
        
        # Remove parent directories if empty
        local parent_dir
        parent_dir=$(dirname "$work_dir")
        while [[ "$parent_dir" != "$HYPE_REPOS_DIR" ]] && [[ -d "$parent_dir" ]] && [[ -z "$(ls -A "$parent_dir" 2>/dev/null)" ]]; do
            rmdir "$parent_dir"
            parent_dir=$(dirname "$parent_dir")
        done
    fi
}

# Validate repository accessibility
validate_repository() {
    local repository="$1"
    
    debug "Validating repository accessibility: $repository"
    
    # Check if we can access the repository
    if ! git ls-remote "$repository" HEAD >/dev/null 2>&1; then
        return 1
    fi
    
    return 0
}