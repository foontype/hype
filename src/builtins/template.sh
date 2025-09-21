#!/bin/bash

# HYPE CLI Template Plugin
# Handles template rendering and state values display

# Builtin metadata (standardized)
BUILTIN_NAME="template"
BUILTIN_VERSION="1.0.0"
BUILTIN_DESCRIPTION="Template rendering and state values builtin"

# Register commands in global BUILTIN_COMMANDS array
BUILTIN_COMMANDS+=("template")

# Help functions
help_template() {
    cat <<EOF
Usage: hype <hype-name> template [SUBCOMMAND]

Show rendered hype section YAML or state values content

Subcommands:
  (none)                              Show rendered hype section YAML
  state-values <configmap-name>       Show state-values file content

Examples:
  hype my-nginx template                                         Show rendered YAML for my-nginx
  hype my-nginx template state-values my-nginx-state-values     Show state-values content
EOF
}

help_template_brief() {
    echo "Show rendered hype section YAML"
}

# Validate state values configmap
validate_state_values_configmap() {
    local hype_name="$1"
    local configmap_name="$2"
    
    debug "Validating StateValuesConfigmap: $configmap_name for hype: $hype_name"
    
    # Parse hypefile first
    parse_hypefile "$hype_name"
    
    if [[ ! -f "$HYPE_SECTION_FILE" ]]; then
        error "No hype section found in hypefile"
        return 1
    fi
    
    # Get resource count and validate
    local resource_count
    resource_count=$(yq eval '.defaultResources | length' "$HYPE_SECTION_FILE" 2>/dev/null || echo "0")
    
    if [[ "$resource_count" -eq 0 ]]; then
        error "No default resources found in hypefile"
        return 1
    fi
    
    # Check if configmap exists in defaultResources and is StateValuesConfigmap type
    local found=false
    for (( i=0; i<resource_count; i++ )); do
        local name type
        
        name=$(yq eval ".defaultResources[$i].name" "$HYPE_SECTION_FILE" | sed "s/{{ \.Hype\.Name }}/$hype_name/g" | sed "s|{{ \.Hype\.CurrentDirectory }}|$(pwd)|g")
        type=$(yq eval ".defaultResources[$i].type" "$HYPE_SECTION_FILE")
        
        debug "Checking resource $i: name=$name, type=$type"
        
        if [[ "$name" == "$configmap_name" ]]; then
            found=true
            if [[ "$type" != "StateValuesConfigmap" ]]; then
                error "ConfigMap $configmap_name is not a StateValuesConfigmap (type: $type)"
                return 1
            fi
            break
        fi
    done
    
    if [[ "$found" == false ]]; then
        error "ConfigMap $configmap_name not found in hypefile defaultResources"
        return 1
    fi
    
    # Check if the ConfigMap actually exists in Kubernetes
    if ! kubectl get configmap "$configmap_name" >/dev/null 2>&1; then
        error "ConfigMap $configmap_name does not exist in Kubernetes"
        error "Run 'hype $hype_name init' to create it"
        return 1
    fi
    
    return 0
}

# Show rendered hype section template
cmd_template_hype_section() {
    local hype_name="$1"
    
    info "Rendered hype section for: $hype_name"
    echo
    
    parse_hypefile "$hype_name"
    
    # Output the rendered hype section
    if [[ -f "$HYPE_SECTION_FILE" ]]; then
        cat "$HYPE_SECTION_FILE"
    else
        warn "No hype section found in hypefile"
    fi
}

# Show state-values file content for StateValuesConfigmap
cmd_template_state_value() {
    local hype_name="$1"
    local configmap_name="$2"
    
    if [[ -z "$configmap_name" ]]; then
        error "ConfigMap name is required"
        error "Usage: hype <hype-name> template state-values <configmap-name>"
        return 1
    fi
    
    info "State-value file content for ConfigMap: $configmap_name"
    echo
    
    # Validate the configmap
    if ! validate_state_values_configmap "$hype_name" "$configmap_name"; then
        return 1
    fi
    
    # Extract YAML content from ConfigMap data.values key
    local state_values
    if ! state_values=$(kubectl get configmap "$configmap_name" -o jsonpath='{.data.values}' 2>/dev/null); then
        error "Failed to extract state values from ConfigMap: $configmap_name"
        return 1
    fi
    
    # Verify the state values are not empty
    if [[ -z "$state_values" ]]; then
        error "ConfigMap $configmap_name contains no values data"
        return 1
    fi
    
    debug "Successfully extracted state values from ConfigMap: $configmap_name"
    
    # Output the state values content
    echo "$state_values"
}

# Template command router
cmd_template() {
    local hype_name="$1"
    local subcommand="${2:-}"
    
    case "$subcommand" in
        "state-values")
            local configmap_name="${3:-}"
            cmd_template_state_value "$hype_name" "$configmap_name"
            ;;
        "")
            cmd_template_hype_section "$hype_name"
            ;;
        *)
            error "Unknown template subcommand: $subcommand"
            error "Valid options: state-values"
            return 1
            ;;
    esac
}