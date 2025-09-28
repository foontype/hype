#!/bin/bash

# HYPE CLI Aliases Plugin
# Handles deployment lifecycle aliases: up, down, restart

# Builtin metadata (standardized)
BUILTIN_NAME="aliases"
BUILTIN_VERSION="1.0.0"
BUILTIN_DESCRIPTION="Deployment lifecycle aliases"

# Register commands in global BUILTIN_COMMANDS array
BUILTIN_COMMANDS+=("init")
BUILTIN_COMMANDS+=("deinit")
BUILTIN_COMMANDS+=("up")
BUILTIN_COMMANDS+=("down")
BUILTIN_COMMANDS+=("restart")
BUILTIN_COMMANDS+=("releases")
BUILTIN_COMMANDS+=("resources")

# Help functions for each command
help_init() {
    cat <<EOF
Usage: hype <hype-name> init

Initialize resources with dependencies and addons

This command performs a complete initialization workflow:
1. Run depends init (if configured)
2. Initialize default resources
3. Run addons init (if configured)

Examples:
  hype my-nginx init                 Initialize my-nginx with all dependencies
EOF
}

help_init_brief() {
    echo "Initialize resources with dependencies and addons"
}

help_deinit() {
    cat <<EOF
Usage: hype <hype-name> deinit

Deinitialize resources with addons cleanup

This command performs a complete deinitialization workflow:
1. Run addons deinit (if configured)
2. Deinitialize default resources

Examples:
  hype my-nginx deinit               Deinitialize my-nginx with addons cleanup
EOF
}

help_deinit_brief() {
    echo "Deinitialize resources with addons cleanup"
}

help_releases() {
    cat <<EOF
Usage: hype <hype-name> releases <subcommand>

Manage releases with dependencies and addons support

Subcommands:
  check                             Check if all expected releases exist

Examples:
  hype my-nginx releases check      Check releases for my-nginx and addons
EOF
}

help_releases_brief() {
    echo "Manage releases with dependencies and addons support"
}

help_resources() {
    cat <<EOF
Usage: hype <hype-name> resources <subcommand>

Manage resources with dependencies and addons support

Subcommands:
  check                             Check if all default resources exist

Examples:
  hype my-nginx resources check     Check resources for my-nginx and addons
EOF
}

help_resources_brief() {
    echo "Manage resources with dependencies and addons support"
}

help_up() {
    cat <<EOF
Usage: hype <hype-name> up [--nothing-if-expected] [--build] [--push]

Start dependencies, build and deploy (dependencies + task build + helmfile apply)

This command performs a complete deployment workflow:
1. Start all dependencies (if configured in depends)
2. Run the build task (if available)
3. Apply the helmfile configuration to deploy your application

Options:
  --nothing-if-expected   Check releases first, skip deployment if already deployed
  --build                 Force run build task before deployment
  --push                  Force run push task before deployment

Examples:
  hype my-nginx up                           Deploy my-nginx with all dependencies
  hype my-nginx up --nothing-if-expected     Only deploy if not already deployed
  hype my-nginx up --build --push            Force build and push before deploy
EOF
}

help_up_brief() {
    echo "Start dependencies, build and deploy (dependencies + task build + helmfile apply)"
}

help_down() {
    cat <<EOF
Usage: hype <hype-name> down

Destroy deployment (helmfile destroy)

This command destroys the deployment by running helmfile destroy,
removing all resources created by the helmfile.

Examples:
  hype my-nginx down                 Destroy my-nginx deployment
EOF
}

help_down_brief() {
    echo "Destroy deployment (helmfile destroy)"
}

help_restart() {
    cat <<EOF
Usage: hype <hype-name> restart

Restart deployment (down + up)

This command performs a restart workflow:
1. Destroy the deployment (helmfile destroy)
2. Start all dependencies (if configured in depends)
3. Run the build task (if available)
4. Deploy the application (helmfile apply)

Examples:
  hype my-nginx restart              Restart my-nginx deployment
EOF
}

help_restart_brief() {
    echo "Restart deployment (down + up)"
}

# Get resource values for kubectl command
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

# Check if addons are configured
has_addons() {
    local hype_name="$1"
    local addons_list
    
    if ! addons_list=$(get_addons_list 2>/dev/null); then
        return 1
    fi
    
    [[ -n "$addons_list" ]]
}

