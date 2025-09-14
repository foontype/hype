#!/bin/bash

# HYPE CLI Repository Binding Module
# Core functions for repository binding and ConfigMap operations

# ConfigMap name for storing repository bindings (legacy)
readonly HYPE_REPOS_CONFIGMAP="hype-repos"

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
    
    # Try new format first
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
    
    # Fallback to legacy format
    get_legacy_repo_binding "$hype_name"
    return $?
}

# Get repository binding information from legacy ConfigMap (fallback)
get_legacy_repo_binding() {
    local hype_name="$1"
    
    if ! command -v kubectl >/dev/null 2>&1; then
        debug "kubectl not available, repository binding disabled"
        return 1
    fi
    
    local binding
    if binding=$(kubectl get configmap "$HYPE_REPOS_CONFIGMAP" -o jsonpath="{.data.${hype_name}}" 2>/dev/null); then
        if [[ -n "$binding" ]]; then
            # Parse legacy JSON format
            parse_repo_binding "$binding"
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
    
    # Check new format first
    if kubectl get configmap "$configmap_name" >/dev/null 2>&1; then
        return 0
    fi
    
    # Fallback to legacy format
    get_legacy_repo_binding "$hype_name" >/dev/null 2>&1
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
    
    # Also include legacy bindings if they exist
    if kubectl get configmap "$HYPE_REPOS_CONFIGMAP" >/dev/null 2>&1; then
        echo ""
        echo "Legacy bindings found in $HYPE_REPOS_CONFIGMAP:"
        kubectl get configmap "$HYPE_REPOS_CONFIGMAP" -o json 2>/dev/null | \
            jq -r '.data // {} | to_entries[] | "\(.key): (legacy format)"' 2>/dev/null || {
            # Fallback if jq is not available
            echo "Use 'hype <name> repo migrate' to upgrade legacy bindings"
        }
    fi
}

# Migration functions for backward compatibility

# Check if new format is available for a hype name
check_new_format_available() {
    local hype_name="$1"
    local configmap_name
    configmap_name=$(get_repo_configmap_name "$hype_name")
    kubectl get configmap "$configmap_name" >/dev/null 2>&1
}

# Migrate a single legacy binding to new format
migrate_single_binding() {
    local hype_name="$1"
    
    if check_new_format_available "$hype_name"; then
        debug "Binding for '$hype_name' already in new format"
        return 0
    fi
    
    # Get legacy binding data
    local legacy_data
    if legacy_data=$(get_legacy_repo_binding "$hype_name"); then
        # Parse legacy data
        eval "$legacy_data"  # Sets REPO_URL, REPO_BRANCH, REPO_PATH
        
        # Store in new format
        if store_repo_binding "$hype_name" "$REPO_URL" "$REPO_BRANCH" "$REPO_PATH"; then
            info "Migrated binding for '$hype_name' to new format"
            return 0
        else
            error "Failed to migrate binding for '$hype_name'"
            return 1
        fi
    else
        debug "No legacy binding found for '$hype_name'"
        return 1
    fi
}

# Migrate all legacy bindings to new format
migrate_legacy_bindings() {
    if ! command -v kubectl >/dev/null 2>&1; then
        debug "kubectl not available, cannot migrate bindings"
        return 1
    fi
    
    if ! kubectl get configmap "$HYPE_REPOS_CONFIGMAP" >/dev/null 2>&1; then
        debug "No legacy bindings found"
        return 0
    fi
    
    info "Checking for legacy repository bindings..."
    
    # Create backup
    local backup_file
    backup_file="/tmp/hype-repos-backup-$(date +%s).yaml"
    kubectl get configmap "$HYPE_REPOS_CONFIGMAP" -o yaml > "$backup_file"
    info "Legacy bindings backed up to: $backup_file"
    
    # Get all legacy binding names
    local hype_names
    if command -v jq >/dev/null 2>&1; then
        hype_names=$(kubectl get configmap "$HYPE_REPOS_CONFIGMAP" -o json | jq -r '.data // {} | keys[]' 2>/dev/null)
    else
        # Fallback without jq
        hype_names=$(kubectl get configmap "$HYPE_REPOS_CONFIGMAP" -o jsonpath='{.data}' 2>/dev/null | grep -o '"[^"]*":' | sed 's/"//g' | sed 's/://')
    fi
    
    if [[ -z "$hype_names" ]]; then
        debug "No legacy bindings to migrate"
        return 0
    fi
    
    local migration_count=0
    local migration_failed=0
    
    while IFS= read -r hype_name; do
        [[ -z "$hype_name" ]] && continue
        
        if migrate_single_binding "$hype_name"; then
            ((migration_count++))
        else
            ((migration_failed++))
        fi
    done <<< "$hype_names"
    
    if [[ $migration_count -gt 0 ]]; then
        info "Successfully migrated $migration_count binding(s) to new format"
        if [[ $migration_failed -eq 0 ]]; then
            warn "All bindings migrated successfully"
            warn "Legacy ConfigMap $HYPE_REPOS_CONFIGMAP can be safely removed"
            warn "Backup saved to: $backup_file"
        else
            warn "$migration_failed binding(s) failed to migrate"
        fi
    else
        warn "No bindings were migrated"
    fi
    
    return 0
}