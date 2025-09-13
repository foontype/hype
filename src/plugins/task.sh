#!/bin/bash

# HYPE CLI Task Plugin
# Handles task execution from taskfile sections

# Plugin metadata
PLUGIN_NAME="task"
PLUGIN_VERSION="1.0.0"
PLUGIN_DESCRIPTION="Task execution plugin"
PLUGIN_COMMANDS=("task")

# Help function for task command
help_task() {
    cat << EOF
  task <task-name> [args...]     Run task from taskfile section
EOF
}

# Run task command
cmd_task() {
    local hype_name="$1"
    local task_name="$2"
    shift 2
    local task_args=("$@")
    
    if [[ -z "$task_name" ]]; then
        error "Task name is required"
        error "Usage: hype <hype-name> task <task-name> [args...]"
        exit 1
    fi
    
    debug "Running task '$task_name' for: $hype_name"
    debug "Task args: ${task_args[*]}"
    
    parse_hypefile "$hype_name"
    
    # Check if taskfile section exists
    if [[ ! -f "$TASKFILE_SECTION_FILE" || ! -s "$TASKFILE_SECTION_FILE" ]]; then
        error "No taskfile section found in hypefile"
        error "Add a taskfile section after the second '---' separator"
        exit 1
    fi
    
    # Validate task exists in taskfile using task command itself
    if ! task --taskfile "$TASKFILE_SECTION_FILE" --list-all 2>/dev/null | grep -E "^\* $task_name:" >/dev/null 2>&1; then
        # Fallback: show all available tasks
        local all_tasks
        all_tasks=$(task --taskfile "$TASKFILE_SECTION_FILE" --list-all 2>/dev/null | grep -E "^\*" | sed 's/^\* //' | cut -d: -f1 | tr '\n' ' ' | sed 's/ $//')
        
        error "Task '$task_name' not found in taskfile section"
        if [[ -n "$all_tasks" ]]; then
            error "Available tasks: ${all_tasks// /, }"
        fi
        exit 1
    fi
    
    # Check if task command is available
    if ! command -v task >/dev/null 2>&1; then
        die "Task runner 'task' not found. Please install go-task: https://taskfile.dev/installation/"
    fi
    
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
    
    debug "Set environment variables - HYPE_NAME: $hype_name, HYPE_CURRENT_DIRECTORY: $(pwd)"
    
    # Run task with the temporary taskfile in the hype project directory
    local cmd=("task" "--taskfile" "$TASKFILE_SECTION_FILE" "--dir" "$HYPE_CURRENT_DIRECTORY" "$task_name")
    
    # Add user-provided arguments
    if [[ ${#task_args[@]} -gt 0 ]]; then
        cmd+=("${task_args[@]}")
    fi
    
    debug "Executing task command: ${cmd[*]}"
    info "Running task '$task_name' for hype: $hype_name"
    
    # Execute the task command
    "${cmd[@]}"
}