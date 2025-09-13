#!/bin/bash

# HYPE CLI Trait Plugin
# Handles trait management for HYPE names

# Builtin metadata (standardized)
BUILTIN_NAME="trait"
BUILTIN_VERSION="1.0.0"
BUILTIN_DESCRIPTION="Trait management builtin"
BUILTIN_COMMANDS=("trait")

# Help functions
help_trait() {
    cat <<EOF
Usage: hype <hype-name> trait [SUBCOMMAND]

Manage trait settings for HYPE names

Subcommands:
  (none)              Show current trait
  set <trait-type>    Set trait type
  unset               Remove trait

Examples:
  hype my-nginx trait                     Show current trait
  hype my-nginx trait set production      Set trait to production
  hype my-nginx trait unset               Remove trait
EOF
}

help_trait_brief() {
    echo "Show current trait"
}

# Get trait for hype name from hype-traits ConfigMap
get_hype_trait() {
    local hype_name="$1"
    
    debug "Getting trait for hype: $hype_name"
    
    # Check if hype-traits ConfigMap exists
    if ! kubectl get configmap hype-traits >/dev/null 2>&1; then
        debug "hype-traits ConfigMap does not exist"
        return 1
    fi
    
    # Get trait from ConfigMap
    local trait
    trait=$(kubectl get configmap hype-traits -o jsonpath="{.data.$hype_name}" 2>/dev/null || echo "")
    
    if [[ -n "$trait" ]]; then
        debug "Found trait for $hype_name: $trait"
        echo "$trait"
        return 0
    else
        debug "No trait found for hype: $hype_name"
        return 1
    fi
}

# Set trait for hype name in hype-traits ConfigMap
set_hype_trait() {
    local hype_name="$1"
    local trait_type="$2"
    
    debug "Setting trait for hype: $hype_name to: $trait_type"
    
    # Validate trait type format (alphanumeric + hyphens only)
    if [[ ! "$trait_type" =~ ^[a-zA-Z0-9-]+$ ]]; then
        die "Invalid trait type: $trait_type (only alphanumeric characters and hyphens allowed)"
    fi
    
    # Create or patch the hype-traits ConfigMap
    if kubectl get configmap hype-traits >/dev/null 2>&1; then
        # ConfigMap exists, patch it
        debug "Patching existing hype-traits ConfigMap"
        kubectl patch configmap hype-traits --patch "{\"data\":{\"$hype_name\":\"$trait_type\"}}"
    else
        # ConfigMap doesn't exist, create it
        debug "Creating new hype-traits ConfigMap"
        kubectl create configmap hype-traits --from-literal="$hype_name=$trait_type"
    fi
    
    info "Set trait '$trait_type' for hype: $hype_name"
}

# Remove trait for hype name from hype-traits ConfigMap
unset_hype_trait() {
    local hype_name="$1"
    
    debug "Removing trait for hype: $hype_name"
    
    # Check if hype-traits ConfigMap exists
    if ! kubectl get configmap hype-traits >/dev/null 2>&1; then
        warn "hype-traits ConfigMap does not exist"
        return 1
    fi
    
    # Check if trait exists for this hype
    if ! kubectl get configmap hype-traits -o jsonpath="{.data.$hype_name}" >/dev/null 2>&1; then
        warn "No trait set for hype: $hype_name"
        return 1
    fi
    
    # Remove the trait by patching the ConfigMap
    debug "Removing trait from hype-traits ConfigMap"
    kubectl patch configmap hype-traits --type json -p "[{\"op\": \"remove\", \"path\": \"/data/$hype_name\"}]"
    
    info "Removed trait for hype: $hype_name"
}

# Handle trait commands
cmd_trait() {
    local hype_name="$1"
    local subcommand="${2:-}"
    local trait_type="${3:-}"
    
    case "$subcommand" in
        "")
            # Show current trait
            local current_trait
            if current_trait=$(get_hype_trait "$hype_name" 2>/dev/null); then
                echo "$current_trait"
            else
                echo "No trait set"
            fi
            ;;
        "set")
            if [[ -z "$trait_type" ]]; then
                error "Trait type is required"
                error "Usage: hype <hype-name> trait set <trait-type>"
                exit 1
            fi
            set_hype_trait "$hype_name" "$trait_type"
            ;;
        "unset")
            if ! unset_hype_trait "$hype_name"; then
                exit 1
            fi
            ;;
        *)
            error "Unknown trait subcommand: $subcommand"
            error "Valid options: set, unset"
            exit 1
            ;;
    esac
}