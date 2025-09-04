#!/bin/bash

# HYPE CLI Repository Management Plugin
# Implements repository binding and management commands

set -euo pipefail

# Plugin metadata
PLUGIN_NAME="repository"
PLUGIN_VERSION="0.7.0"
PLUGIN_DESCRIPTION="Repository binding and management commands"

# Commands provided by this plugin
PLUGIN_COMMANDS=(
    "use"
    "unuse" 
    "update"
    "list"
)

# Repository use command
cmd_use() {
    local hype_name="$1"
    shift
    
    if [[ $# -lt 2 ]] || [[ "$1" != "repo" ]]; then
        error "Usage: hype <hype-name> use repo <repository> [--branch <branch>] [--path <path>]"
        exit 1
    fi
    
    local repository="$2"
    local branch=""
    local path=""
    
    # Parse options
    shift 2
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --branch)
                if [[ $# -lt 2 ]]; then
                    error "Option --branch requires a value"
                    exit 1
                fi
                branch="$2"
                shift 2
                ;;
            --path)
                if [[ $# -lt 2 ]]; then
                    error "Option --path requires a value"
                    exit 1
                fi
                path="$2"
                shift 2
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Validate repository
    if ! validate_repository "$repository"; then
        error "Repository not accessible: $repository"
        exit 10
    fi
    
    # Set binding and ensure working directory
    set_repository_binding "$hype_name" "$repository" "$branch" "$path"
    
    if ! ensure_working_directory "$hype_name"; then
        error "Failed to set up working directory"
        exit 13
    fi
    
    local binding actual_branch actual_path
    binding=$(get_repository_binding "$hype_name")
    actual_branch=$(parse_binding "$binding" "branch")
    actual_path=$(parse_binding "$binding" "path")
    
    if [[ -n "$actual_path" ]] && [[ "$actual_path" != "." ]]; then
        info "Repository bound: $hype_name -> $repository (branch: $actual_branch, path: $actual_path)"
    else
        info "Repository bound: $hype_name -> $repository (branch: $actual_branch)"
    fi
}

# Repository unuse command
cmd_unuse() {
    local hype_name="$1"
    
    local binding
    binding=$(get_repository_binding "$hype_name")
    
    if [[ -z "$binding" ]]; then
        warn "No repository binding found for: $hype_name"
        return 0
    fi
    
    local repository
    repository=$(parse_binding "$binding" "repository")
    
    # Ask for confirmation
    if [[ "${FORCE:-false}" != "true" ]]; then
        echo "This will remove the repository binding for '$hype_name'"
        echo "Repository: $repository"
        echo ""
        read -p "Remove working directory as well? [y/N]: " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            remove_working_directory "$hype_name"
            info "Working directory removed"
        fi
    else
        remove_working_directory "$hype_name"
    fi
    
    # Remove binding
    remove_repository_binding "$hype_name"
    info "Repository binding removed: $hype_name"
}

# Repository update command
cmd_update() {
    info "Updating all bound repositories..."
    
    local binding_count=0
    local success_count=0
    local failed_repos=()
    
    while IFS= read -r line; do
        if [[ -z "$line" ]]; then
            continue
        fi
        
        local hype_name binding_json
        hype_name=$(echo "$line" | cut -d'=' -f1)
        binding_json=$(echo "$line" | cut -d'=' -f2-)
        
        if [[ -z "$binding_json" ]] || [[ "$binding_json" == "null" ]]; then
            continue
        fi
        
        local repository branch
        repository=$(parse_binding "$binding_json" "repository")
        branch=$(parse_binding "$binding_json" "branch")
        
        if [[ -z "$repository" ]]; then
            continue
        fi
        
        ((binding_count++))
        
        info "Updating $hype_name ($repository:$branch)..."
        
        if ensure_working_directory "$hype_name"; then
            ((success_count++))
            info "✓ Updated $hype_name"
        else
            failed_repos+=("$hype_name")
            warn "✗ Failed to update $hype_name"
        fi
    done < <(get_all_bindings)
    
    if [[ $binding_count -eq 0 ]]; then
        info "No repository bindings found"
    else
        info ""
        info "Update summary:"
        info "  Total bindings: $binding_count"
        info "  Successful: $success_count"
        info "  Failed: ${#failed_repos[@]}"
        
        if [[ ${#failed_repos[@]} -gt 0 ]]; then
            warn "Failed repositories: ${failed_repos[*]}"
            exit 1
        fi
    fi
}

# Repository list command  
cmd_list() {
    local has_bindings=false
    
    # Print header
    printf "%-20s %-50s %-10s\n" "HYPE NAME" "REPOSITORY" "STATUS"
    printf "%-20s %-50s %-10s\n" "----------" "----------" "------"
    
    # Get all bindings and display
    while IFS= read -r line; do
        if [[ -z "$line" ]]; then
            continue
        fi
        
        has_bindings=true
        
        local hype_name binding_json
        hype_name=$(echo "$line" | cut -d'=' -f1)
        binding_json=$(echo "$line" | cut -d'=' -f2-)
        
        if [[ -z "$binding_json" ]] || [[ "$binding_json" == "null" ]]; then
            printf "%-20s %-50s %-10s\n" "$hype_name" "." "current-dir"
        else
            local repository branch path status
            repository=$(parse_binding "$binding_json" "repository")
            branch=$(parse_binding "$binding_json" "branch")
            path=$(parse_binding "$binding_json" "path")
            status=$(directory_exists "$hype_name")
            
            local display_repo="$repository"
            if [[ -n "$branch" ]]; then
                display_repo="$repository:$branch"
            fi
            if [[ -n "$path" ]] && [[ "$path" != "." ]]; then
                display_repo="$display_repo/$path"
            fi
            
            # Truncate long repository names
            if [[ ${#display_repo} -gt 50 ]]; then
                display_repo="${display_repo:0:47}..."
            fi
            
            printf "%-20s %-50s %-10s\n" "$hype_name" "$display_repo" "$status"
        fi
    done < <(get_all_bindings)
    
    # Show unbound environments that might exist in ConfigMaps or other places
    # This is a placeholder for future enhancement
    
    if [[ "$has_bindings" == "false" ]]; then
        echo "No repository bindings found"
    fi
}

# Execute repository command
execute_repository_command() {
    local command="$1"
    shift
    
    case "$command" in
        "use")
            cmd_use "$@"
            ;;
        "unuse")
            cmd_unuse "$@"
            ;;
        "update")
            cmd_update "$@"
            ;;
        "list")
            cmd_list "$@"
            ;;
        *)
            error "Unknown repository command: $command"
            exit 1
            ;;
    esac
}