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
            ;;
        "StateValuesConfigmap"|"Configmap")
            if kubectl get configmap "$name" >/dev/null 2>&1; then
                echo -e "${GREEN}✓${NC} ConfigMap $name exists"
            else
                echo -e "${RED}✗${NC} ConfigMap $name missing"
            fi
            ;;
        "Secrets")
            if kubectl get secret "$name" >/dev/null 2>&1; then
                echo -e "${GREEN}✓${NC} Secret $name exists"
            else
                echo -e "${RED}✗${NC} Secret $name missing"
            fi
            ;;
        *)
            echo -e "${YELLOW}?${NC} Unknown resource type: $type"
            ;;
    esac
}

# Check command - check status of default resources
cmd_resources_check() {
    local hype_name="$1"
    
    info "Resource status for: $hype_name"
    echo
    
    parse_hypefile "$hype_name"
    
    if [[ ! -f "$HYPE_SECTION_FILE" ]]; then
        info "No hypefile section found"
        return
    fi
    
    # Get resource count first
    local resource_count
    resource_count=$(yq eval '.defaultResources | length' "$HYPE_SECTION_FILE" 2>/dev/null || echo "0")
    
    if [[ "$resource_count" -eq 0 ]]; then
        info "No default resources found"
        return
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
                check_resource_status "$name" "$type"
            fi
        fi
    done
}

# Main command function for resources
cmd_resources() {
    local hype_name="$1"
    local subcommand="${2:-}"
    shift 2
    
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
  check                   Check status of default resources
  help, -h, --help       Show this help message

Examples:
  hype my-hype resources check     Check resource status for my-hype
  hype my-hype resources help      Show this help

The 'check' subcommand lists all default resources defined in the 
hypefile.yaml and shows their current status in the Kubernetes cluster,
indicating whether they exist or are missing from the cluster.
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