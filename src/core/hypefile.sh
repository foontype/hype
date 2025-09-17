#!/bin/bash

# HYPE CLI Hypefile Parsing Module
# Functions for parsing and managing hypefile.yaml sections

# Global variables for temporary files
HYPE_SECTION_FILE=""
HELMFILE_SECTION_FILE=""
TASKFILE_SECTION_FILE=""

# Parse hypefile.yaml into sections
parse_hypefile() {
    local hype_name="$1"
    
    if [[ ! -f "$HYPEFILE" ]]; then
        die "Hypefile not found: $HYPEFILE"
    fi
    
    debug "Parsing hypefile: $HYPEFILE"
    
    # Create temporary files
    HYPE_SECTION_FILE=$(mktemp)
    HELMFILE_SECTION_FILE=$(mktemp --suffix=.yaml.gotmpl)
    TASKFILE_SECTION_FILE=$(mktemp --suffix=.yaml)
    
    # Split file on "---" separator (supports up to 3 sections)
    awk -v hype_file="$HYPE_SECTION_FILE" -v helmfile_file="$HELMFILE_SECTION_FILE" -v taskfile_file="$TASKFILE_SECTION_FILE" '
    BEGIN { section = "hype"; section_count = 0 }
    /^---$/ { 
        section_count++
        if (section_count == 1) section = "helmfile"
        else if (section_count == 2) section = "taskfile"
        next 
    }
    { 
        if (section == "hype") print > hype_file
        else if (section == "helmfile") print > helmfile_file
        else if (section == "taskfile") print > taskfile_file
    }
    ' "$HYPEFILE"
    
    # Replace template variables with actual values (hype section only)
    sed -i "s/{{ \.Hype\.Name }}/$hype_name/g" "$HYPE_SECTION_FILE"
    sed -i "s|{{ \.Hype\.CurrentDirectory }}|$(pwd)|g" "$HYPE_SECTION_FILE"
    
    # Replace {{ .Hype.Trait }} with actual trait value (hype section only)
    local trait_value
    if trait_value=$(get_hype_trait "$hype_name" 2>/dev/null); then
        debug "Found trait for template replacement: $trait_value"
        sed -i "s/{{ \.Hype\.Trait }}/$trait_value/g" "$HYPE_SECTION_FILE"
    else
        debug "No trait found, removing trait template variables"
        sed -i "s/{{ \.Hype\.Trait }}//g" "$HYPE_SECTION_FILE"
    fi
    
    # Note: TASKFILE_SECTION_FILE is not processed here - it keeps its original template variables
    # for go-task to process with environment variables
    
    debug "Created temporary files: $HYPE_SECTION_FILE, $HELMFILE_SECTION_FILE, $TASKFILE_SECTION_FILE"
    
    # Debug: Show contents of temporary files
    if [[ "$DEBUG" == "true" ]]; then
        debug "=== HYPE SECTION CONTENT ==="
        cat "$HYPE_SECTION_FILE" >&2
        debug "=== END HYPE SECTION ==="
        
        debug "=== HELMFILE SECTION CONTENT ==="
        cat "$HELMFILE_SECTION_FILE" >&2
        debug "=== END HELMFILE SECTION ==="
        
        debug "=== TASKFILE SECTION CONTENT ==="
        cat "$TASKFILE_SECTION_FILE" >&2
        debug "=== END TASKFILE SECTION ==="
    fi
}

# Cleanup temporary files
cleanup() {
    if [[ -n "${HYPE_SECTION_FILE:-}" && -f "$HYPE_SECTION_FILE" ]]; then
        rm -f "$HYPE_SECTION_FILE"
    fi
    if [[ -n "${HELMFILE_SECTION_FILE:-}" && -f "$HELMFILE_SECTION_FILE" ]]; then
        rm -f "$HELMFILE_SECTION_FILE"
    fi
    if [[ -n "${TASKFILE_SECTION_FILE:-}" && -f "$TASKFILE_SECTION_FILE" ]]; then
        rm -f "$TASKFILE_SECTION_FILE"
    fi
}

# Set up cleanup trap
trap cleanup EXIT

# Get default resources from hype section
get_default_resources() {
    if [[ ! -f "$HYPE_SECTION_FILE" ]]; then
        return
    fi
    
    yq eval '.defaultResources[]' "$HYPE_SECTION_FILE" 2>/dev/null || true
}

# Get release probe list from hype section
# Note: Template variables are already expanded by parse_hypefile()
get_release_probe_list() {
    if [[ ! -f "$HYPE_SECTION_FILE" ]]; then
        return
    fi
    
    yq eval '.hype.releaseProbe[]' "$HYPE_SECTION_FILE" 2>/dev/null || true
}