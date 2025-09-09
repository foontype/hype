#!/bin/bash

# HYPE CLI Cache Management Module
# Functions for managing repository caches and Git operations

# Ensure cache directory exists
ensure_cache_dir() {
    local cache_dir="$1"
    
    if [[ ! -d "$cache_dir" ]]; then
        mkdir -p "$cache_dir" || {
            error "Failed to create cache directory: $cache_dir"
            return 1
        }
        debug "Created cache directory: $cache_dir"
    fi
    
    return 0
}

# Clone repository to cache directory
clone_repo_to_cache() {
    local url="$1"
    local branch="$2"
    local cache_dir="$3"
    
    debug "Cloning repository: $url (branch: $branch) to $cache_dir"
    
    # Remove existing cache if it exists
    if [[ -d "$cache_dir" ]]; then
        rm -rf "$cache_dir" || {
            error "Failed to remove existing cache directory: $cache_dir"
            return 1
        }
    fi
    
    # Create parent directory
    local parent_dir
    parent_dir=$(dirname "$cache_dir")
    ensure_cache_dir "$parent_dir" || return 1
    
    # Clone repository
    if ! git clone --quiet --branch "$branch" "$url" "$cache_dir" 2>/dev/null; then
        # Try cloning without specifying branch if branch-specific clone fails
        debug "Branch-specific clone failed, trying default branch"
        if ! git clone --quiet "$url" "$cache_dir" 2>/dev/null; then
            error "Failed to clone repository: $url"
            return 1
        fi
        
        # If default clone succeeded, try to checkout the specified branch
        if [[ "$branch" != "main" ]] && [[ "$branch" != "master" ]]; then
            (cd "$cache_dir" && git checkout --quiet "$branch" 2>/dev/null) || {
                warn "Failed to checkout branch '$branch', using default branch"
            }
        fi
    fi
    
    # Initialize and update submodules
    if (cd "$cache_dir" && git submodule update --init --recursive --quiet 2>/dev/null); then
        debug "Updated submodules in $cache_dir"
    else
        debug "No submodules found or submodule update failed"
    fi
    
    info "Repository cached successfully: $cache_dir"
    return 0
}

# Update existing repository cache
update_repo_cache() {
    local cache_dir="$1"
    local branch="$2"
    
    if [[ ! -d "$cache_dir" ]]; then
        error "Cache directory does not exist: $cache_dir"
        return 1
    fi
    
    if [[ ! -d "$cache_dir/.git" ]]; then
        error "Cache directory is not a Git repository: $cache_dir"
        return 1
    fi
    
    debug "Updating repository cache: $cache_dir"
    
    # Change to cache directory and update
    (
        cd "$cache_dir" || return 1
        
        # Fetch latest changes
        git fetch --quiet origin || {
            error "Failed to fetch from remote repository"
            return 1
        }
        
        # Reset to origin branch
        git reset --hard --quiet "origin/$branch" || {
            warn "Failed to reset to origin/$branch, trying to pull"
            git pull --quiet origin "$branch" || {
                error "Failed to update repository cache"
                return 1
            }
        }
        
        # Update submodules
        git submodule update --init --recursive --quiet 2>/dev/null || {
            debug "Submodule update failed or no submodules found"
        }
    )
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        info "Repository cache updated successfully: $cache_dir"
        return 0
    else
        return 1
    fi
}

# Check if cache directory is valid
is_valid_cache() {
    local cache_dir="$1"
    
    [[ -d "$cache_dir" ]] && [[ -d "$cache_dir/.git" ]]
}

# Get repository status from cache
get_repo_status() {
    local cache_dir="$1"
    
    if ! is_valid_cache "$cache_dir"; then
        return 1
    fi
    
    (
        cd "$cache_dir" || return 1
        
        local branch
        branch=$(git branch --show-current 2>/dev/null || echo "unknown")
        
        local remote_url
        remote_url=$(git remote get-url origin 2>/dev/null || echo "unknown")
        
        local last_commit
        last_commit=$(git log -1 --format="%h %s" 2>/dev/null || echo "unknown")
        
        echo "Branch: $branch"
        echo "Remote: $remote_url"
        echo "Last commit: $last_commit"
    )
}

# Remove repository cache
remove_repo_cache() {
    local cache_dir="$1"
    
    if [[ -d "$cache_dir" ]]; then
        rm -rf "$cache_dir" || {
            error "Failed to remove cache directory: $cache_dir"
            return 1
        }
        info "Repository cache removed: $cache_dir"
    else
        debug "Cache directory does not exist: $cache_dir"
    fi
    
    return 0
}

# Setup repository working directory
setup_repo_workdir() {
    local cache_dir="$1"
    local repo_path="$2"
    
    if [[ ! -d "$cache_dir" ]]; then
        error "Cache directory does not exist: $cache_dir"
        return 1
    fi
    
    local work_dir="$cache_dir"
    if [[ "$repo_path" != "." ]] && [[ -n "$repo_path" ]]; then
        work_dir="$cache_dir/$repo_path"
        if [[ ! -d "$work_dir" ]]; then
            error "Repository path does not exist: $repo_path"
            return 1
        fi
    fi
    
    debug "Repository working directory: $work_dir"
    echo "$work_dir"
    return 0
}

# Clean up old cache entries (optional maintenance function)
cleanup_old_caches() {
    local cache_base="${HYPE_CACHE_DIR:-$HOME/.hype/cache}"
    local repo_cache_dir="$cache_base/repo"
    local max_age_days="${1:-30}"
    
    if [[ ! -d "$repo_cache_dir" ]]; then
        debug "No repository cache directory found"
        return 0
    fi
    
    debug "Cleaning up repository caches older than $max_age_days days"
    
    find "$repo_cache_dir" -maxdepth 1 -type d -mtime +"$max_age_days" -exec rm -rf {} \; 2>/dev/null || true
    
    info "Cache cleanup completed"
}