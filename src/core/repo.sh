#!/bin/bash

# HYPE CLI Repository Binding Module
# Core functions for repository binding and ConfigMap operations

# ConfigMap name for storing repository bindings
readonly HYPE_REPOS_CONFIGMAP="hype-repos"

# Get cache directory for repository
get_repo_cache_dir() {
    local hype_name="$1"
    local cache_base="${HYPE_CACHE_DIR:-$HOME/.hype/cache}"
    echo "${cache_base}/repo/${hype_name}"
}

# Get repository binding information from ConfigMap
get_repo_binding() {
    local hype_name="$1"
    
    if ! command -v kubectl >/dev/null 2>&1; then
        debug "kubectl not available, repository binding disabled"
        return 1
    fi
    
    local binding
    if binding=$(kubectl get configmap "$HYPE_REPOS_CONFIGMAP" -o jsonpath="{.data.${hype_name}}" 2>/dev/null); then
        if [[ -n "$binding" ]]; then
            echo "$binding"
            return 0
        fi
    fi
    
    return 1
}

# Parse repository binding data
parse_repo_binding() {
    local binding_data="$1"
    
    # Parse JSON-like data using parameter expansion
    local url branch path
    
    # Extract URL
    url=$(echo "$binding_data" | grep -o '"url":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    # Extract branch (optional)
    branch=$(echo "$binding_data" | grep -o '"branch":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    # Extract path (optional)
    path=$(echo "$binding_data" | grep -o '"path":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    
    # Set defaults if not specified
    branch="${branch:-main}"
    path="${path:-.}"
    
    echo "REPO_URL=$url"
    echo "REPO_BRANCH=$branch"
    echo "REPO_PATH=$path"
}

# Store repository binding in ConfigMap
store_repo_binding() {
    local hype_name="$1"
    local url="$2"
    local branch="${3:-main}"
    local path="${4:-.}"
    
    if ! command -v kubectl >/dev/null 2>&1; then
        die "kubectl is required for repository binding operations"
    fi
    
    # Create JSON data for the binding
    local binding_data
    binding_data=$(cat <<EOF
{
    "url": "$url",
    "branch": "$branch",
    "path": "$path"
}
EOF
)
    
    # Try to get existing ConfigMap
    if kubectl get configmap "$HYPE_REPOS_CONFIGMAP" >/dev/null 2>&1; then
        # Update existing ConfigMap
        kubectl patch configmap "$HYPE_REPOS_CONFIGMAP" --type='merge' -p="{\"data\":{\"$hype_name\":\"$(echo "$binding_data" | tr -d '\n' | sed 's/"/\\"/g')\"}}"
    else
        # Create new ConfigMap
        kubectl create configmap "$HYPE_REPOS_CONFIGMAP" --from-literal="$hype_name=$(echo "$binding_data" | tr -d '\n')"
    fi
    
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        info "Repository binding stored for '$hype_name'"
        return 0
    else
        error "Failed to store repository binding"
        return 1
    fi
}

# Remove repository binding from ConfigMap
remove_repo_binding() {
    local hype_name="$1"
    
    if ! command -v kubectl >/dev/null 2>&1; then
        die "kubectl is required for repository binding operations"
    fi
    
    # Check if ConfigMap exists
    if ! kubectl get configmap "$HYPE_REPOS_CONFIGMAP" >/dev/null 2>&1; then
        warn "No repository bindings found (ConfigMap does not exist)"
        return 1
    fi
    
    # Remove the specific binding
    if kubectl patch configmap "$HYPE_REPOS_CONFIGMAP" --type='json' -p="[{\"op\": \"remove\", \"path\": \"/data/$hype_name\"}]" 2>/dev/null; then
        info "Repository binding removed for '$hype_name'"
        return 0
    else
        warn "No repository binding found for '$hype_name'"
        return 1
    fi
}

# Check if a hype name has a repository binding
has_repo_binding() {
    local hype_name="$1"
    get_repo_binding "$hype_name" >/dev/null 2>&1
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

# Get all repository bindings
list_repo_bindings() {
    if ! command -v kubectl >/dev/null 2>&1; then
        debug "kubectl not available, cannot list repository bindings"
        return 1
    fi
    
    if ! kubectl get configmap "$HYPE_REPOS_CONFIGMAP" >/dev/null 2>&1; then
        debug "No repository bindings ConfigMap found"
        return 1
    fi
    
    kubectl get configmap "$HYPE_REPOS_CONFIGMAP" -o json | \
        jq -r '.data // {} | to_entries[] | "\(.key):\(.value)"' 2>/dev/null || {
        # Fallback if jq is not available
        kubectl get configmap "$HYPE_REPOS_CONFIGMAP" -o jsonpath='{.data}' 2>/dev/null
    }
}