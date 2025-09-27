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
        "init")
            depends_init "$hype_name"
            ;;
        "deinit")
            depends_deinit "$hype_name"
            ;;
        "up")
            depends_up "$hype_name"
            ;;
        "down")
            depends_down "$hype_name"
            ;;
        "list")
            depends_list "$hype_name"
            ;;
        "check")
            depends_check "$hype_name"
            ;;
        "releases")
            shift
            depends_releases "$hype_name" "$@"
            ;;
        "resources")
            shift
            depends_resources "$hype_name" "$@"
            ;;
        "help"|"-h"|"--help")
            help_depends
            ;;
        "")
            error "Missing subcommand. Use 'init', 'deinit', 'up', 'down', 'list', 'check', 'releases', 'resources', or 'help'"
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

depends_init() {
    local hype_name="$1"

    info "Initializing dependencies for $hype_name"

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
    local line

    while IFS= read -r line; do
        if [[ "$line" =~ ^hype:.*$ ]]; then
            # Process previous entry if exists
            if [[ -n "$current_entry" ]]; then
                # Check if this entry should be processed based on traits
                if should_process_entry_by_traits "$current_entry" "$hype_name"; then
                    count=$((count + 1))
                    local depend_hype

                    depend_hype=$(echo "$current_entry" | yq eval '.hype' -)

                    if [[ -z "$depend_hype" || "$depend_hype" == "null" ]]; then
                        error "Dependency $count: missing 'hype' field"
                        return 1
                    fi

                    info "Initializing dependency $count: $depend_hype"
                    debug "Running: hype $depend_hype init"

                    if ! hype "$depend_hype" init; then
                        error "Failed to initialize dependency: $depend_hype"
                        return 1
                    fi

                    info "Dependency $count initialized: $depend_hype"
                else
                    debug "Skipping dependency due to trait mismatch"
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
        # Check if this entry should be processed based on traits
        if should_process_entry_by_traits "$current_entry" "$hype_name"; then
            count=$((count + 1))
            local depend_hype

            depend_hype=$(echo "$current_entry" | yq eval '.hype' -)

            if [[ -z "$depend_hype" || "$depend_hype" == "null" ]]; then
                error "Dependency $count: missing 'hype' field"
                return 1
            fi

            info "Initializing dependency $count: $depend_hype"
            debug "Running: hype $depend_hype init"

            if ! hype "$depend_hype" init; then
                error "Failed to initialize dependency: $depend_hype"
                return 1
            fi

            info "Dependency $count initialized: $depend_hype"
        else
            debug "Skipping last dependency due to trait mismatch"
        fi
    fi

    if [[ $count -eq 0 ]]; then
        debug "No valid dependencies found for $hype_name"
    else
        info "All $count dependencies initialized for $hype_name"
    fi
}

