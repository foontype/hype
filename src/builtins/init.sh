#!/bin/bash

# HYPE CLI Init Plugin
# Handles initialization, deinitialization, and resource checking

# Builtin metadata (standardized)
BUILTIN_NAME="init"
BUILTIN_VERSION="1.0.0"
BUILTIN_DESCRIPTION="Resource initialization and management builtin"

# Note: init and deinit commands are now registered in aliases.sh
# This builtin provides helper functions for resource management



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


