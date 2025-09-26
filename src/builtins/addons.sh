#!/bin/bash

# HYPE CLI Addons Builtin
# Manage addons for hype instances

BUILTIN_NAME="addons"
# shellcheck disable=SC2034
BUILTIN_VERSION="1.0.0"
# shellcheck disable=SC2034
BUILTIN_DESCRIPTION="Manage addons for hype instances"
BUILTIN_COMMANDS+=("addons")

builtin_addons_init() {
    debug "Builtin $BUILTIN_NAME initialized"
}

cmd_addons() {
    local hype_name="$1"
    shift
    local subcommand="${1:-}"
    
    case "$subcommand" in
        "up")
            addons_up "$hype_name"
            ;;
        "down")
            addons_down "$hype_name"
            ;;
        "list")
            addons_list "$hype_name"
            ;;
        "check")
            addons_check "$hype_name"
            ;;
        "help"|"-h"|"--help")
            help_addons
            ;;
        "")
            error "Missing subcommand. Use 'up', 'down', 'list', 'check', or 'help'"
            help_addons
            return 1
            ;;
        *)
            error "Unknown addons subcommand: $subcommand"
            help_addons
            return 1
            ;;
    esac
}

addons_up() {
    local hype_name="$1"

    info "Starting addons for $hype_name"

    parse_hypefile "$hype_name"

    local addons_list
    if ! addons_list=$(get_addons_list "$hype_name"); then
        debug "No addons found for $hype_name"
        return 0
    fi


    if [[ -z "$addons_list" ]]; then
        debug "No addons configured for $hype_name"
        return 0
    fi
    
    local count=0
    local current_entry=""
    local line

    while IFS= read -r line; do
        if [[ "$line" =~ ^hype:.*$ ]]; then
            # Process previous entry if exists
            if [[ -n "$current_entry" ]]; then
                # Check if this entry should be processed based on traits
                if should_process_entry_by_traits "$current_entry" "$hype_name"; then
                    count=$((count + 1))
                    local addon_hype
                    local addon_prepare

                    addon_hype=$(echo "$current_entry" | yq eval '.hype' -)
                    addon_prepare=$(echo "$current_entry" | yq eval '.prepare' -)

                    if [[ -z "$addon_hype" || "$addon_hype" == "null" ]]; then
                        error "Addon $count: missing 'hype' field"
                        return 1
                    fi

                    if [[ -z "$addon_prepare" || "$addon_prepare" == "null" ]]; then
                        error "Addon $count: missing 'prepare' field"
                        return 1
                    fi

                    info "Processing addon $count: $addon_hype"
                    debug "Running: cmd_prepare $addon_hype $addon_prepare"

                    if ! eval "cmd_prepare $addon_hype $addon_prepare"; then
                        error "Failed to prepare addon: $addon_hype"
                        return 1
                    fi

                    info "Addon $count completed: $addon_hype"
                else
                    debug "Skipping addon due to trait mismatch"
                fi
            fi
            
            # Start new entry
            current_entry="$line"
        else
            # Continue building current entry
            current_entry="$current_entry"$'\n'"$line"
        fi
    done <<< "$addons_list"
    
    # Process last entry
    if [[ -n "$current_entry" ]]; then
        # Check if this entry should be processed based on traits
        if should_process_entry_by_traits "$current_entry" "$hype_name"; then
            count=$((count + 1))
            local addon_hype
            local addon_prepare

            addon_hype=$(echo "$current_entry" | yq eval '.hype' -)
            addon_prepare=$(echo "$current_entry" | yq eval '.prepare' -)

            if [[ -z "$addon_hype" || "$addon_hype" == "null" ]]; then
                error "Addon $count: missing 'hype' field"
                return 1
            fi

            if [[ -z "$addon_prepare" || "$addon_prepare" == "null" ]]; then
                error "Addon $count: missing 'prepare' field"
                return 1
            fi

            info "Processing addon $count: $addon_hype"
            debug "Running: cmd_prepare $addon_hype $addon_prepare"

            if ! eval "cmd_prepare $addon_hype $addon_prepare"; then
                error "Failed to prepare addon: $addon_hype"
                return 1
            fi

            info "Addon $count completed: $addon_hype"
        else
            debug "Skipping last addon due to trait mismatch"
        fi
    fi
    
    if [[ $count -eq 0 ]]; then
        debug "No valid addons found for $hype_name"
    else
        info "All $count addons started for $hype_name"
    fi
}