depends_deinit() {
    local hype_name="$1"

    info "Deinitializing dependencies for $hype_name"

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
    local line

    while IFS= read -r line; do
        if [[ "$line" =~ ^hype:.*$ ]]; then
            # Process previous entry if exists
            if [[ -n "$current_entry" ]]; then
                # Check if this entry should be processed based on traits
                if should_process_entry_by_traits "$current_entry" "$hype_name"; then
                    local depend_hype
                    depend_hype=$(echo "$current_entry" | yq eval '.hype' -)

                    if [[ -n "$depend_hype" && "$depend_hype" != "null" ]]; then
                        depend_array+=("$depend_hype")
                    fi
                else
                    debug "Skipping dependency in deinit due to trait mismatch"
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
        # Check if this entry should be processed based on traits
        if should_process_entry_by_traits "$current_entry" "$hype_name"; then
            local depend_hype
            depend_hype=$(echo "$current_entry" | yq eval '.hype' -)

            if [[ -n "$depend_hype" && "$depend_hype" != "null" ]]; then
                depend_array+=("$depend_hype")
            fi
        else
            debug "Skipping last dependency in deinit due to trait mismatch"
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

        info "Deinitializing dependency $dep_num: $depend_hype"
        debug "Running: hype $depend_hype deinit"

        if ! hype "$depend_hype" deinit; then
            error "Failed to deinitialize dependency: $depend_hype"
            return 1
        fi

        info "Dependency $dep_num deinitialized: $depend_hype"
    done

    info "All $count dependencies deinitialized for $hype_name"
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
    local line

    while IFS= read -r line; do
        if [[ "$line" =~ ^hype:.*$ ]]; then
            # Process previous entry if exists
            if [[ -n "$current_entry" ]]; then
                # Check if this entry should be processed based on traits
                if should_process_entry_by_traits "$current_entry" "$hype_name"; then
                    count=$((count + 1))
                    local depend_hype

                    depend_hype=$(echo "$current_entry" | yq eval '.hype' -)

                    if [[ -z "$depend_hype" || "$depend_hype" == "null" ]]; then
                        error "Dependency $count: missing 'hype' field"
                        return 1
                    fi

                    info "Processing dependency $count: $depend_hype"
                    debug "Running: hype $depend_hype up --nothing-if-expected --build --push"

                    if ! hype "$depend_hype" up --nothing-if-expected --build --push; then
                        error "Failed to start dependency: $depend_hype"
                        return 1
                    fi

                    info "Dependency $count completed: $depend_hype"
                else
                    debug "Skipping dependency due to trait mismatch"
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
        # Check if this entry should be processed based on traits
        if should_process_entry_by_traits "$current_entry" "$hype_name"; then
            count=$((count + 1))
            local depend_hype

            depend_hype=$(echo "$current_entry" | yq eval '.hype' -)

            if [[ -z "$depend_hype" || "$depend_hype" == "null" ]]; then
                error "Dependency $count: missing 'hype' field"
                return 1
            fi

            info "Processing dependency $count: $depend_hype"
            debug "Running: hype $depend_hype up --nothing-if-expected --build --push"

            if ! hype "$depend_hype" up --nothing-if-expected --build --push; then
                error "Failed to start dependency: $depend_hype"
                return 1
            fi

            info "Dependency $count completed: $depend_hype"
        else
            debug "Skipping last dependency due to trait mismatch"
        fi
    fi

    if [[ $count -eq 0 ]]; then
        debug "No valid dependencies found for $hype_name"
    else
        info "All $count dependencies started for $hype_name"
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
    local line

    while IFS= read -r line; do
        if [[ "$line" =~ ^hype:.*$ ]]; then
            # Process previous entry if exists
            if [[ -n "$current_entry" ]]; then
                # Check if this entry should be processed based on traits
                if should_process_entry_by_traits "$current_entry" "$hype_name"; then
                    local depend_hype
                    depend_hype=$(echo "$current_entry" | yq eval '.hype' -)

                    if [[ -n "$depend_hype" && "$depend_hype" != "null" ]]; then
                        depend_array+=("$depend_hype")
                    fi
                else
                    debug "Skipping dependency in down due to trait mismatch"
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
        # Check if this entry should be processed based on traits
        if should_process_entry_by_traits "$current_entry" "$hype_name"; then
            local depend_hype
            depend_hype=$(echo "$current_entry" | yq eval '.hype' -)

            if [[ -n "$depend_hype" && "$depend_hype" != "null" ]]; then
                depend_array+=("$depend_hype")
            fi
        else
            debug "Skipping last dependency in down due to trait mismatch"
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
        debug "Running: hype $depend_hype down"

        if ! hype "$depend_hype" down; then
            error "Failed to stop dependency: $depend_hype"
            return 1
        fi

        info "Dependency $dep_num stopped: $depend_hype"
    done

    info "All $count dependencies stopped for $hype_name"
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
    local line

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

depends_check() {
    local hype_name="$1"
    debug "Checking dependency releases for $hype_name (legacy check command)"
    depends_releases "$hype_name" "check"
}

depends_releases() {
    local hype_name="$1"
    local subcommand="${2:-}"

    case "$subcommand" in
        "check")
            depends_releases_check "$hype_name"
            ;;
        "help"|"-h"|"--help")
            help_depends_releases
            ;;
        "")
            error "Missing releases subcommand. Use 'check' or 'help'"
            help_depends_releases
            return 1
            ;;
        *)
            error "Unknown depends releases subcommand: $subcommand"
            help_depends_releases
            return 1
            ;;
    esac
}

depends_resources() {
    local hype_name="$1"
    local subcommand="${2:-}"

    case "$subcommand" in
        "check")
            depends_resources_check "$hype_name"
            ;;
        "help"|"-h"|"--help")
            help_depends_resources
            ;;
        "")
            error "Missing resources subcommand. Use 'check' or 'help'"
            help_depends_resources
            return 1
            ;;
        *)
            error "Unknown depends resources subcommand: $subcommand"
            help_depends_resources
            return 1
            ;;
    esac
}

