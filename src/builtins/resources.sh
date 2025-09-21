#!/bin/bash

# HYPE CLI Resources Plugin
# Handles resource checking and management

# Builtin metadata (standardized)
BUILTIN_NAME="resources"
BUILTIN_VERSION="1.0.0"
BUILTIN_DESCRIPTION="Manage and check status of HYPE resources"

# Register commands in global BUILTIN_COMMANDS array
BUILTIN_COMMANDS+=("resources")

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

# Check command - check status of default resources
cmd_resources_check() {
    local hype_name="$1"
    local has_missing_resources=false
    
    info "Resource status for: $hype_name"
    echo
    
    parse_hypefile "$hype_name"
    
    if [[ ! -f "$HYPE_SECTION_FILE" ]]; then
        info "No hypefile section found"
        exit 1
    fi
    
    # Get resource count first
    local resource_count
    resource_count=$(yq eval '.defaultResources | length' "$HYPE_SECTION_FILE" 2>/dev/null || echo "0")
    
    if [[ "$resource_count" -eq 0 ]]; then
        info "No default resources found"
        exit 1
    fi
    
    # Check status of each default resource
    for (( i=0; i<resource_count; i++ )); do
        local name type
        
        name=$(yq eval ".defaultResources[$i].name" "$HYPE_SECTION_FILE" | sed "s/{{ \.Hype\.Name }}/$hype_name/g" | sed "s|{{ \.Hype\.CurrentDirectory }}|$(pwd)|g")
        type=$(yq eval ".defaultResources[$i].type" "$HYPE_SECTION_FILE")
        
        if [[ "$type" != "null" ]]; then
            if [[ "$type" == "DefaultStateValues" ]]; then
                # DefaultStateValues doesn't have a name, use type for status
                check_resource_status "" "$type"
            elif [[ "$name" != "null" ]]; then
                if ! check_resource_status "$name" "$type"; then
                    has_missing_resources=true
                fi
            fi
        fi
    done
    
    # Exit with appropriate status
    if [[ "$has_missing_resources" == true ]]; then
        exit 1
    else
        exit 0
    fi
}

# Main command function for resources
cmd_resources() {
    local hype_name="$1"
    local subcommand="${2:-}"
    
    # Only shift if we have a subcommand
    if [[ -n "$subcommand" ]]; then
        shift 2
    else
        shift 1
    fi
    
    case "$subcommand" in
        "check")
            cmd_resources_check "$hype_name" "$@"
            ;;
        "help"|"-h"|"--help"|"")
            help_resources
            ;;
        *)
            error "Unknown resources subcommand: $subcommand"
            help_resources
            exit 1
            ;;
    esac
}

# Help function
help_resources() {
    cat << EOF
Usage: hype <hype-name> resources <subcommand> [options...]

Resources builtin for HYPE CLI - manage and check status of resources

Subcommands:
  check                   Check status of default resources (exit 0 if all exist, exit 1 if any missing)
  help, -h, --help       Show this help message

Examples:
  hype my-nginx resources         Show this help
  hype my-nginx resources check   Check resource status for my-nginx
  hype my-nginx resources help    Show this help

The 'check' subcommand lists all default resources defined in the 
hypefile.yaml and shows their current status in the Kubernetes cluster.
It exits with status 0 if all resources exist, or status 1 if any are missing
or if no resources are configured.
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