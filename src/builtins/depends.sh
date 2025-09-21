#!/bin/bash

# HYPE CLI Depends Builtin
# Manage dependencies between hype instances

BUILTIN_NAME="depends"
# shellcheck disable=SC2034
BUILTIN_VERSION="1.0.0"
# shellcheck disable=SC2034
BUILTIN_DESCRIPTION="Manage dependencies between hype instances"
BUILTIN_COMMANDS+=("depends")

builtin_depends_init() {
    debug "Builtin $BUILTIN_NAME initialized"
}

cmd_depends() {
    local hype_name="$1"
    shift
    local subcommand="${1:-}"
    
    case "$subcommand" in
        "up")
            depends_up "$hype_name"
            ;;
        "down")
            depends_down "$hype_name"
            ;;
        "list")
            depends_list "$hype_name"
            ;;
        "help"|"-h"|"--help")
            help_depends
            ;;
        "")
            error "Missing subcommand. Use 'up', 'down', 'list', or 'help'"
            help_depends
            return 1
            ;;
        *)
            error "Unknown depends subcommand: $subcommand"
            help_depends
            return 1
            ;;
    esac
}

depends_up() {
    local hype_name="$1"
    
    info "Starting dependencies for $hype_name"
    
    parse_hypefile "$hype_name"
    
    local depends_list
    if ! depends_list=$(get_depends_list); then
        debug "No dependencies found for $hype_name"
        return 0
    fi
    
    if [[ -z "$depends_list" ]]; then
        debug "No dependencies configured for $hype_name"
        return 0
    fi
    
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
                debug "Running: hype $depend_hype prepare $depend_prepare"
                
                if ! hype "$depend_hype" prepare "$depend_prepare"; then
                    error "Failed to prepare dependency: $depend_hype"
                    return 1
                fi
                
                success "Dependency $count completed: $depend_hype"
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
        debug "Running: hype $depend_hype prepare $depend_prepare"
        
        if ! hype "$depend_hype" prepare "$depend_prepare"; then
            error "Failed to prepare dependency: $depend_hype"
            return 1
        fi
        
        success "Dependency $count completed: $depend_hype"
    fi
    
    if [[ $count -eq 0 ]]; then
        debug "No valid dependencies found for $hype_name"
    else
        success "All $count dependencies started for $hype_name"
    fi
}

depends_down() {
    local hype_name="$1"
    
    info "Stopping dependencies for $hype_name"
    
    parse_hypefile "$hype_name"
    
    local depends_list
    if ! depends_list=$(get_depends_list); then
        debug "No dependencies found for $hype_name"
        return 0
    fi
    
    if [[ -z "$depends_list" ]]; then
        debug "No dependencies configured for $hype_name"
        return 0
    fi
    
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
        
        success "Dependency $dep_num stopped: $depend_hype"
    done
    
    success "All $count dependencies stopped for $hype_name"
}

depends_list() {
    local hype_name="$1"
    
    parse_hypefile "$hype_name"
    
    local depends_list
    if ! depends_list=$(get_depends_list); then
        info "No dependencies found for $hype_name"
        return 0
    fi
    
    if [[ -z "$depends_list" ]]; then
        info "No dependencies configured for $hype_name"
        return 0
    fi
    
    info "Dependencies for $hype_name:"
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
                
                echo "  $count. $depend_hype"
                echo "     prepare: $depend_prepare"
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
        
        echo "  $count. $depend_hype"
        echo "     prepare: $depend_prepare"
    fi
    
    if [[ $count -eq 0 ]]; then
        info "No valid dependencies found"
    fi
}

help_depends() {
    cat << EOF
Usage: hype <hype-name> depends <command>

Manage dependencies between hype instances

Commands:
  up          Start all dependencies in order
  down        Stop all dependencies in reverse order
  list        List configured dependencies
  help        Show this help message

The dependencies are configured in the hype section of hypefile.yaml:

  dependsOn:
    - hype: dependency-name
      prepare: repo/path --option value
    - hype: another-dependency
      prepare: local/repo --path example

Examples:
  hype myapp depends up       Start all dependencies for myapp
  hype myapp depends down     Stop all dependencies for myapp
  hype myapp depends list     List dependencies for myapp
EOF
}

help_depends_brief() {
    echo "Manage dependencies between hype instances"
}

builtin_depends_cleanup() {
    debug "Builtin $BUILTIN_NAME cleaned up"
}