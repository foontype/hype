#!/bin/bash

# Unit tests for releases builtin

# Create test environment
setup_test_env() {
    TEST_DIR=$(mktemp -d)
    export HYPE_DIR="$TEST_DIR"
    export HYPEFILE="$TEST_DIR/hypefile.yaml"
    export DEBUG="false"
    cd "$TEST_DIR"
}

# Cleanup test environment
cleanup_test_env() {
    if [[ -n "${TEST_DIR:-}" && -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

# Create test hypefile with releases section
create_test_hypefile() {
    local hype_name="$1"
    cat > "$HYPEFILE" << EOF
hype:
  expectedReleases:
    - hype-common
    - ${hype_name}-core-system
    - static-release
---
helmfile:
  chart: test
---
taskfile:
  test: echo "test"
EOF
}

# Mock helm command for testing
mock_helm_success() {
    cat > "$TEST_DIR/helm" << 'EOF'
#!/bin/bash
case "$1" in
    "list")
        case "$3" in
            "^hype-common$"|"^test-app-core-system$"|"^static-release$")
                echo "test-release"
                ;;
            *)
                exit 1
                ;;
        esac
        ;;
    *)
        exit 1
        ;;
esac
EOF
    chmod +x "$TEST_DIR/helm"
    export PATH="$TEST_DIR:$PATH"
}

# Mock helm command that fails for some releases
mock_helm_partial_failure() {
    cat > "$TEST_DIR/helm" << 'EOF'
#!/bin/bash
case "$1" in
    "list")
        case "$3" in
            "^hype-common$"|"^static-release$")
                echo "test-release"
                ;;
            "^test-app-core-system$")
                exit 1
                ;;
            *)
                exit 1
                ;;
        esac
        ;;
    *)
        exit 1
        ;;
esac
EOF
    chmod +x "$TEST_DIR/helm"
    export PATH="$TEST_DIR:$PATH"
}

# Source required modules
source_modules() {
    # Use absolute path from current working directory
    source "src/core/common.sh"
    source "src/core/config.sh"
    source "src/core/hypefile.sh"
    source "src/builtins/releases.sh"
}

# Test get_releases_list function
test_get_releases_list() {
    setup_test_env
    create_test_hypefile "test-app"
    source_modules
    
    # Parse hypefile
    parse_hypefile "test-app"
    
    # Get release list
    local releases
    releases=$(get_releases_list)
    
    # Check if expected releases are returned
    if echo "$releases" | grep -q "hype-common" && \
       echo "$releases" | grep -q "test-app-core-system" && \
       echo "$releases" | grep -q "static-release"; then
        echo "✓ get_releases_list returns expected releases"
        cleanup_test_env
        return 0
    else
        echo "✗ get_releases_list failed: $releases"
        cleanup_test_env
        return 1
    fi
}

# Test template variable expansion
test_template_expansion() {
    setup_test_env
    create_test_hypefile "my-service"
    source_modules
    
    # Parse hypefile
    parse_hypefile "my-service"
    
    # Get release list
    local releases
    releases=$(get_releases_list)
    
    # Check if template variable was expanded
    if echo "$releases" | grep -q "my-service-core-system"; then
        echo "✓ Template variable {{ .Hype.Name }} expanded correctly"
        cleanup_test_env
        return 0
    else
        echo "✗ Template expansion failed: $releases"
        cleanup_test_env
        return 1
    fi
}

# Test releases check with all releases existing
test_releases_check_success() {
    setup_test_env
    create_test_hypefile "test-app"
    source_modules
    mock_helm_success
    
    # Run releases check command
    if cmd_releases_check "test-app" >/dev/null 2>&1; then
        echo "✓ releases check succeeds when all releases exist"
        cleanup_test_env
        return 0
    else
        echo "✗ releases check failed when all releases should exist"
        cleanup_test_env
        return 1
    fi
}

# Test releases check with missing releases
test_releases_check_failure() {
    setup_test_env
    create_test_hypefile "test-app"
    source_modules
    mock_helm_partial_failure
    
    # Run releases check command
    if ! cmd_releases_check "test-app" >/dev/null 2>&1; then
        echo "✓ releases check fails when some releases are missing"
        cleanup_test_env
        return 0
    else
        echo "✗ releases check succeeded when it should have failed"
        cleanup_test_env
        return 1
    fi
}

# Test empty releases list
test_empty_releases() {
    setup_test_env
    cat > "$HYPEFILE" << EOF
hype:
  expectedReleases: []
EOF
    source_modules
    
    # Run releases check command
    if cmd_releases_check "test-app" >/dev/null 2>&1; then
        echo "✓ releases check succeeds with empty releases list"
        cleanup_test_env
        return 0
    else
        echo "✗ releases check failed with empty releases list"
        cleanup_test_env
        return 1
    fi
}

# Run tests
echo "Releases Builtin Unit Tests"
echo "==========================="

test_get_releases_list
test_template_expansion
test_releases_check_success
test_releases_check_failure
test_empty_releases

echo "Releases tests completed"