# Check if build task exists in taskfile
has_build_task() {
    local hype_name="$1"
    
    if [[ ! -f "$TASKFILE_SECTION_FILE" || ! -s "$TASKFILE_SECTION_FILE" ]]; then
        return 1
    fi
    
    if ! command -v task >/dev/null 2>&1; then
        return 1
    fi
    
    if task --taskfile "$TASKFILE_SECTION_FILE" --list-all 2>/dev/null | grep -E "^\* build:" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Run build task
run_build_task() {
    local hype_name="$1"
    
    info "Running build task for hype: $hype_name"
    
    # Set up environment variables for the task
    export HYPE_NAME="$hype_name"
    local current_dir
    current_dir="$(pwd)"
    export HYPE_CURRENT_DIRECTORY="$current_dir"
    
    # Set trait if available
    local trait_value
    if trait_value=$(get_hype_trait "$hype_name" 2>/dev/null); then
        export HYPE_TRAIT="$trait_value"
        debug "Set HYPE_TRAIT environment variable: $trait_value"
    else
        unset HYPE_TRAIT
        debug "No trait set, HYPE_TRAIT environment variable unset"
    fi
    
    # Run build task
    local cmd=("task" "--taskfile" "$TASKFILE_SECTION_FILE" "--dir" "$HYPE_CURRENT_DIRECTORY" "build")
    
    debug "Executing build task: ${cmd[*]}"
    "${cmd[@]}"
}

# Run helmfile apply
run_helmfile_apply() {
    local hype_name="$1"
    
    if ! has_helmfile_section; then
        info "No helmfile section found, skipping helmfile apply for hype: $hype_name"
        return 0
    fi
    
    info "Running helmfile apply for hype: $hype_name"
    cmd_helmfile "$hype_name" "apply"
}

# Run helmfile destroy
run_helmfile_destroy() {
    local hype_name="$1"
    
    if ! has_helmfile_section; then
        info "No helmfile section found, skipping helmfile destroy for hype: $hype_name"
        return 0
    fi
    
    info "Running helmfile destroy for hype: $hype_name"
    cmd_helmfile "$hype_name" "destroy"
}

# Stop dependencies in reverse order
stop_dependencies() {
    local hype_name="$1"
    
    local depends_list
    if ! depends_list=$(get_depends_list); then
        debug "No dependencies found for $hype_name"
        return 0
    fi
    
    if [[ -z "$depends_list" ]]; then
        debug "No dependencies configured for $hype_name"
        return 0
    fi
    
    info "Stopping dependencies for $hype_name"
    
    local depend_array=()
    local current_entry=""
    local line

    while IFS= read -r line; do
        if [[ "$line" =~ ^hype:.*$ ]]; then
            # Process previous entry if exists
            if [[ -n "$current_entry" ]]; then
                local depend_hype
                depend_hype=$(echo "$current_entry" | yq eval '.hype' -)
                
                if [[ -n "$depend_hype" && "$depend_hype" != "null" ]]; then
                    depend_array+=("$depend_hype")
                fi
            fi
            
            # Start new entry
            current_entry="$line"
        else
            # Continue building current entry
            current_entry="$current_entry"$'\n'"$line"
        fi
    done <<< "$depends_list"
    
    # Process last entry
    if [[ -n "$current_entry" ]]; then
        local depend_hype
        depend_hype=$(echo "$current_entry" | yq eval '.hype' -)
        
        if [[ -n "$depend_hype" && "$depend_hype" != "null" ]]; then
            depend_array+=("$depend_hype")
        fi
    fi
    
    local count=${#depend_array[@]}
    if [[ $count -eq 0 ]]; then
        debug "No valid dependencies found for $hype_name"
        return 0
    fi
    
    for ((i = count - 1; i >= 0; i--)); do
        local depend_hype="${depend_array[i]}"
        local dep_num=$((count - i))
        
        info "Stopping dependency $dep_num: $depend_hype"
        debug "Running: hype $depend_hype helmfile destroy"
        
        if ! hype "$depend_hype" helmfile destroy; then
            error "Failed to destroy dependency: $depend_hype"
            return 1
        fi
        
        info "Dependency $dep_num stopped: $depend_hype"
    done
    
    info "All $count dependencies stopped for $hype_name"
}

# Process dependencies if they exist
run_dependencies() {
    local hype_name="$1"
    
    local depends_list
    if ! depends_list=$(get_depends_list); then
        debug "No dependencies found for $hype_name"
        return 0
    fi
    
    if [[ -z "$depends_list" ]]; then
        debug "No dependencies configured for $hype_name"
        return 0
    fi
    
    info "Starting dependencies for $hype_name"
    
    local count=0
    local current_entry=""
    local line

    while IFS= read -r line; do
        if [[ "$line" =~ ^hype:.*$ ]]; then
            # Process previous entry if exists
            if [[ -n "$current_entry" ]]; then
                count=$((count + 1))
                local depend_hype
                local depend_prepare
                
                depend_hype=$(echo "$current_entry" | yq eval '.hype' -)
                depend_prepare=$(echo "$current_entry" | yq eval '.prepare' -)
                
                if [[ -z "$depend_hype" || "$depend_hype" == "null" ]]; then
                    error "Dependency $count: missing 'hype' field"
                    return 1
                fi
                
                if [[ -z "$depend_prepare" || "$depend_prepare" == "null" ]]; then
                    error "Dependency $count: missing 'prepare' field"
                    return 1
                fi
                
                info "Processing dependency $count: $depend_hype"
                debug "Running: cmd_prepare $depend_hype $depend_prepare"
                
                if ! eval "cmd_prepare $depend_hype $depend_prepare"; then
                    error "Failed to prepare dependency: $depend_hype"
                    return 1
                fi
                
                info "Dependency $count completed: $depend_hype"
            fi
            
            # Start new entry
            current_entry="$line"
        else
            # Continue building current entry
            current_entry="$current_entry"$'\n'"$line"
        fi
    done <<< "$depends_list"
    
    # Process last entry
    if [[ -n "$current_entry" ]]; then
        count=$((count + 1))
        local depend_hype
        local depend_prepare
        
        depend_hype=$(echo "$current_entry" | yq eval '.hype' -)
        depend_prepare=$(echo "$current_entry" | yq eval '.prepare' -)
        
        if [[ -z "$depend_hype" || "$depend_hype" == "null" ]]; then
            error "Dependency $count: missing 'hype' field"
            return 1
        fi
        
        if [[ -z "$depend_prepare" || "$depend_prepare" == "null" ]]; then
            error "Dependency $count: missing 'prepare' field"
            return 1
        fi
        
        info "Processing dependency $count: $depend_hype"
        debug "Running: cmd_prepare $depend_hype $depend_prepare"
        
        if ! eval "cmd_prepare $depend_hype $depend_prepare"; then
            error "Failed to prepare dependency: $depend_hype"
            return 1
        fi
        
        info "Dependency $count completed: $depend_hype"
    fi
    
    if [[ $count -eq 0 ]]; then
        debug "No valid dependencies found for $hype_name"
    else
        info "All $count dependencies started for $hype_name"
    fi
}

# Up command: dependencies + build (if available) + helmfile apply
cmd_up() {
    local hype_name="$1"
    shift

    # Parse options
    local nothing_if_expected=false
    local force_build=false
    local force_push=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --nothing-if-expected)
                nothing_if_expected=true
                shift
                ;;
            --build)
                force_build=true
                shift
                ;;
            --push)
                force_push=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                return 1
                ;;
        esac
    done

    debug "Running up command for: $hype_name (nothing-if-expected: $nothing_if_expected, force-build: $force_build, force-push: $force_push)"

    parse_hypefile "$hype_name"

    # Check if deployment is expected (if --nothing-if-expected is specified)
    if [[ "$nothing_if_expected" == "true" ]]; then
        debug "Checking if deployment is expected using releases check"
        if cmd_releases_check "$hype_name"; then
            info "Deployment already exists and matches expected state, skipping up command"
            return 0
        else
            debug "Deployment not in expected state, proceeding with up command"
        fi
    fi

    # Run build task if forced or if available and not explicitly overridden
    if [[ "$force_build" == "true" ]] || { [[ "$force_build" == "false" ]] && has_build_task "$hype_name"; }; then
        debug "Running build task (forced: $force_build, available: $(has_build_task "$hype_name" && echo "true" || echo "false"))"
        if ! run_build_task "$hype_name"; then
            error "Build task failed"
            return 1
        fi
        info "Build task completed successfully"
    else
        debug "Build task skipped (forced: $force_build, available: $(has_build_task "$hype_name" && echo "true" || echo "false"))"
    fi

    # Run push task if forced
    if [[ "$force_push" == "true" ]]; then
        debug "Force push requested, running push task"
        if ! cmd_task "$hype_name" "push"; then
            error "Push task failed"
            return 1
        fi
        info "Push task completed successfully"
    fi

    # Run dependencies first
    if ! depends_up "$hype_name"; then
        error "Dependencies failed"
        return 1
    fi

    # Run helmfile apply
    if ! run_helmfile_apply "$hype_name"; then
        error "Helmfile apply failed"
        return 1
    fi

    # Run addons up automatically after successful deployment
    if has_addons "$hype_name"; then
        info "Running addons up for hype: $hype_name"
        if ! addons_up "$hype_name"; then
            warn "Main deployment succeeded but addons setup failed"
            return 1
        fi
    else
        debug "No addons configured for $hype_name"
    fi

    info "Up command completed successfully for hype: $hype_name"
}

