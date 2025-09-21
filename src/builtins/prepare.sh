#!/bin/bash

# HYPE CLI Prepare Plugin
# Handles complete project preparation workflow

# Builtin metadata (standardized)
BUILTIN_NAME="prepare"
BUILTIN_VERSION="1.0.0"
BUILTIN_DESCRIPTION="Complete project preparation builtin"

# Register commands in global BUILTIN_COMMANDS array
BUILTIN_COMMANDS+=("prepare")

# Help functions
help_prepare() {
    cat <<EOF
Usage: hype <hype-name> prepare <repository-url> [OPTIONS]

Complete project preparation workflow

This command provides a comprehensive preparation workflow:
1. Repository binding setup (bind repository if needed)
2. Initialize default resources from hypefile.yaml 
3. Build the project (if build task is available)

Options:
  --branch <branch>     Specify branch (default: main)
  --path <path>         Specify path within repository (default: .)

Examples:
  hype my-nginx prepare user/repo                              Complete preparation
  hype my-nginx prepare https://github.com/user/repo.git      Full URL preparation  
  hype my-nginx prepare user/repo --branch develop            With specific branch
EOF
}

help_prepare_brief() {
    echo "Complete project preparation workflow"
}

# Main prepare command
cmd_prepare() {
    local hype_name="$1"
    shift  # Remove hype_name from arguments
    
    if [[ $# -eq 0 ]]; then
        error "Repository URL is required"
        error "Usage: hype <hype-name> prepare <repository-url> [OPTIONS]"
        exit 1
    fi
    
    info "Starting complete preparation for: $hype_name"
    
    # Step 1: Repository binding setup
    info "Step 1: Repository binding setup"
    if cmd_repo_prepare "$hype_name" "$@"; then
        info "Repository binding completed successfully"
    else
        error "Repository binding failed"
        exit 1
    fi
    
    # Step 2: Initialize default resources
    info "Step 2: Initializing default resources"
    if cmd_init "$hype_name"; then
        info "Resource initialization completed successfully"
    else
        error "Resource initialization failed"
        exit 1
    fi
    
    # Step 3: Build the project (if build task exists)
    info "Step 3: Building project"
    if cmd_task "$hype_name" "build" 2>/dev/null; then
        info "Build completed successfully"
    else
        warn "Build task not found or failed - skipping build step"
        debug "This is not an error if your project doesn't have a build task defined"
    fi
    
    info "Complete preparation finished for: $hype_name"
    info "Your project is ready to use!"
}