#!/bin/bash

# HYPE CLI Parse Plugin
# Handles parsing of hypefile sections

# Builtin metadata (standardized)
BUILTIN_NAME="parse"
BUILTIN_VERSION="1.0.0"
BUILTIN_DESCRIPTION="Hypefile section parsing builtin"

# Register commands in global BUILTIN_COMMANDS array
BUILTIN_COMMANDS+=("parse")

# Help functions
help_parse() {
    cat <<EOF
Usage: hype <hype-name> parse section <section-type>

Show raw section content without headers

Section Types:
  hype           Show raw hype section
  helmfile       Show raw helmfile section
  taskfile       Show raw taskfile section

Examples:
  hype my-nginx parse section hype                  Show raw hype section
  hype my-nginx parse section helmfile              Show raw helmfile section
  hype my-nginx parse section taskfile              Show raw taskfile section
EOF
}

help_parse_brief() {
    echo "Show raw section without headers"
}

# Show raw sections without rendering info headers
cmd_parse_section() {
    local hype_name="$1"
    local section_type="$2"
    
    if [[ -z "$section_type" ]]; then
        error "Section type is required"
        error "Usage: hype <hype-name> parse section [hype|helmfile|taskfile]"
        return 1
    fi
    
    parse_hypefile "$hype_name"
    
    case "$section_type" in
        "hype")
            if [[ -f "$HYPE_SECTION_FILE" ]]; then
                cat "$HYPE_SECTION_FILE"
            fi
            ;;
        "helmfile")
            if [[ -f "$HELMFILE_SECTION_FILE" ]]; then
                cat "$HELMFILE_SECTION_FILE"
            fi
            ;;
        "taskfile")
            if [[ -f "$TASKFILE_SECTION_FILE" ]]; then
                cat "$TASKFILE_SECTION_FILE"
            fi
            ;;
        *)
            error "Unknown section type: $section_type"
            error "Valid options: hype, helmfile, taskfile"
            return 1
            ;;
    esac
}

# Parse command router
cmd_parse() {
    local hype_name="$1"
    local subcommand="${2:-}"
    
    case "$subcommand" in
        "section")
            local section_type="${3:-}"
            cmd_parse_section "$hype_name" "$section_type"
            ;;
        "")
            error "Missing parse subcommand"
            error "Usage: hype <hype-name> parse section [hype|helmfile|taskfile]"
            return 1
            ;;
        *)
            error "Unknown parse subcommand: $subcommand"
            error "Valid options: section"
            return 1
            ;;
    esac
}