# Down command: helmfile destroy
cmd_down() {
    local hype_name="$1"
    
    debug "Running down command for: $hype_name"
    
    parse_hypefile "$hype_name"
    
    # Run addons down first if they exist
    if has_addons "$hype_name"; then
        info "Running addons down for hype: $hype_name"
        if ! addons_down "$hype_name"; then
            warn "Addons teardown failed, continuing with main deployment teardown"
        fi
    else
        debug "No addons configured for $hype_name"
    fi
    
    # Run helmfile destroy
    if ! run_helmfile_destroy "$hype_name"; then
        error "Helmfile destroy failed"
        return 1
    fi
    
    info "Down command completed successfully for hype: $hype_name"
}

# Restart command: down + up
cmd_restart() {
    local hype_name="$1"
    
    debug "Running restart command for: $hype_name"
    
    parse_hypefile "$hype_name"
    
    # Run down first
    info "Starting restart: running down phase"
    
    # Run addons down first if they exist
    if has_addons "$hype_name"; then
        info "Running addons down for hype: $hype_name"
        if ! addons_down "$hype_name"; then
            warn "Addons teardown failed during restart, continuing"
        fi
    else
        debug "No addons configured for $hype_name"
    fi
    
    if ! run_helmfile_destroy "$hype_name"; then
        error "Down phase failed during restart"
        return 1
    fi
    
    info "Down phase completed, starting up phase"
    
    # Run dependencies first
    if ! depends_up "$hype_name"; then
        error "Dependencies failed during restart"
        return 1
    fi
    
    # Run build task if available
    if has_build_task "$hype_name"; then
        debug "Build task found, running build"
        if ! run_build_task "$hype_name"; then
            error "Build task failed during restart"
            return 1
        fi
        info "Build task completed successfully"
    else
        debug "No build task found, skipping build step"
    fi
    
    # Run up (helmfile apply)
    if ! run_helmfile_apply "$hype_name"; then
        error "Up phase failed during restart"
        return 1
    fi
    
    # Run addons up automatically after successful deployment
    if has_addons "$hype_name"; then
        info "Running addons up for hype: $hype_name"
        if ! addons_up "$hype_name"; then
            warn "Main deployment succeeded but addons setup failed during restart"
            return 1
        fi
    else
        debug "No addons configured for $hype_name"
    fi
    
    info "Restart command completed successfully for hype: $hype_name"
}

