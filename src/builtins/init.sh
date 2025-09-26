#!/bin/bash

# HYPE CLI Init Plugin
# Handles initialization, deinitialization, and resource checking

# Builtin metadata (standardized)
BUILTIN_NAME="init"
BUILTIN_VERSION="1.0.0"
BUILTIN_DESCRIPTION="Resource initialization and management builtin"

# Register commands in global BUILTIN_COMMANDS array
BUILTIN_COMMANDS+=("init")
BUILTIN_COMMANDS+=("deinit")

# Help functions for each command
help_init() {
    cat <<EOF
Usage: hype <hype-name> init

Create default resources defined in hypefile.yaml and initialize addons

This command initializes ConfigMaps, Secrets, and other default resources
specified in the defaultResources section of your hypefile.yaml.
After completing self initialization, all configured addons will also
be initialized in the order they are listed.

Examples:
  hype my-nginx init                   Create resources for my-nginx and initialize addons
EOF
}

help_init_brief() {
    echo "Create default resources"
}

help_deinit() {
    cat <<EOF
Usage: hype <hype-name> deinit

Delete default resources defined in hypefile.yaml and deinitialize addons

This command first deinitializes all configured addons in reverse order,
then removes ConfigMaps, Secrets, and other default resources that were
created during initialization.

Examples:
  hype my-nginx deinit                 Deinitialize addons and delete resources for my-nginx
EOF
}

help_deinit_brief() {
    echo "Delete default resources"
}


# Get resource values for kubectl creation
get_resource_values() {
    local values_yaml="$1"
    local tmpdir="$2"
    local resource_type="$3"
    
    debug "Processing values_yaml with tmpdir: $tmpdir, resource_type: $resource_type"
    
    if [[ "$resource_type" == "StateValuesConfigmap" ]]; then
        # StateValuesConfigmap: Save entire values as single YAML file
        debug "StateValuesConfigmap detected - saving entire values as YAML"
        echo "$values_yaml" > "$tmpdir/values.yaml"
        echo "--from-file=values=$tmpdir/values.yaml"
    else
        # Regular Configmap/Secrets: Validate against complex structures
        debug "Regular $resource_type detected - validating for simple values only"
        
        # Check for complex structures (arrays/objects) and error if found
        local complex_keys
        complex_keys=$(echo "$values_yaml" \
          | yq eval -o=json - \
          | jq -r '
              to_entries[]
              | select((.value|type) == "array" or (.value|type) == "object")
              | .key
            ' \
          | tr '\n' ' ')
        
        if [[ -n "${complex_keys// }" ]]; then
            die "Error: Complex YAML structures (arrays/objects) not allowed in $resource_type. Found in keys: ${complex_keys// /,}"
        fi
        
        # Process simple values only (string/number/boolean)
        # ① Create files for multiline strings
        echo "$values_yaml" \
          | yq eval -o=json - \
          | jq -r '
              to_entries[]
              | select((.value|type) == "string" and (.value|contains("\n")))
              | "cat > \"'"$tmpdir"'/\(.key).txt\" <<'\''EOF'\''\n\(.value)\nEOF"
            ' \
          | bash
        
        # ② Generate kubectl arguments for all keys
        echo "$values_yaml" \
          | yq eval -o=json - \
          | jq -r '
              to_entries[]
              | if (.value|type) == "string" and (.value|contains("\n")) then
                  "--from-file=\(.key)='"$tmpdir"'/\(.key).txt"
                elif ((.value|type) == "string" or (.value|type) == "number" or (.value|type) == "boolean") then
                  "--from-literal=\(.key)=\(.value|tostring)"
                else
                  empty
                end
            '
    fi
}

# Create a resource
create_resource() {
    local name="$1"
    local type="$2"
    local values_yaml="$3"
    local tmpdir
    
    debug "Creating resource: $name (type: $type)"
    
    # Create temporary directory for complex values
    tmpdir=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '$tmpdir'" EXIT
    
    case "$type" in
        "DefaultStateValues")
            debug "DefaultStateValues detected - skipping resource creation (local processing only)"
            return
            ;;
        "StateValuesConfigmap"|"Configmap")
            if kubectl get configmap "$name" >/dev/null 2>&1; then
                info "ConfigMap $name already exists"
                return
            fi
            
            # Create configmap from values using new logic
            local kubectl_args=("create" "configmap" "$name")
            while IFS= read -r arg; do
                [[ -n "$arg" ]] && kubectl_args+=("$arg")
            done < <(get_resource_values "$values_yaml" "$tmpdir" "$type")
            
            kubectl "${kubectl_args[@]}"
            info "Created ConfigMap: $name"
            ;;
        "Secrets")
            if kubectl get secret "$name" >/dev/null 2>&1; then
                info "Secret $name already exists"
                return
            fi
            
            # Create secret from values using new logic
            local kubectl_args=("create" "secret" "generic" "$name")
            while IFS= read -r arg; do
                [[ -n "$arg" ]] && kubectl_args+=("$arg")
            done < <(get_resource_values "$values_yaml" "$tmpdir" "$type")
            
            kubectl "${kubectl_args[@]}"
            info "Created Secret: $name"
            ;;
        *)
            warn "Unknown resource type: $type"
            ;;
    esac
}

