#!/bin/bash

# HYPE CLI Trait Plugin
# Handles trait management for HYPE names

# Builtin metadata (standardized)
BUILTIN_NAME="trait"
BUILTIN_VERSION="1.0.0"
BUILTIN_DESCRIPTION="Trait management builtin"

# Register commands in global BUILTIN_COMMANDS array
BUILTIN_COMMANDS+=("trait")

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

# Get trait for hype name from hype-trait-<hype-name> ConfigMap
get_hype_trait() {
    local hype_name="$1"
    local configmap_name="hype-trait-$hype_name"
    
    debug "Getting trait for hype: $hype_name"
    
    # Check if hype-trait-<hype-name> ConfigMap exists
    if ! kubectl get configmap "$configmap_name" >/dev/null 2>&1; then
        debug "$configmap_name ConfigMap does not exist"
        return 1
    fi
    
    # Get trait from ConfigMap
    local trait
    trait=$(kubectl get configmap "$configmap_name" -o jsonpath="{.data.trait}" 2>/dev/null || echo "")
    
    if [[ -n "$trait" ]]; then
        debug "Found trait for $hype_name: $trait"
        echo "$trait"
        return 0
    else
        debug "No trait found for hype: $hype_name"
        return 1
    fi
}

# Set trait for hype name in hype-trait-<hype-name> ConfigMap
set_hype_trait() {
    local hype_name="$1"
    local trait_type="$2"
    local configmap_name="hype-trait-$hype_name"
    
    debug "Setting trait for hype: $hype_name to: $trait_type"
    
    # Validate hype name format for Kubernetes ConfigMap naming (DNS-1123 label)
    if [[ ! "$hype_name" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
        die "Invalid hype name: $hype_name (must be valid Kubernetes ConfigMap name: lowercase alphanumeric and hyphens only, start/end with alphanumeric)"
    fi
    
    # Validate trait type format (alphanumeric + hyphens only)
    if [[ ! "$trait_type" =~ ^[a-zA-Z0-9-]+$ ]]; then
        die "Invalid trait type: $trait_type (only alphanumeric characters and hyphens allowed)"
    fi
    
    # Delete existing ConfigMap if it exists, then create new one
    if kubectl get configmap "$configmap_name" >/dev/null 2>&1; then
        debug "Deleting existing $configmap_name ConfigMap"
        kubectl delete configmap "$configmap_name" >/dev/null 2>&1
    fi
    
    # Create new ConfigMap
    debug "Creating $configmap_name ConfigMap"
    kubectl create configmap "$configmap_name" --from-literal="trait=$trait_type"
    
    info "Set trait '$trait_type' for hype: $hype_name"
}

# Remove trait for hype name by deleting hype-trait-<hype-name> ConfigMap
unset_hype_trait() {
    local hype_name="$1"
    local configmap_name="hype-trait-$hype_name"
    
    debug "Removing trait for hype: $hype_name"
    
    # Check if hype-trait-<hype-name> ConfigMap exists
    if ! kubectl get configmap "$configmap_name" >/dev/null 2>&1; then
        warn "No trait set for hype: $hype_name"
        return 1
    fi
    
    # Delete the entire ConfigMap
    debug "Deleting $configmap_name ConfigMap"
    kubectl delete configmap "$configmap_name"
    
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