#!/bin/bash

# HYPE CLI Resources Plugin
# Handles resource checking and management

# Builtin metadata (standardized)
BUILTIN_NAME="resources"
BUILTIN_VERSION="1.0.0"
BUILTIN_DESCRIPTION="Manage and check status of HYPE resources"

# Register commands in global BUILTIN_COMMANDS array
# Note: resources command is now registered in aliases.sh

# Check resource status
check_resource_status() {
    local name="$1"
    local type="$2"
    
    case "$type" in
        "DefaultStateValues")
            echo -e "${GREEN}✓${NC} DefaultStateValues (local processing)"
            return 0
            ;;
        "StateValuesConfigmap"|"Configmap")
            if kubectl get configmap "$name" >/dev/null 2>&1; then
                echo -e "${GREEN}✓${NC} ConfigMap $name exists"
                return 0
            else
                echo -e "${RED}✗${NC} ConfigMap $name missing"
                return 1
            fi
            ;;
        "Secrets")
            if kubectl get secret "$name" >/dev/null 2>&1; then
                echo -e "${GREEN}✓${NC} Secret $name exists"
                return 0
            else
                echo -e "${RED}✗${NC} Secret $name missing"
                return 1
            fi
            ;;
        *)
            echo -e "${YELLOW}?${NC} Unknown resource type: $type"
            return 1
            ;;
    esac
}

# Check if addons are configured
has_addons() {
    local hype_name="$1"
    local addons_list

    if ! addons_list=$(get_addons_list 2>/dev/null); then
        return 1
    fi

    [[ -n "$addons_list" ]]
}

# Check defaultResources from hypefile.yaml
check_default_resources() {
    local hype_name="$1"

    debug "Checking default resources for hype: $hype_name"

    if [[ ! -f "$HYPE_SECTION_FILE" ]]; then
        debug "No hypefile section found for $hype_name"
        return 0
    fi

    # Get resource count first
    local resource_count
    resource_count=$(yq eval '.defaultResources | length' "$HYPE_SECTION_FILE" 2>/dev/null || echo "0")

    if [[ "$resource_count" -eq 0 ]]; then
        debug "No default resources found for $hype_name"
        return 0
    fi

    local missing_resources=()
    # Process each default resource by index
    for (( i=0; i<resource_count; i++ )); do
        local name type

        name=$(yq eval ".defaultResources[$i].name" "$HYPE_SECTION_FILE" | sed "s/{{ \.Hype\.Name }}/$hype_name/g" | sed "s|{{ \.Hype\.CurrentDirectory }}|$(pwd)|g")
        type=$(yq eval ".defaultResources[$i].type" "$HYPE_SECTION_FILE")

        if [[ "$name" != "null" && "$type" != "null" ]]; then
            case "$type" in
                "DefaultStateValues")
                    # Skip check for DefaultStateValues (local processing only)
                    ;;
                "StateValuesConfigmap"|"Configmap")
                    if ! kubectl get configmap "$name" >/dev/null 2>&1; then
                        missing_resources+=("ConfigMap:$name")
                    fi
                    ;;
                "Secrets")
                    if ! kubectl get secret "$name" >/dev/null 2>&1; then
                        missing_resources+=("Secret:$name")
                    fi
                    ;;
            esac
        fi
    done

    if [[ ${#missing_resources[@]} -gt 0 ]]; then
        error "Missing default resources: ${missing_resources[*]}"
        return 1
    fi

    info "All default resources exist for hype: $hype_name"
    return 0
}

# Check command - display current resources and check if configuration exists
cmd_resources_check() {
    local hype_name="$1"
    
    info "Resources for: $hype_name"
    echo
    
    parse_hypefile "$hype_name"
    
    if [[ ! -f "$HYPE_SECTION_FILE" ]]; then
        info "No hypefile section found"
        return 1
    fi
    
    # Get resource count first
    local resource_count
    resource_count=$(yq eval '.defaultResources | length' "$HYPE_SECTION_FILE" 2>/dev/null || echo "0")
    
    if [[ "$resource_count" -eq 0 ]]; then
        info "No default resources configured"
        return 1
    fi
    
    # Display each default resource
    for (( i=0; i<resource_count; i++ )); do
        local name type
        
        name=$(yq eval ".defaultResources[$i].name" "$HYPE_SECTION_FILE" | sed "s/{{ \.Hype\.Name }}/$hype_name/g" | sed "s|{{ \.Hype\.CurrentDirectory }}|$(pwd)|g")
        type=$(yq eval ".defaultResources[$i].type" "$HYPE_SECTION_FILE")
        
        if [[ "$type" != "null" ]]; then
            if [[ "$type" == "DefaultStateValues" ]]; then
                echo "  - Type: $type (local processing)"
            elif [[ "$name" != "null" ]]; then
                echo "  - Name: $name, Type: $type"
            else
                echo "  - Type: $type"
            fi
        fi
    done
    
    echo
    info "Found $resource_count configured resource(s)"
    
    # Exit with status 0 since resources are configured
    return 0
}

# Main command function for resources (with dependencies and addons support)
cmd_resources() {
    local hype_name="$1"
    shift
    local subcommand="${1:-}"

    case "$subcommand" in
        "check")
            debug "Running resources check command for: $hype_name"

            parse_hypefile "$hype_name"

            local main_status=0
            local addons_status=0

            # Check main hype resources
            if ! check_default_resources "$hype_name"; then
                main_status=1
            fi

            # Check addons resources if configured
            if has_addons "$hype_name"; then
                info "Running addons resources check for hype: $hype_name"
                if ! addons_resources "$hype_name" "check"; then
                    addons_status=1
                fi
            else
                debug "No addons configured for $hype_name"
            fi

            # Return success only if both main and addons succeed
            if [[ $main_status -eq 0 && $addons_status -eq 0 ]]; then
                info "Resources check completed successfully for hype: $hype_name"
                return 0
            else
                error "Resources check failed for hype: $hype_name"
                return 1
            fi
            ;;
        "help"|"-h"|"--help"|"")
            help_resources_builtin
            ;;
        *)
            error "Unknown resources subcommand: $subcommand"
            help_resources_builtin
            return 1
            ;;
    esac
}

# Help function
help_resources_builtin() {
    cat << EOF
Usage: hype <hype-name> resources <subcommand> [options...]

Resources builtin for HYPE CLI - manage and check status of resources

Subcommands:
  check                   Display current resources and check if configuration exists (exit 0 if exists, exit 1 if not)
  help, -h, --help       Show this help message

Examples:
  hype my-nginx resources         Show this help
  hype my-nginx resources check   Display current resources for my-nginx
  hype my-nginx resources help    Show this help

The 'check' subcommand displays all default resources defined in the 
hypefile.yaml. It exits with status 0 if resources are configured, 
or status 1 if no resources are configured.
EOF
}

# Brief help for main help display
help_resources_brief() {
    echo "Manage and check status of HYPE resources"
}

# Builtin cleanup function (optional)
cleanup_resources() {
    debug "Resources builtin cleanup"
}