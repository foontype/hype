#!/bin/bash

# HYPE CLI Prepare Plugin
# Handles complete setup workflow in one command

# Builtin metadata (required)
BUILTIN_NAME="prepare"
BUILTIN_VERSION="1.0.0"
BUILTIN_DESCRIPTION="Complete setup workflow builtin"

# Register commands in global BUILTIN_COMMANDS array
BUILTIN_COMMANDS+=("prepare")

# Help functions
help_prepare() {
    cat <<EOF
Usage: hype <hype-name> prepare <url> --branch <branch> --path <path> --trait <trait>

Complete setup workflow in one command

This command performs a complete setup by executing the following steps:
1. hype <hype-name> trait prepare <trait>
2. hype <hype-name> repo prepare <url> --branch <branch> --path <path>
3. hype <hype-name> task build
4. hype <hype-name> task push
5. hype <hype-name> up

Options:
  --branch <branch>     Repository branch (default: main)
  --path <path>         Path within repository (default: .)
  --trait <trait>       Trait type (required)

Examples:
  hype my-nginx prepare user/repo --trait production
  hype my-nginx prepare https://github.com/user/repo.git --branch develop --path deploy --trait staging
EOF
}

help_prepare_brief() {
    echo "Complete setup workflow in one command"
}

# Main command function
cmd_prepare() {
    local hype_name="$1"
    shift
    local repo_url=""
    local branch=""
    local path=""
    local trait=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --branch)
                branch="$2"
                shift 2
                ;;
            --path)
                path="$2"
                shift 2
                ;;
            --trait)
                trait="$2"
                shift 2
                ;;
            *)
                if [[ -z "$repo_url" ]]; then
                    repo_url="$1"
                else
                    error "Unknown argument: $1"
                    help_prepare
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Validate required arguments
    if [[ -z "$hype_name" ]]; then
        error "Hype name is required"
        help_prepare
        exit 1
    fi
    
    if [[ -z "$repo_url" ]]; then
        error "Repository URL is required"
        help_prepare
        exit 1
    fi
    
    if [[ -z "$trait" ]]; then
        error "Trait is required"
        help_prepare
        exit 1
    fi
    
    # Set defaults
    branch="${branch:-main}"
    path="${path:-.}"
    
    info "Starting complete setup workflow for hype: $hype_name"
    info "Repository: $repo_url"
    info "Branch: $branch"
    info "Path: $path"
    info "Trait: $trait"
    echo ""
    
    # Step 1: trait prepare
    info "Step 1/5: Preparing trait..."
    if ! cmd_trait "$hype_name" "prepare" "$trait"; then
        error "Failed to prepare trait: $trait"
        exit 1
    fi
    info "✓ Trait preparation completed"
    echo ""
    
    # Step 2: repo prepare
    info "Step 2/5: Preparing repository..."
    if ! cmd_repo "$hype_name" "prepare" "$repo_url" --branch "$branch" --path "$path"; then
        error "Failed to prepare repository: $repo_url"
        exit 1
    fi
    info "✓ Repository preparation completed"
    echo ""
    
    # Step 3: task build
    info "Step 3/5: Running build task..."
    if ! cmd_task "$hype_name" "build"; then
        error "Failed to run build task"
        exit 1
    fi
    info "✓ Build task completed"
    echo ""
    
    # Step 4: task push
    info "Step 4/5: Running push task..."
    if ! cmd_task "$hype_name" "push"; then
        error "Failed to run push task"
        exit 1
    fi
    info "✓ Push task completed"
    echo ""
    
    # Step 5: up
    info "Step 5/5: Deploying application..."
    if ! cmd_up "$hype_name"; then
        error "Failed to deploy application"
        exit 1
    fi
    info "✓ Application deployment completed"
    echo ""
    
    info "🎉 Complete setup workflow finished successfully for hype: $hype_name"
    info "Your application should now be deployed and running."
}