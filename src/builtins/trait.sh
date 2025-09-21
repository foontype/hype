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
  check                   Show current trait (exit 0 if exists, exit 1 if not)
  check <trait-name>      Check if current trait matches specified trait name
  set <trait-type>        Set trait type
  unset                   Remove trait
  prepare <trait-type>    Prepare trait (check if exists, set if not)

Examples:
  hype my-nginx trait                     Show trait help
  hype my-nginx trait check               Show current trait
  hype my-nginx trait check production    Check if trait is production (exit 0 if match, exit 1 if no match)
  hype my-nginx trait set production      Set trait to production
  hype my-nginx trait unset               Remove trait
  hype my-nginx trait prepare production  Prepare trait (set if not already production)
EOF
}

help_trait_brief() {
    echo "Manage trait settings for HYPE names"
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

# Get trait for hype name with default fallback
get_hype_trait_with_default() {
    local hype_name="$1"
    local trait
    
    debug "Getting trait with default for hype: $hype_name"
    
    if trait=$(get_hype_trait "$hype_name" 2>/dev/null); then
        echo "$trait"
    else
        echo "default"
    fi
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
            # Show trait help
            help_trait
            ;;
        "set")
            if [[ -z "$trait_type" ]]; then
                error "Trait type is required"
                error "Usage: hype <hype-name> trait set <trait-type>"
                return 1
            fi
            set_hype_trait "$hype_name" "$trait_type"
            ;;
        "unset")
            if ! unset_hype_trait "$hype_name"; then
                return 1
            fi
            ;;
        "check")
            if [[ -z "$trait_type" ]]; then
                # Show current trait
                local current_trait
                if current_trait=$(get_hype_trait "$hype_name" 2>/dev/null); then
                    echo "$current_trait"
                    return 0
                else
                    echo "No trait set"
                    return 1
                fi
            else
                # Check if current trait matches specified trait
                local current_trait
                if current_trait=$(get_hype_trait "$hype_name" 2>/dev/null); then
                    # Compare current trait with specified trait
                    if [[ "$current_trait" == "$trait_type" ]]; then
                        debug "Trait matches: $current_trait == $trait_type"
                        return 0
                    else
                        debug "Trait does not match: $current_trait != $trait_type"
                        return 1
                    fi
                else
                    debug "No trait set for hype: $hype_name"
                    return 1
                fi
            fi
            ;;
        "prepare")
            if [[ -z "$trait_type" ]]; then
                error "Trait type is required for prepare"
                error "Usage: hype <hype-name> trait prepare <trait-type>"
                return 1
            fi
            
            # Check if trait exists and matches
            if get_hype_trait "$hype_name" >/dev/null 2>&1; then
                # Trait exists, check if it matches
                debug "Trait exists, checking if it matches: $trait_type"
                cmd_trait "$hype_name" "check" "$trait_type"
            else
                # No trait set, set it
                debug "No trait set, setting trait: $trait_type"
                set_hype_trait "$hype_name" "$trait_type"
            fi
            ;;
        *)
            error "Unknown trait subcommand: $subcommand"
            error "Valid options: set, unset, check, prepare"
            return 1
            ;;
    esac
}