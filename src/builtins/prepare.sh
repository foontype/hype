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
Usage: hype <hype-name> prepare <url> --branch <branch> --path <path> [--trait <trait>]

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
  --trait <trait>       Trait type (optional, uses current trait if not specified)

Examples:
  hype my-nginx prepare user/repo --trait production
  hype my-nginx prepare user/repo                        (uses current trait)
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
                    return 1
                fi
                shift
                ;;
        esac
    done
    
    # Validate required arguments
    if [[ -z "$hype_name" ]]; then
        error "Hype name is required"
        help_prepare
        return 1
    fi
    
    if [[ -z "$repo_url" ]]; then
        error "Repository URL is required"
        help_prepare
        return 1
    fi
    
    # Check trait configuration
    local trait_specified=true
    if [[ -z "$trait" ]]; then
        trait_specified=false
    fi

    # Get current trait
    local current_trait=""
    if cmd_trait "$hype_name" "check" >/dev/null 2>&1; then
        current_trait=$(cmd_trait "$hype_name" "check" 2>/dev/null)
    fi

    # Validate trait configuration based on requirements
    if [[ "$trait_specified" == "true" ]]; then
        # Case: trait specified
        if [[ -z "$current_trait" ]]; then
            # trait指定あり、カレントtraitなし → エラー
            error "Trait '$trait' specified but no current trait is set"
            error "Please set the trait first: hype $hype_name trait set $trait"
            return 1
        elif [[ "$current_trait" != "$trait" ]]; then
            # trait指定あり、カレントtraitと不一致 → エラー
            error "Trait mismatch: specified trait '$trait' differs from current trait '$current_trait'"
            error "Please either:"
            error "  1. Use current trait: hype $hype_name prepare <url> --trait $current_trait"
            error "  2. Change current trait: hype $hype_name trait set $trait"
            return 1
        fi
        # trait指定あり、カレントtraitと一致 → OK
        debug "Using specified trait: $trait (matches current trait)"
    else
        # Case: trait not specified
        if [[ -n "$current_trait" ]]; then
            # trait指定なし、カレントtraitあり → エラー
            error "Current trait '$current_trait' is set but no trait specified"
            error "Please either:"
            error "  1. Specify the current trait: hype $hype_name prepare <url> --trait $current_trait"
            error "  2. Clear current trait: hype $hype_name trait clear"
            return 1
        fi
        # trait指定なし、カレントtraitなし → OK
        debug "No trait specified and no current trait set, proceeding without trait"
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
    
    # Step 1: trait prepare (only if trait was explicitly specified)
    if [[ "$trait_specified" == "true" ]]; then
        info "Step 1/6: Preparing trait..."
        if ! cmd_trait "$hype_name" "prepare" "$trait"; then
            error "Failed to prepare trait: $trait"
            return 1
        fi
        info "✓ Trait preparation completed"
        echo ""
    else
        info "Step 1/6: No trait specified, skipping trait preparation"
        echo ""
    fi
    
    # Step 2: repo prepare
    info "Step 2/6: Preparing repository..."
    if ! cmd_repo "$hype_name" "prepare" "$repo_url" --branch "$branch" --path "$path"; then
        error "Failed to prepare repository: $repo_url"
        return 1
    fi
    info "✓ Repository preparation completed"
    echo ""

    # Step 2.5: Setup repository working directory if bound
    if ! setup_repo_workdir_if_bound "$hype_name"; then
        error "Failed to setup repository working directory for '$hype_name'"
        return 1
    fi
    
    # Step 2.5: Initialize hype environment
    info "Step 2.5/5: Initializing hype environment..."
    if ! cmd_init "$hype_name"; then
        error "Failed to initialize hype environment"
        return 1
    fi
    info "✓ Hype environment initialization completed"
    echo ""
    
    # Step 3: task build
    info "Step 3/6: Running build task..."
    if ! cmd_task "$hype_name" "build"; then
        error "Failed to run build task"
        return 1
    fi
    info "✓ Build task completed"
    echo ""
    
    # Step 4: task push
    info "Step 4/6: Running push task..."
    if ! cmd_task "$hype_name" "push"; then
        error "Failed to run push task"
        return 1
    fi
    info "✓ Push task completed"
    echo ""
    
    # Step 5: up
    info "Step 5/6: Deploying application..."
    if ! cmd_up "$hype_name"; then
        error "Failed to deploy application"
        return 1
    fi
    info "✓ Application deployment completed"
    echo ""
    
    info "🎉 Complete setup workflow finished successfully for hype: $hype_name"
    info "Your application should now be deployed and running."
}