addons_down() {
    local hype_name="$1"
    
    info "Stopping addons for $hype_name"
    
    parse_hypefile "$hype_name"
    
    local addons_list
    if ! addons_list=$(get_addons_list "$hype_name"); then
        debug "No addons found for $hype_name"
        return 0
    fi
    
    if [[ -z "$addons_list" ]]; then
        debug "No addons configured for $hype_name"
        return 0
    fi
    
    local addon_array=()
    local current_entry=""
    local line

    while IFS= read -r line; do
        if [[ "$line" =~ ^hype:.*$ ]]; then
            # Process previous entry if exists
            if [[ -n "$current_entry" ]]; then
                # Check if this entry should be processed based on traits
                if should_process_entry_by_traits "$current_entry" "$hype_name"; then
                    local addon_hype
                    addon_hype=$(echo "$current_entry" | yq eval '.hype' -)

                    if [[ -n "$addon_hype" && "$addon_hype" != "null" ]]; then
                        addon_array+=("$addon_hype")
                    fi
                else
                    debug "Skipping addon in down due to trait mismatch"
                fi
            fi
            
            # Start new entry
            current_entry="$line"
        else
            # Continue building current entry
            current_entry="$current_entry"$'\n'"$line"
        fi
    done <<< "$addons_list"
    
    # Process last entry
    if [[ -n "$current_entry" ]]; then
        # Check if this entry should be processed based on traits
        if should_process_entry_by_traits "$current_entry" "$hype_name"; then
            local addon_hype
            addon_hype=$(echo "$current_entry" | yq eval '.hype' -)

            if [[ -n "$addon_hype" && "$addon_hype" != "null" ]]; then
                addon_array+=("$addon_hype")
            fi
        else
            debug "Skipping last addon in down due to trait mismatch"
        fi
    fi
    
    local count=${#addon_array[@]}
    if [[ $count -eq 0 ]]; then
        debug "No valid addons found for $hype_name"
        return 0
    fi
    
    for ((i = count - 1; i >= 0; i--)); do
        local addon_hype="${addon_array[i]}"
        local addon_num=$((count - i))
        
        info "Stopping addon $addon_num: $addon_hype"
        debug "Running: hype $addon_hype helmfile destroy"
        
        if ! hype "$addon_hype" helmfile destroy; then
            error "Failed to destroy addon: $addon_hype"
            return 1
        fi
        
        info "Addon $addon_num stopped: $addon_hype"
    done
    
    info "All $count addons stopped for $hype_name"
}

addons_list() {
    local hype_name="$1"

    parse_hypefile "$hype_name"

    local addons_list
    if ! addons_list=$(get_addons_list "$hype_name"); then
        info "No addons found for $hype_name"
        return 0
    fi

    if [[ -z "$addons_list" ]]; then
        info "No addons configured for $hype_name"
        return 0
    fi

    info "Addons for $hype_name:"
    local count=0
    local current_entry=""
    local line

    while IFS= read -r line; do
        if [[ "$line" =~ ^hype:.*$ ]]; then
            # Process previous entry if exists
            if [[ -n "$current_entry" ]]; then
                count=$((count + 1))
                local addon_hype
                local addon_prepare

                addon_hype=$(echo "$current_entry" | yq eval '.hype' -)
                addon_prepare=$(echo "$current_entry" | yq eval '.prepare' -)

                echo "  $count. $addon_hype"
                echo "     prepare: $addon_prepare"
            fi

            # Start new entry
            current_entry="$line"
        else
            # Continue building current entry
            current_entry="$current_entry"$'\n'"$line"
        fi
    done <<< "$addons_list"

    # Process last entry
    if [[ -n "$current_entry" ]]; then
        count=$((count + 1))
        local addon_hype
        local addon_prepare

        addon_hype=$(echo "$current_entry" | yq eval '.hype' -)
        addon_prepare=$(echo "$current_entry" | yq eval '.prepare' -)

        echo "  $count. $addon_hype"
        echo "     prepare: $addon_prepare"
    fi

    if [[ $count -eq 0 ]]; then
        info "No valid addons found"
    fi
}

addons_check() {
    local hype_name="$1"

    debug "Checking addon releases for $hype_name"

    parse_hypefile "$hype_name"

    local addons_list
    if ! addons_list=$(get_addons_list "$hype_name"); then
        debug "No addons found for $hype_name"
        return 0
    fi

    if [[ -z "$addons_list" ]]; then
        debug "No addons configured for $hype_name"
        return 0
    fi

    local failed_addons=()
    local count=0
    local current_entry=""
    local line

    while IFS= read -r line; do
        if [[ "$line" =~ ^hype:.*$ ]]; then
            # Process previous entry if exists
            if [[ -n "$current_entry" ]]; then
                # Check if this entry should be processed based on traits
                if should_process_entry_by_traits "$current_entry" "$hype_name"; then
                    count=$((count + 1))
                    local addon_hype

                    addon_hype=$(echo "$current_entry" | yq eval '.hype' -)

                    if [[ -z "$addon_hype" || "$addon_hype" == "null" ]]; then
                        error "Addon $count: missing 'hype' field"
                        return 1
                    fi

                    debug "Checking releases for addon: $addon_hype"

                    if ! env HYPEFILE="$HYPEFILE" "$0" "$addon_hype" releases check; then
                        failed_addons+=("$addon_hype")
                    fi
                else
                    debug "Skipping addon check due to trait mismatch"
                fi
            fi

            # Start new entry
            current_entry="$line"
        else
            # Continue building current entry
            current_entry="$current_entry"$'\n'"$line"
        fi
    done <<< "$addons_list"

    # Process last entry
    if [[ -n "$current_entry" ]]; then
        # Check if this entry should be processed based on traits
        if should_process_entry_by_traits "$current_entry" "$hype_name"; then
            count=$((count + 1))
            local addon_hype

            addon_hype=$(echo "$current_entry" | yq eval '.hype' -)

            if [[ -z "$addon_hype" || "$addon_hype" == "null" ]]; then
                error "Addon $count: missing 'hype' field"
                return 1
            fi

            debug "Checking releases for addon: $addon_hype"

            if ! env HYPEFILE="$HYPEFILE" "$0" "$addon_hype" releases check; then
                failed_addons+=("$addon_hype")
            fi
        else
            debug "Skipping last addon check due to trait mismatch"
        fi
    fi

    # Report results
    if [[ ${#failed_addons[@]} -eq 0 ]]; then
        if [[ $count -eq 0 ]]; then
            info "No addons to check"
        else
            info "All $count addon releases are present"
        fi
        return 0
    else
        error "Addons with missing releases: ${failed_addons[*]}"
        return 1
    fi
}

help_addons() {
    cat << EOF
Usage: hype <hype-name> addons <command>

Manage addons for hype instances

Commands:
  up          Start all addons in order
  down        Stop all addons in reverse order
  list        List configured addons
  check       Check if all addon releases exist
  help        Show this help message

The addons are configured in the hype section of hypefile.yaml:

  addons:
    - hype: addon-name
      prepare: "repo/path --option value"
      matchTraits: [trait1, trait2]  # Optional: only process if current trait matches
    - hype: another-addon
      prepare: "local/repo --path example"

Examples:
  hype myapp addons up       Start all addons for myapp
  hype myapp addons down     Stop all addons for myapp
  hype myapp addons list     List addons for myapp
  hype myapp addons check    Check if all addon releases exist
EOF
}

help_addons_brief() {
    echo "Manage addons for hype instances"
}

builtin_addons_cleanup() {
    debug "Builtin $BUILTIN_NAME cleaned up"
}