# Init command: depends init + init + addons init
cmd_init() {
    local hype_name="$1"

    debug "Running init command for: $hype_name"

    parse_hypefile "$hype_name"

    # Run depends init first if configured
    local depends_list
    if depends_list=$(get_depends_list 2>/dev/null) && [[ -n "$depends_list" ]]; then
        info "Running depends init for hype: $hype_name"
        if ! depends_init "$hype_name"; then
            error "Dependencies initialization failed"
            return 1
        fi
    else
        debug "No dependencies configured for $hype_name"
    fi

    # Run main init (copied from init.sh builtin)
    info "Initializing default resources for: $hype_name"

    if [[ ! -f "$HYPE_SECTION_FILE" ]]; then
        debug "No hypefile section found"
    else
        # Get resource count first
        local resource_count
        resource_count=$(yq eval '.defaultResources | length' "$HYPE_SECTION_FILE" 2>/dev/null || echo "0")

        if [[ "$resource_count" -eq 0 ]]; then
            debug "No default resources found"
        else
            # Process each default resource by index
            for (( i=0; i<resource_count; i++ )); do
                local name type values_yaml

                name=$(yq eval ".defaultResources[$i].name" "$HYPE_SECTION_FILE" | sed "s/{{ \.Hype\.Name }}/$hype_name/g" | sed "s|{{ \.Hype\.CurrentDirectory }}|$(pwd)|g")
                type=$(yq eval ".defaultResources[$i].type" "$HYPE_SECTION_FILE")
                values_yaml=$(yq eval ".defaultResources[$i].values" "$HYPE_SECTION_FILE")

                debug "Processing resource $i: name=$name, type=$type"

                if [[ "$name" != "null" && "$type" != "null" && "$values_yaml" != "null" ]]; then
                    # Create resource logic from init.sh
                    create_resource "$name" "$type" "$values_yaml"
                fi
            done
        fi
    fi

    # Run addons init after if configured
    if has_addons "$hype_name"; then
        info "Running addons init for hype: $hype_name"
        if ! addons_init "$hype_name"; then
            error "Addons initialization failed"
            return 1
        fi
    else
        debug "No addons configured for $hype_name"
    fi

    info "Init command completed successfully for hype: $hype_name"
}

