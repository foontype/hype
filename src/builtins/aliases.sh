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

Build and deploy (task build + helmfile apply)

This command first runs the build task (if available) and then
applies the helmfile configuration to deploy your application.

Examples:
  hype my-nginx up                   Build and deploy my-nginx
EOF
}

help_up_brief() {
    echo "Build and deploy (task build + helmfile apply)"
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

This command performs a complete restart by first destroying
the current deployment and then rebuilding and redeploying.

Examples:
  hype my-nginx restart              Restart my-nginx deployment
EOF
}

help_restart_brief() {
    echo "Restart deployment (down + up)"
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
    
    info "Running helmfile apply for hype: $hype_name"
    cmd_helmfile "$hype_name" "apply"
}

# Run helmfile destroy
run_helmfile_destroy() {
    local hype_name="$1"
    
    info "Running helmfile destroy for hype: $hype_name"
    cmd_helmfile "$hype_name" "destroy"
}

# Up command: build (if available) + helmfile apply
cmd_up() {
    local hype_name="$1"
    
    debug "Running up command for: $hype_name"
    
    parse_hypefile "$hype_name"
    
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
    
    info "Up command completed successfully for hype: $hype_name"
}

# Down command: helmfile destroy
cmd_down() {
    local hype_name="$1"
    
    debug "Running down command for: $hype_name"
    
    parse_hypefile "$hype_name"
    
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
    if ! run_helmfile_destroy "$hype_name"; then
        error "Down phase failed during restart"
        return 1
    fi
    
    info "Down phase completed, starting up phase"
    
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
    
    info "Restart command completed successfully for hype: $hype_name"
}