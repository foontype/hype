#!/bin/bash

# HYPE CLI Helmfile Plugin
# Handles helmfile command execution with state management

# Plugin metadata
PLUGIN_NAME="helmfile"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Helmfile execution plugin"
PLUGIN_COMMANDS=("helmfile")

# Run helmfile command
cmd_helmfile() {
    local hype_name="$1"
    shift
    local helmfile_args=("$@")
    
    debug "Running helmfile for: $hype_name"
    debug "Helmfile args: ${helmfile_args[*]}"
    
    parse_hypefile "$hype_name"
    
    # Build helmfile command
    local cmd=("helmfile" "-f" "$HELMFILE_SECTION_FILE" "-e" "$hype_name")
    
    # Add current directory and trait as state values
    local current_dir_state_file
    current_dir_state_file=$(mktemp --suffix=.yaml)
    
    # Get trait value if available
    local trait_value
    if trait_value=$(get_hype_trait "$hype_name" 2>/dev/null); then
        debug "Adding trait to state values: $trait_value"
        cat > "$current_dir_state_file" << EOF
Hype:
  CurrentDirectory: "$(pwd)"
  Name: "$hype_name"
  Trait: "$trait_value"
EOF
    else
        debug "No trait found, using default state values"
        cat > "$current_dir_state_file" << EOF
Hype:
  CurrentDirectory: "$(pwd)"
  Name: "$hype_name"
EOF
    fi
    
    cmd+=("--state-values-file" "$current_dir_state_file")
    
    debug "Added Hype state values - CurrentDirectory: $(pwd), Name: $hype_name"
    
    # Clean up current directory state file when done
    # shellcheck disable=SC2064
    trap "rm -f '$current_dir_state_file'" EXIT
    
    # Add state-values-file for DefaultStateValues and StateValuesConfigmap resources
    if [[ -f "$HYPE_SECTION_FILE" ]]; then
        local resource_count
        resource_count=$(yq eval '.defaultResources | length' "$HYPE_SECTION_FILE" 2>/dev/null || echo "0")
        
        # First pass: Process DefaultStateValues (highest priority)
        for (( i=0; i<resource_count; i++ )); do
            local type
            type=$(yq eval ".defaultResources[$i].type" "$HYPE_SECTION_FILE")
            
            if [[ "$type" == "DefaultStateValues" ]]; then
                # Create temporary state values file for DefaultStateValues
                local default_state_file
                default_state_file=$(mktemp --suffix=.yaml)
                
                # Extract values directly from the YAML resource
                if ! yq eval ".defaultResources[$i].values" "$HYPE_SECTION_FILE" > "$default_state_file" 2>/dev/null; then
                    error "Failed to extract values from DefaultStateValues resource"
                    continue
                fi
                
                # Verify the state file is not empty
                if [[ ! -s "$default_state_file" ]]; then
                    error "DefaultStateValues resource contains no values data"
                    continue
                fi
                
                cmd+=("--state-values-file" "$default_state_file")
                
                debug "Added DefaultStateValues state-values-file: $default_state_file"
                
                # Debug: Show contents of DefaultStateValues file
                if [[ "$DEBUG" == "true" ]]; then
                    debug "=== DEFAULT STATE VALUES FILE CONTENT ==="
                    cat "$default_state_file" >&2
                    debug "=== END DEFAULT STATE VALUES FILE ==="
                fi
                
                # Clean up default state file when done
                # shellcheck disable=SC2064
                trap "rm -f '$default_state_file'" EXIT
            fi
        done
        
        # Second pass: Process StateValuesConfigmap resources in reverse order
        # (later resources in hypefile get higher priority in state-values-file)
        for (( i=resource_count-1; i>=0; i-- )); do
            local name type
            
            name=$(yq eval ".defaultResources[$i].name" "$HYPE_SECTION_FILE" | sed "s/{{ \.Hype\.Name }}/$hype_name/g" | sed "s|{{ \.Hype\.CurrentDirectory }}|$(pwd)|g")
            type=$(yq eval ".defaultResources[$i].type" "$HYPE_SECTION_FILE")
            
            if [[ "$type" == "StateValuesConfigmap" && "$name" != "null" ]]; then
                # Create temporary state values file
                local state_file
                state_file=$(mktemp --suffix=.yaml)
                
                # Extract YAML content directly from ConfigMap data.values key
                if ! kubectl get configmap "$name" -o jsonpath='{.data.values}' > "$state_file" 2>/dev/null; then
                    error "Failed to extract state values from StateValuesConfigmap: $name"
                    continue
                fi
                
                # Verify the state file is not empty
                if [[ ! -s "$state_file" ]]; then
                    error "StateValuesConfigmap $name contains no values data"
                    continue
                fi
                cmd+=("--state-values-file" "$state_file")
                
                debug "Added state-values-file: $state_file for ConfigMap: $name"
                
                # Debug: Show contents of state values file
                if [[ "$DEBUG" == "true" ]]; then
                    debug "=== STATE VALUES FILE CONTENT ($name) ==="
                    cat "$state_file" >&2
                    debug "=== END STATE VALUES FILE ==="
                fi
                
                # Clean up state file when done
                # shellcheck disable=SC2064
                trap "rm -f '$state_file'" EXIT
            fi
        done
    fi
    
    # Add user-provided arguments
    cmd+=("${helmfile_args[@]}")
    
    debug "Executing: ${cmd[*]}"
    "${cmd[@]}"
}