# Delete a resource
delete_resource() {
    local name="$1"
    local type="$2"
    
    debug "Deleting resource: $name (type: $type)"
    
    case "$type" in
        "DefaultStateValues")
            debug "DefaultStateValues detected - no resource to delete (local processing only)"
            return
            ;;
        "StateValuesConfigmap"|"Configmap")
            if kubectl get configmap "$name" >/dev/null 2>&1; then
                kubectl delete configmap "$name"
                info "Deleted ConfigMap: $name"
            else
                info "ConfigMap $name does not exist"
            fi
            ;;
        "Secrets")
            if kubectl get secret "$name" >/dev/null 2>&1; then
                kubectl delete secret "$name"
                info "Deleted Secret: $name"
            else
                info "Secret $name does not exist"
            fi
            ;;
        *)
            warn "Unknown resource type: $type"
            ;;
    esac
}


# Initialize addons for a hype name
init_addons() {
    local hype_name="$1"

    debug "Initializing addons for: $hype_name"

    local addons_list
    if ! addons_list=$(get_addons_list "$hype_name"); then
        debug "No addons found for $hype_name"
        return 0
    fi

    if [[ -z "$addons_list" ]]; then
        debug "No addons configured for $hype_name"
        return 0
    fi

    local count=0
    local current_entry=""
    local line

    while IFS= read -r line; do
        if [[ "$line" =~ ^hype:.*$ ]]; then
            # Process previous entry if exists
            if [[ -n "$current_entry" ]]; then
                # Check if this entry should be processed based on traits
                if should_process_entry_by_traits "$current_entry" "$hype_name"; then
                    count=$((count + 1))
                    local addon_hype

                    addon_hype=$(echo "$current_entry" | yq eval '.hype' -)

                    if [[ -z "$addon_hype" || "$addon_hype" == "null" ]]; then
                        error "Addon $count: missing 'hype' field"
                        return 1
                    fi

                    info "Initializing addon $count: $addon_hype"
                    debug "Running: hype $addon_hype init"

                    if ! hype "$addon_hype" init; then
                        error "Failed to initialize addon: $addon_hype"
                        return 1
                    fi

                    info "Addon $count initialized: $addon_hype"
                else
                    debug "Skipping addon due to trait mismatch"
                fi
            fi

            # Start new entry
            current_entry="$line"
        else
            # Continue building current entry
            current_entry="$current_entry"$'\n'"$line"
        fi
    done <<< "$addons_list"

    # Process last entry
    if [[ -n "$current_entry" ]]; then
        # Check if this entry should be processed based on traits
        if should_process_entry_by_traits "$current_entry" "$hype_name"; then
            count=$((count + 1))
            local addon_hype

            addon_hype=$(echo "$current_entry" | yq eval '.hype' -)

            if [[ -z "$addon_hype" || "$addon_hype" == "null" ]]; then
                error "Addon $count: missing 'hype' field"
                return 1
            fi

            info "Initializing addon $count: $addon_hype"
            debug "Running: hype $addon_hype init"

            if ! hype "$addon_hype" init; then
                error "Failed to initialize addon: $addon_hype"
                return 1
            fi

            info "Addon $count initialized: $addon_hype"
        else
            debug "Skipping last addon due to trait mismatch"
        fi
    fi

    if [[ $count -eq 0 ]]; then
        debug "No valid addons found for initialization"
    else
        info "All $count addons initialized for $hype_name"
    fi
}