depends_releases_check() {
    local hype_name="$1"

    debug "Checking dependency releases for $hype_name"

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

    local failed_dependencies=()
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
                    local depend_hype

                    depend_hype=$(echo "$current_entry" | yq eval '.hype' -)

                    if [[ -z "$depend_hype" || "$depend_hype" == "null" ]]; then
                        error "Dependency $count: missing 'hype' field"
                        return 1
                    fi

                    debug "Checking releases for dependency: $depend_hype"

                    if ! env HYPEFILE="$HYPEFILE" "$0" "$depend_hype" releases check; then
                        failed_dependencies+=("$depend_hype")
                    fi
                else
                    debug "Skipping dependency check due to trait mismatch"
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
        # Check if this entry should be processed based on traits
        if should_process_entry_by_traits "$current_entry" "$hype_name"; then
            count=$((count + 1))
            local depend_hype

            depend_hype=$(echo "$current_entry" | yq eval '.hype' -)

            if [[ -z "$depend_hype" || "$depend_hype" == "null" ]]; then
                error "Dependency $count: missing 'hype' field"
                return 1
            fi

            debug "Checking releases for dependency: $depend_hype"

            if ! env HYPEFILE="$HYPEFILE" "$0" "$depend_hype" releases check; then
                failed_dependencies+=("$depend_hype")
            fi
        else
            debug "Skipping last dependency check due to trait mismatch"
        fi
    fi

    # Report results
    if [[ ${#failed_dependencies[@]} -eq 0 ]]; then
        if [[ $count -eq 0 ]]; then
            info "No dependencies to check"
        else
            info "All $count dependency releases are present"
        fi
        return 0
    else
        error "Dependencies with missing releases: ${failed_dependencies[*]}"
        return 1
    fi
}

depends_resources_check() {
    local hype_name="$1"

    debug "Checking dependency resources for $hype_name"

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

    local failed_dependencies=()
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
                    local depend_hype

                    depend_hype=$(echo "$current_entry" | yq eval '.hype' -)

                    if [[ -z "$depend_hype" || "$depend_hype" == "null" ]]; then
                        error "Dependency $count: missing 'hype' field"
                        return 1
                    fi

                    debug "Checking resources for dependency: $depend_hype"

                    if ! env HYPEFILE="$HYPEFILE" "$0" "$depend_hype" resources check; then
                        failed_dependencies+=("$depend_hype")
                    fi
                else
                    debug "Skipping dependency check due to trait mismatch"
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
        # Check if this entry should be processed based on traits
        if should_process_entry_by_traits "$current_entry" "$hype_name"; then
            count=$((count + 1))
            local depend_hype

            depend_hype=$(echo "$current_entry" | yq eval '.hype' -)

            if [[ -z "$depend_hype" || "$depend_hype" == "null" ]]; then
                error "Dependency $count: missing 'hype' field"
                return 1
            fi

            debug "Checking resources for dependency: $depend_hype"

            if ! env HYPEFILE="$HYPEFILE" "$0" "$depend_hype" resources check; then
                failed_dependencies+=("$depend_hype")
            fi
        else
            debug "Skipping last dependency check due to trait mismatch"
        fi
    fi

    # Report results
    if [[ ${#failed_dependencies[@]} -eq 0 ]]; then
        if [[ $count -eq 0 ]]; then
            info "No dependencies to check"
        else
            info "All $count dependency resources are ready"
        fi
        return 0
    else
        error "Dependencies with failed resource checks: ${failed_dependencies[*]}"
        return 1
    fi
}

help_depends() {
    cat << EOF
Usage: hype <hype-name> depends <command>

Manage dependencies between hype instances

Commands:
  init        Initialize all dependencies
  deinit      Deinitialize all dependencies in reverse order
  up          Start all dependencies with --nothing-if-expected --build --push
  down        Stop all dependencies in reverse order
  list        List configured dependencies
  check       Check if all dependency releases exist (legacy command)
  releases    Manage dependency releases (check)
  resources   Manage dependency resources (check)
  help        Show this help message

The dependencies are configured in the hype section of hypefile.yaml:

  depends:
    - hype: dependency-name
      matchTraits: [trait1, trait2]  # Optional: only process if current trait matches
    - hype: another-dependency

Examples:
  hype myapp depends init              Initialize all dependencies for myapp
  hype myapp depends deinit            Deinitialize all dependencies for myapp
  hype myapp depends up                Start all dependencies for myapp
  hype myapp depends down              Stop all dependencies for myapp
  hype myapp depends list              List dependencies for myapp
  hype myapp depends check             Check if all dependency releases exist
  hype myapp depends releases check    Check if all dependency releases exist
  hype myapp depends resources check   Check if all dependency resources are ready
EOF
}

help_depends_releases() {
    cat << EOF
Usage: hype <hype-name> depends releases <command>

Manage dependency releases

Commands:
  check       Check if all dependency releases exist
  help        Show this help message

Examples:
  hype myapp depends releases check    Check if all dependency releases exist
EOF
}

help_depends_resources() {
    cat << EOF
Usage: hype <hype-name> depends resources <command>

Manage dependency resources

Commands:
  check       Check if all dependency resources are ready
  help        Show this help message

Examples:
  hype myapp depends resources check   Check if all dependency resources are ready
EOF
}

help_depends_brief() {
    echo "Manage dependencies between hype instances"
}

builtin_depends_cleanup() {
    debug "Builtin $BUILTIN_NAME cleaned up"
}