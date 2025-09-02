#!/bin/bash

# Unit tests for config module

# Source the config module
source "$(dirname "${BASH_SOURCE[0]}")/../src/core/config.sh"

# Test version is set
test_version_set() {
    if [[ -n "$HYPE_VERSION" ]]; then
        echo "✓ HYPE_VERSION is set: $HYPE_VERSION"
        return 0
    else
        echo "✗ HYPE_VERSION is not set"
        return 1
    fi
}

# Test default hypefile is set
test_hypefile_default() {
    if [[ "$HYPEFILE" == "hypefile.yaml" ]]; then
        echo "✓ HYPEFILE has correct default"
        return 0
    else
        echo "✗ HYPEFILE default incorrect: $HYPEFILE"
        return 1
    fi
}

# Test debug default is false
test_debug_default() {
    if [[ "$DEBUG" == "false" ]]; then
        echo "✓ DEBUG has correct default"
        return 0
    else
        echo "✗ DEBUG default incorrect: $DEBUG"
        return 1
    fi
}

# Run tests
echo "Config Module Unit Tests"
echo "========================"

test_version_set
test_hypefile_default
test_debug_default

echo "Config tests completed"