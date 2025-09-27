#!/bin/bash

# HYPE CLI Prepare Plugin
# Handles repository preparation workflow

# Builtin metadata (required)
BUILTIN_NAME="prepare"
BUILTIN_VERSION="1.0.0"
BUILTIN_DESCRIPTION="Repository preparation builtin"

# Register commands in global BUILTIN_COMMANDS array
BUILTIN_COMMANDS+=("prepare")

# Help functions
help_prepare() {
    cat <<EOF
Usage: hype <hype-name> prepare <url> --branch <branch> --path <path> [--trait <trait>]

Repository preparation workflow

This command performs repository setup by executing the following steps:
1. Validate trait configuration (if specified)
2. hype <hype-name> repo prepare <url> --branch <branch> --path <path>

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
    echo "Repository preparation workflow"
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

    # Save current environment to restore later
    local saved_hypefile="${HYPEFILE:-}"
    local saved_hype_dir="${HYPE_DIR:-}"
    local saved_hype_section_file="${HYPE_SECTION_FILE:-}"
    local saved_helmfile_section_file="${HELMFILE_SECTION_FILE:-}"
    local saved_taskfile_section_file="${TASKFILE_SECTION_FILE:-}"
    local saved_working_dir
    saved_working_dir="$(pwd)"

    info "Starting repository preparation workflow for hype: $hype_name"
    info "Repository: $repo_url"
    info "Branch: $branch"
    info "Path: $path"
    info "Trait: $trait"
    echo ""

    # Step 1: trait validation already completed above
    if [[ "$trait_specified" == "true" ]]; then
        info "Step 1/2: Using specified trait: $trait"
        echo ""
    else
        info "Step 1/2: No trait specified, proceeding without trait"
        echo ""
    fi
    
    # Define cleanup function for error handling
    restore_environment() {
        debug "Restoring environment due to error or completion"
        if [[ -n "$saved_hypefile" ]]; then
            export HYPEFILE="$saved_hypefile"
            debug "Restored HYPEFILE to: $HYPEFILE"
        else
            unset HYPEFILE
            debug "Cleared HYPEFILE (was not set originally)"
        fi

        if [[ -n "$saved_hype_dir" ]]; then
            export HYPE_DIR="$saved_hype_dir"
            debug "Restored HYPE_DIR to: $HYPE_DIR"
        else
            unset HYPE_DIR
            debug "Cleared HYPE_DIR (was not set originally)"
        fi

        if [[ -n "$saved_hype_section_file" ]]; then
            HYPE_SECTION_FILE="$saved_hype_section_file"
            debug "Restored HYPE_SECTION_FILE to: $HYPE_SECTION_FILE"
        else
            HYPE_SECTION_FILE=""
            debug "Cleared HYPE_SECTION_FILE (was not set originally)"
        fi

        if [[ -n "$saved_helmfile_section_file" ]]; then
            HELMFILE_SECTION_FILE="$saved_helmfile_section_file"
            debug "Restored HELMFILE_SECTION_FILE to: $HELMFILE_SECTION_FILE"
        else
            HELMFILE_SECTION_FILE=""
            debug "Cleared HELMFILE_SECTION_FILE (was not set originally)"
        fi

        if [[ -n "$saved_taskfile_section_file" ]]; then
            TASKFILE_SECTION_FILE="$saved_taskfile_section_file"
            debug "Restored TASKFILE_SECTION_FILE to: $TASKFILE_SECTION_FILE"
        else
            TASKFILE_SECTION_FILE=""
            debug "Cleared TASKFILE_SECTION_FILE (was not set originally)"
        fi

        if ! cd "$saved_working_dir"; then
            warn "Failed to restore working directory to: $saved_working_dir"
        else
            debug "Restored working directory to: $saved_working_dir"
        fi
    }

    # Step 2: repo prepare
    info "Step 2/2: Preparing repository..."
    if ! cmd_repo "$hype_name" "prepare" "$repo_url" --branch "$branch" --path "$path"; then
        error "Failed to prepare repository: $repo_url"
        restore_environment
        return 1
    fi
    info "✓ Repository preparation completed"
    echo ""

    # Step 2.5: Setup repository working directory if bound
    if ! setup_repo_workdir_if_bound "$hype_name"; then
        error "Failed to setup repository working directory for '$hype_name'"
        restore_environment
        return 1
    fi

    info "🎉 Repository preparation completed successfully for hype: $hype_name"
    info "Repository is ready for initialization and further configuration."

    # Restore original environment after successful completion
    restore_environment
}