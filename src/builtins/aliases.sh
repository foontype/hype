#!/bin/bash

# HYPE CLI Aliases Plugin
# Handles deployment lifecycle aliases: up, down, restart

# Builtin metadata (standardized)
BUILTIN_NAME="aliases"
BUILTIN_VERSION="1.0.0"
BUILTIN_DESCRIPTION="Deployment lifecycle aliases"

# Register commands in global BUILTIN_COMMANDS array
BUILTIN_COMMANDS+=("up")
BUILTIN_COMMANDS+=("down")
BUILTIN_COMMANDS+=("restart")

# Help functions for each command
help_up() {
    cat <<EOF
Usage: hype <hype-name> up

Start dependencies, build and deploy (dependencies + task build + helmfile apply)

This command performs a complete deployment workflow:
1. Start all dependencies (if configured in depends)
2. Run the build task (if available)
3. Apply the helmfile configuration to deploy your application

Examples:
  hype my-nginx up                   Deploy my-nginx with all dependencies
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
    
    debug "Running up command for: $hype_name"
    
    parse_hypefile "$hype_name"
    
    # Run dependencies first
    if ! run_dependencies "$hype_name"; then
        error "Dependencies failed"
        return 1
    fi
    
    # Run build task if available
    if has_build_task "$hype_name"; then
        debug "Build task found, running build"
        if ! run_build_task "$hype_name"; then
            error "Build task failed"
            return 1
        fi
        info "Build task completed successfully"
    else
        debug "No build task found, skipping build step"
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
    if ! run_dependencies "$hype_name"; then
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