# Deinit command: addons deinit + deinit
cmd_deinit() {
    local hype_name="$1"

    debug "Running deinit command for: $hype_name"

    parse_hypefile "$hype_name"

    # Run addons deinit first if they exist
    if has_addons "$hype_name"; then
        info "Running addons deinit for hype: $hype_name"
        if ! addons_deinit "$hype_name"; then
            warn "Addons deinitialization failed, continuing with main deinitialization"
        fi
    else
        debug "No addons configured for $hype_name"
    fi

    # Run main deinit (copied from init.sh builtin)
    info "Deinitializing default resources for: $hype_name"

    if [[ ! -f "$HYPE_SECTION_FILE" ]]; then
        debug "No hypefile section found"
    else
        # Get resource count first
        local resource_count
        resource_count=$(yq eval '.defaultResources | length' "$HYPE_SECTION_FILE" 2>/dev/null || echo "0")

        if [[ "$resource_count" -eq 0 ]]; then
            debug "No default resources found"
        else
            # Process each default resource by index
            for (( i=0; i<resource_count; i++ )); do
                local name type

                name=$(yq eval ".defaultResources[$i].name" "$HYPE_SECTION_FILE" | sed "s/{{ \.Hype\.Name }}/$hype_name/g" | sed "s|{{ \.Hype\.CurrentDirectory }}|$(pwd)|g")
                type=$(yq eval ".defaultResources[$i].type" "$HYPE_SECTION_FILE")

                debug "Processing resource $i for deletion: name=$name, type=$type"

                if [[ "$name" != "null" && "$type" != "null" ]]; then
                    # Delete resource logic from init.sh
                    delete_resource "$name" "$type"
                fi
            done
        fi
    fi

    info "Deinit command completed successfully for hype: $hype_name"
}

