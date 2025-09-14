#!/bin/bash

# HYPE CLI Repository Binding Module
# Core functions for repository binding and ConfigMap operations


# Get ConfigMap name for individual hype repository binding
get_repo_configmap_name() {
    local hype_name="$1"
    echo "hype-repo-${hype_name}"
}

# Get cache directory for repository
get_repo_cache_dir() {
    local hype_name="$1"
    local cache_base="${HYPE_CACHE_DIR:-$HOME/.hype/cache}"
    echo "${cache_base}/repo/${hype_name}"
}

# Get repository binding information from individual ConfigMap
get_repo_binding() {
    local hype_name="$1"
    local configmap_name
    configmap_name=$(get_repo_configmap_name "$hype_name")
    
    if ! command -v kubectl >/dev/null 2>&1; then
        debug "kubectl not available, repository binding disabled"
        return 1
    fi
    
    if kubectl get configmap "$configmap_name" >/dev/null 2>&1; then
        local url branch path
        url=$(kubectl get configmap "$configmap_name" -o jsonpath='{.data.url}' 2>/dev/null)
        branch=$(kubectl get configmap "$configmap_name" -o jsonpath='{.data.branch}' 2>/dev/null)
        path=$(kubectl get configmap "$configmap_name" -o jsonpath='{.data.path}' 2>/dev/null)
        
        if [[ -n "$url" ]]; then
            echo "REPO_URL=${url}"
            echo "REPO_BRANCH=${branch:-main}"
            echo "REPO_PATH=${path:-.}"
            return 0
        fi
    fi
    
    return 1
}


# Store repository binding in individual ConfigMap
store_repo_binding() {
    local hype_name="$1"
    local url="$2"
    local branch="${3:-main}"
    local path="${4:-.}"
    local configmap_name
    configmap_name=$(get_repo_configmap_name "$hype_name")
    
    if ! command -v kubectl >/dev/null 2>&1; then
        die "kubectl is required for repository binding operations"
    fi
    
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Check if ConfigMap exists
    if kubectl get configmap "$configmap_name" >/dev/null 2>&1; then
        # Update existing ConfigMap
        kubectl patch configmap "$configmap_name" --type='merge' -p="{
            \"data\": {
                \"url\": \"$url\",
                \"branch\": \"$branch\",
                \"path\": \"$path\",
                \"last_updated\": \"$timestamp\"
            }
        }"
    else
        # Create new ConfigMap
        kubectl create configmap "$configmap_name" \
            --from-literal="url=$url" \
            --from-literal="branch=$branch" \
            --from-literal="path=$path" \
            --from-literal="bound_at=$timestamp" \
            --from-literal="last_updated=$timestamp"
    fi
    
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        info "Repository binding stored in ConfigMap: $configmap_name"
        return 0
    else
        error "Failed to store repository binding"
        return 1
    fi
}

# Remove repository binding by deleting individual ConfigMap
remove_repo_binding() {
    local hype_name="$1"
    local configmap_name
    configmap_name=$(get_repo_configmap_name "$hype_name")
    
    if ! command -v kubectl >/dev/null 2>&1; then
        die "kubectl is required for repository binding operations"
    fi
    
    # Check if ConfigMap exists
    if kubectl get configmap "$configmap_name" >/dev/null 2>&1; then
        kubectl delete configmap "$configmap_name"
        info "Repository binding removed: $configmap_name"
        return 0
    else
        warn "No repository binding found for '$hype_name'"
        return 1
    fi
}

# Check if a hype name has a repository binding
has_repo_binding() {
    local hype_name="$1"
    local configmap_name
    configmap_name=$(get_repo_configmap_name "$hype_name")
    
    kubectl get configmap "$configmap_name" >/dev/null 2>&1
}

# Expand GitHub shorthand notation (user/repo) to full URL
expand_github_shorthand() {
    local url="$1"
    
    # Check if URL is GitHub shorthand (user/repo format)
    if [[ "$url" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+$ ]]; then
        echo "https://github.com/${url}"
        return 0
    fi
    
    # Return original URL if not shorthand
    echo "$url"
    return 0
}

# Validate repository URL
validate_repo_url() {
    local url="$1"
    
    # Expand GitHub shorthand if applicable
    url=$(expand_github_shorthand "$url")
    
    # Basic URL validation
    if [[ ! "$url" =~ ^https?://.*\.git$ ]] && [[ ! "$url" =~ ^git@.*:.*\.git$ ]] && [[ ! "$url" =~ ^https?://github\.com/.*/.*$ ]]; then
        return 1
    fi
    
    return 0
}

# Get all repository bindings from individual ConfigMaps
list_repo_bindings() {
    if ! command -v kubectl >/dev/null 2>&1; then
        debug "kubectl not available, cannot list repository bindings"
        return 1
    fi
    
    # List all hype-repo-* ConfigMaps
    kubectl get configmaps -o name 2>/dev/null | grep "^configmap/hype-repo-" | sed 's/^configmap\/hype-repo-//' | while read -r hype_name; do
        local configmap_name="hype-repo-${hype_name}"
        local url branch
        url=$(kubectl get configmap "$configmap_name" -o jsonpath='{.data.url}' 2>/dev/null)
        branch=$(kubectl get configmap "$configmap_name" -o jsonpath='{.data.branch}' 2>/dev/null)
        echo "${hype_name}: ${url} (${branch:-main})"
    done
}