# Initialize default resources
cmd_init() {
    local hype_name="$1"

    info "Initializing resources for: $hype_name"

    parse_hypefile "$hype_name"

    if [[ ! -f "$HYPE_SECTION_FILE" ]]; then
        info "No hypefile section found"
        return
    fi

    # Get resource count first
    local resource_count
    resource_count=$(yq eval '.defaultResources | length' "$HYPE_SECTION_FILE" 2>/dev/null || echo "0")

    if [[ "$resource_count" -eq 0 ]]; then
        info "No default resources found"
    else
        # Process each default resource by index
        for (( i=0; i<resource_count; i++ )); do
            local name type values_yaml

            name=$(yq eval ".defaultResources[$i].name" "$HYPE_SECTION_FILE" | sed "s/{{ \.Hype\.Name }}/$hype_name/g" | sed "s|{{ \.Hype\.CurrentDirectory }}|$(pwd)|g")
            type=$(yq eval ".defaultResources[$i].type" "$HYPE_SECTION_FILE")
            values_yaml=$(yq eval ".defaultResources[$i].values" "$HYPE_SECTION_FILE")

            debug "Processing resource $i: name=$name, type=$type"

            if [[ "$name" != "null" && "$type" != "null" && "$values_yaml" != "null" ]]; then
                create_resource "$name" "$type" "$values_yaml"
            fi
        done

        info "Default resources initialization completed for: $hype_name"
    fi

    # After self initialization, initialize addons
    init_addons "$hype_name"

    info "Initialization completed for: $hype_name"
}

# Deinitialize addons for a hype name (reverse order)
deinit_addons() {
    local hype_name="$1"

    debug "Deinitializing addons for: $hype_name"

    local addons_list
    if ! addons_list=$(get_addons_list "$hype_name"); then
        debug "No addons found for $hype_name"
        return 0
    fi

    if [[ -z "$addons_list" ]]; then
        debug "No addons configured for $hype_name"
        return 0
    fi

    local addon_array=()
    local current_entry=""
    local line

    while IFS= read -r line; do
        if [[ "$line" =~ ^hype:.*$ ]]; then
            # Process previous entry if exists
            if [[ -n "$current_entry" ]]; then
                # Check if this entry should be processed based on traits
                if should_process_entry_by_traits "$current_entry" "$hype_name"; then
                    local addon_hype
                    addon_hype=$(echo "$current_entry" | yq eval '.hype' -)

                    if [[ -n "$addon_hype" && "$addon_hype" != "null" ]]; then
                        addon_array+=("$addon_hype")
                    fi
                else
                    debug "Skipping addon in deinit due to trait mismatch"
                fi
            fi

            # Start new entry
            current_entry="$line"
        else
            # Continue building current entry
            current_entry="$current_entry"$'\n'"$line"
        fi
    done <<< "$addons_list"

    # Process last entry
    if [[ -n "$current_entry" ]]; then
        # Check if this entry should be processed based on traits
        if should_process_entry_by_traits "$current_entry" "$hype_name"; then
            local addon_hype
            addon_hype=$(echo "$current_entry" | yq eval '.hype' -)

            if [[ -n "$addon_hype" && "$addon_hype" != "null" ]]; then
                addon_array+=("$addon_hype")
            fi
        else
            debug "Skipping last addon in deinit due to trait mismatch"
        fi
    fi

    local count=${#addon_array[@]}
    if [[ $count -eq 0 ]]; then
        debug "No valid addons found for deinitialization"
        return 0
    fi

    # Process in reverse order
    for ((i = count - 1; i >= 0; i--)); do
        local addon_hype="${addon_array[i]}"
        local addon_num=$((count - i))

        info "Deinitializing addon $addon_num: $addon_hype"
        debug "Running: hype $addon_hype deinit"

        if ! hype "$addon_hype" deinit; then
            error "Failed to deinitialize addon: $addon_hype"
            return 1
        fi

        info "Addon $addon_num deinitialized: $addon_hype"
    done

    info "All $count addons deinitialized for $hype_name"
}

# Deinitialize default resources
cmd_deinit() {
    local hype_name="$1"

    info "Deinitializing resources for: $hype_name"

    parse_hypefile "$hype_name"

    if [[ ! -f "$HYPE_SECTION_FILE" ]]; then
        info "No hypefile section found"
        return
    fi

    # First deinitialize addons (reverse order)
    deinit_addons "$hype_name"

    # Get resource count first
    local resource_count
    resource_count=$(yq eval '.defaultResources | length' "$HYPE_SECTION_FILE" 2>/dev/null || echo "0")

    if [[ "$resource_count" -eq 0 ]]; then
        info "No default resources found"
    else
        # Process each default resource by index
        for (( i=0; i<resource_count; i++ )); do
            local name type

            name=$(yq eval ".defaultResources[$i].name" "$HYPE_SECTION_FILE" | sed "s/{{ \.Hype\.Name }}/$hype_name/g" | sed "s|{{ \.Hype\.CurrentDirectory }}|$(pwd)|g")
            type=$(yq eval ".defaultResources[$i].type" "$HYPE_SECTION_FILE")

            debug "Processing resource $i for deletion: name=$name, type=$type"

            if [[ "$name" != "null" && "$type" != "null" ]]; then
                delete_resource "$name" "$type"
            fi
        done

        info "Default resources deinitialization completed for: $hype_name"
    fi

    info "Deinitialization completed for: $hype_name"
}