# Check expectedReleases from helmfile.yaml
check_expected_releases() {
    local hype_name="$1"

    debug "Checking expected releases for hype: $hype_name"

    if [[ ! -f "$HELMFILE_SECTION_FILE" || ! -s "$HELMFILE_SECTION_FILE" ]]; then
        debug "No helmfile section found for $hype_name"
        return 0
    fi

    # Get expectedReleases from helmfile section
    local expected_releases
    expected_releases=$(yq eval '.expectedReleases[]' "$HELMFILE_SECTION_FILE" 2>/dev/null)

    if [[ -z "$expected_releases" ]]; then
        debug "No expectedReleases found in helmfile for $hype_name"
        return 0
    fi

    local missing_releases=()
    while IFS= read -r release; do
        if [[ -n "$release" ]]; then
            if ! helm list --filter="^${release}$" --short 2>/dev/null | grep -q "^${release}$"; then
                missing_releases+=("$release")
            fi
        fi
    done <<< "$expected_releases"

    if [[ ${#missing_releases[@]} -gt 0 ]]; then
        error "Missing expected releases: ${missing_releases[*]}"
        return 1
    fi

    info "All expected releases are deployed for hype: $hype_name"
    return 0
}

# Check defaultResources from hypefile.yaml
check_default_resources() {
    local hype_name="$1"

    debug "Checking default resources for hype: $hype_name"

    if [[ ! -f "$HYPE_SECTION_FILE" ]]; then
        debug "No hypefile section found for $hype_name"
        return 0
    fi

    # Get resource count first
    local resource_count
    resource_count=$(yq eval '.defaultResources | length' "$HYPE_SECTION_FILE" 2>/dev/null || echo "0")

    if [[ "$resource_count" -eq 0 ]]; then
        debug "No default resources found for $hype_name"
        return 0
    fi

    local missing_resources=()
    # Process each default resource by index
    for (( i=0; i<resource_count; i++ )); do
        local name type

        name=$(yq eval ".defaultResources[$i].name" "$HYPE_SECTION_FILE" | sed "s/{{ \.Hype\.Name }}/$hype_name/g" | sed "s|{{ \.Hype\.CurrentDirectory }}|$(pwd)|g")
        type=$(yq eval ".defaultResources[$i].type" "$HYPE_SECTION_FILE")

        if [[ "$name" != "null" && "$type" != "null" ]]; then
            case "$type" in
                "DefaultStateValues")
                    # Skip check for DefaultStateValues (local processing only)
                    ;;
                "StateValuesConfigmap"|"Configmap")
                    if ! kubectl get configmap "$name" >/dev/null 2>&1; then
                        missing_resources+=("ConfigMap:$name")
                    fi
                    ;;
                "Secrets")
                    if ! kubectl get secret "$name" >/dev/null 2>&1; then
                        missing_resources+=("Secret:$name")
                    fi
                    ;;
            esac
        fi
    done

    if [[ ${#missing_resources[@]} -gt 0 ]]; then
        error "Missing default resources: ${missing_resources[*]}"
        return 1
    fi

    info "All default resources exist for hype: $hype_name"
    return 0
}

# Releases command: manage releases with addons support
cmd_releases() {
    local hype_name="$1"
    shift
    local subcommand="${1:-}"

    case "$subcommand" in
        "check")
            debug "Running releases check command for: $hype_name"

            parse_hypefile "$hype_name"

            local main_status=0
            local addons_status=0

            # Check main hype releases
            if ! check_expected_releases "$hype_name"; then
                main_status=1
            fi

            # Check addons releases if configured
            if has_addons "$hype_name"; then
                info "Running addons releases check for hype: $hype_name"
                if ! addons_releases "$hype_name" "check"; then
                    addons_status=1
                fi
            else
                debug "No addons configured for $hype_name"
            fi

            # Return success only if both main and addons succeed
            if [[ $main_status -eq 0 && $addons_status -eq 0 ]]; then
                info "Releases check completed successfully for hype: $hype_name"
                return 0
            else
                error "Releases check failed for hype: $hype_name"
                return 1
            fi
            ;;
        *)
            error "Unknown releases subcommand: $subcommand"
            help_releases
            return 1
            ;;
    esac
}

# Resources command: manage resources with addons support
cmd_resources() {
    local hype_name="$1"
    shift
    local subcommand="${1:-}"

    case "$subcommand" in
        "check")
            debug "Running resources check command for: $hype_name"

            parse_hypefile "$hype_name"

            local main_status=0
            local addons_status=0

            # Check main hype resources
            if ! check_default_resources "$hype_name"; then
                main_status=1
            fi

            # Check addons resources if configured
            if has_addons "$hype_name"; then
                info "Running addons resources check for hype: $hype_name"
                if ! addons_resources "$hype_name" "check"; then
                    addons_status=1
                fi
            else
                debug "No addons configured for $hype_name"
            fi

            # Return success only if both main and addons succeed
            if [[ $main_status -eq 0 && $addons_status -eq 0 ]]; then
                info "Resources check completed successfully for hype: $hype_name"
                return 0
            else
                error "Resources check failed for hype: $hype_name"
                return 1
            fi
            ;;
        *)
            error "Unknown resources subcommand: $subcommand"
            help_resources
            return 1
            ;;
    esac
}