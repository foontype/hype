#!/bin/bash

# Unit tests for config module

# Source the config module from proper path
source "$(dirname "${BASH_SOURCE[0]}")/../../src/core/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../src/core/config.sh"

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

# Test valid hype names
test_valid_hype_names() {
    local valid_names=("app" "my-app" "app123" "test-env-1" "a" "a1" "a-1" "web-server-prod")
    local failed=0
    
    for name in "${valid_names[@]}"; do
        if validate_hype_name "$name" 2>/dev/null; then
            echo "✓ Valid hype name accepted: $name"
        else
            echo "✗ Valid hype name rejected: $name"
            ((failed++))
        fi
    done
    
    return $failed
}

# Test invalid hype names
test_invalid_hype_names() {
    local invalid_names=("App" "1app" "app-" "-app" "app_test" "my@app" "" "APP" "test.app" "app/test")
    local failed=0
    
    for name in "${invalid_names[@]}"; do
        if ! validate_hype_name "$name" 2>/dev/null; then
            echo "✓ Invalid hype name rejected: '$name'"
        else
            echo "✗ Invalid hype name accepted: '$name'"
            ((failed++))
        fi
    done
    
    return $failed
}

# Test hype name length limit
test_hype_name_length_limit() {
    # Create a name longer than 253 characters
    local long_name=$(printf 'a%.0s' {1..254})
    
    if ! validate_hype_name "$long_name" 2>/dev/null; then
        echo "✓ Long hype name rejected (254 chars)"
        return 0
    else
        echo "✗ Long hype name accepted (should be rejected)"
        return 1
    fi
}

# Run tests
echo "Config Module Unit Tests"
echo "========================"

test_version_set
test_hypefile_default
test_debug_default
test_valid_hype_names
test_invalid_hype_names
test_hype_name_length_limit

echo "Config tests completed"