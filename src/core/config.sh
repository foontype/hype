#!/bin/bash

# HYPE CLI Configuration Module
# Core configuration settings and environment variables

# Default configuration
HYPEFILE="${HYPEFILE:-hypefile.yaml}"
HYPE_LOG="${HYPE_LOG:-stdout}"

# Debug and trace modes
DEBUG="${DEBUG:-false}"
TRACE="${TRACE:-false}"

# Enable trace mode if requested
if [[ "$TRACE" == "true" ]]; then
    set -x
fi