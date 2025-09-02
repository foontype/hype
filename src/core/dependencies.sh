#!/bin/bash

# HYPE CLI Dependencies Module
# Check for required tools and dependencies

# Check if required tools are available
check_dependencies() {
    local missing=()
    
    if ! command -v kubectl >/dev/null 2>&1; then
        missing+=("kubectl")
    fi
    
    if ! command -v helmfile >/dev/null 2>&1; then
        missing+=("helmfile")
    fi
    
    # Check for correct yq version (mikefarah/yq)
    if ! command -v yq >/dev/null 2>&1; then
        missing+=("yq")
    elif ! yq --version 2>&1 | grep -q "mikefarah"; then
        error "Wrong yq version detected. Please install mikefarah/yq"
        missing+=("yq (mikefarah version)")
    fi
    
    # Check for helm diff plugin
    if ! helm plugin list | grep -q "diff"; then
        missing+=("helm-diff plugin")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Missing required dependencies: ${missing[*]}"
    fi
}