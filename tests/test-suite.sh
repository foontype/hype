#!/bin/bash

# HYPE CLI Test Suite
# Main test runner for unit and integration tests

set -euo pipefail

# Test configuration
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
HYPE_BINARY="$BUILD_DIR/hype"

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Test result tracking
test_passed() {
    local test_name="$1"
    echo -e "${GREEN}✓${NC} $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

test_failed() {
    local test_name="$1"
    local error_msg="${2:-}"
    echo -e "${RED}✗${NC} $test_name"
    if [[ -n "$error_msg" ]]; then
        echo -e "  ${RED}Error:${NC} $error_msg"
    fi
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

test_skipped() {
    local test_name="$1"
    local reason="${2:-}"
    echo -e "${YELLOW}~${NC} $test_name (skipped)"
    if [[ -n "$reason" ]]; then
        echo -e "  ${YELLOW}Reason:${NC} $reason"
    fi
}

# Check if build exists
check_build() {
    echo "Checking build artifacts..."
    
    if [[ ! -f "$HYPE_BINARY" ]]; then
        echo -e "${RED}Error:${NC} Build artifact not found: $HYPE_BINARY"
        echo "Run 'task build' first"
        exit 1
    fi
    
    if [[ ! -x "$HYPE_BINARY" ]]; then
        echo -e "${RED}Error:${NC} Build artifact is not executable: $HYPE_BINARY"
        exit 1
    fi
    
    echo -e "${GREEN}✓${NC} Build artifacts found and executable"
}

# Test basic functionality
test_basic_functionality() {
    echo
    echo "Testing basic functionality..."
    
    # Test version command
    if output=$("$HYPE_BINARY" --version 2>&1) && [[ "$output" =~ "HYPE CLI version" ]]; then
        test_passed "Version command"
    else
        test_failed "Version command" "Output: $output"
    fi
    
    # Test help command
    if output=$("$HYPE_BINARY" --help 2>&1) && [[ "$output" =~ "HYPE CLI - Helmfile Wrapper Tool" ]]; then
        test_passed "Help command"
    else
        test_failed "Help command" "Output: $output"
    fi
    
    # Test no arguments (should show help)
    if output=$("$HYPE_BINARY" 2>&1) && [[ "$output" =~ "Usage:" ]]; then
        test_passed "No arguments shows help"
    else
        test_failed "No arguments shows help" "Output: $output"
    fi
}

# Test command parsing
test_command_parsing() {
    echo
    echo "Testing command parsing..."
    
    # Create temporary directory with hypefile for testing
    local test_root
    test_root=$(mktemp -d)
    echo "hype: test-hype" > "$test_root/hypefile.yaml"
    
    # Test unknown command
    output=$(cd "$test_root" && "$HYPE_BINARY" test-hype unknown-command 2>&1) || true
    if [[ "$output" =~ "Unknown command: unknown-command" ]]; then
        test_passed "Unknown command detection"
    else
        test_failed "Unknown command detection" "Output: $output"
    fi
    
    # Test missing arguments
    output=$(cd "$test_root" && "$HYPE_BINARY" test-hype 2>&1) || true
    if [[ "$output" =~ "Missing required arguments" ]]; then
        test_passed "Missing dependencies detection"
    else
        test_failed "Missing dependencies detection" "Output: $output"
    fi
    
    # Cleanup
    rm -rf "$test_root"
}

# Test plugin structure
test_plugin_structure() {
    echo
    echo "Testing plugin structure..."
    
    local plugins_found=0
    local expected_plugins=("init" "template" "parse" "trait" "upgrade" "task" "helmfile")
    
    for plugin in "${expected_plugins[@]}"; do
        if [[ -f "$PROJECT_ROOT/src/plugins/${plugin}.sh" ]]; then
            plugins_found=$((plugins_found + 1))
            test_passed "Plugin file exists: ${plugin}.sh"
        else
            test_failed "Plugin file missing: ${plugin}.sh"
        fi
    done
    
    if [[ $plugins_found -eq ${#expected_plugins[@]} ]]; then
        test_passed "All expected plugins found"
    else
        test_failed "Plugin count mismatch" "Found: $plugins_found, Expected: ${#expected_plugins[@]}"
    fi
}

# Test core modules
test_core_modules() {
    echo
    echo "Testing core modules..."
    
    local modules_found=0
    local expected_modules=("config" "common" "hypefile" "dependencies")
    
    for module in "${expected_modules[@]}"; do
        if [[ -f "$PROJECT_ROOT/src/core/${module}.sh" ]]; then
            modules_found=$((modules_found + 1))
            test_passed "Core module exists: ${module}.sh"
        else
            test_failed "Core module missing: ${module}.sh"
        fi
    done
    
    if [[ $modules_found -eq ${#expected_modules[@]} ]]; then
        test_passed "All expected core modules found"
    else
        test_failed "Core module count mismatch" "Found: $modules_found, Expected: ${#expected_modules[@]}"
    fi
}

# Run ShellCheck if available
test_shellcheck() {
    echo
    echo "Testing with ShellCheck..."
    
    if ! command -v shellcheck >/dev/null 2>&1; then
        test_skipped "ShellCheck tests" "shellcheck not installed"
        return
    fi
    
    local shellcheck_passed=true
    
    # Check built binary
    if shellcheck -e SC1091 -e SC2034 -e SC2317 "$HYPE_BINARY" >/dev/null 2>&1; then
        test_passed "ShellCheck: built binary"
    else
        test_failed "ShellCheck: built binary"
        shellcheck_passed=false
    fi
    
    # Check source files
    local source_files=()
    mapfile -t source_files < <(find "$PROJECT_ROOT/src" -name "*.sh" -type f)
    
    for file in "${source_files[@]}"; do
        local basename_file
        basename_file=$(basename "$file")
        if shellcheck -e SC1091 -e SC2034 -e SC2317 "$file" >/dev/null 2>&1; then
            test_passed "ShellCheck: $basename_file"
        else
            test_failed "ShellCheck: $basename_file"
            shellcheck_passed=false
        fi
    done
    
    if [[ "$shellcheck_passed" == true ]]; then
        test_passed "All ShellCheck tests passed"
    else
        test_failed "Some ShellCheck tests failed"
    fi
}

# Test hypefile discovery functionality
test_hypefile_discovery() {
    echo
    echo "Testing hypefile discovery..."
    
    # Create test directory structure and temporary hypefile
    local test_root
    test_root=$(mktemp -d)
    local test_hypefile="$test_root/hypefile.yaml"
    echo "# Test hypefile" > "$test_hypefile"
    
    # Test 1: Find hypefile in current directory
    echo "hype: test-hype" > "$test_hypefile"
    if (cd "$test_root" && env DEBUG=true "$HYPE_BINARY" test-hype init 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -q "Found hypefile at: $test_hypefile"); then
        test_passed "Hypefile discovery: current directory"
    else
        test_failed "Hypefile discovery: current directory"
    fi
    
    # Test 2: Find hypefile from subdirectory
    local test_subdir="$test_root/subdir/nested"
    mkdir -p "$test_subdir"
    if (cd "$test_subdir" && env DEBUG=true "$HYPE_BINARY" test-hype init 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -q "Found hypefile at: $test_hypefile"); then
        test_passed "Hypefile discovery: parent directory search"
    else
        test_failed "Hypefile discovery: parent directory search"
    fi
    
    # Test 3: Error when no hypefile found
    local test_empty_root
    test_empty_root=$(mktemp -d)
    local error_output
    error_output=$(cd "$test_empty_root" && "$HYPE_BINARY" test-hype init 2>&1) || true
    if echo "$error_output" | grep -q "Error: hypefile.yaml not found in current or parent directories"; then
        test_passed "Hypefile discovery: error when not found"
    else
        test_failed "Hypefile discovery: error when not found" "Actual output: $error_output"
    fi
    
    # Test 4: HYPE_DIR set correctly when hypefile found
    if (cd "$test_subdir" && env DEBUG=true "$HYPE_BINARY" test-hype init 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -q "Set HYPE_DIR to hypefile directory: $test_root"); then
        test_passed "HYPE_DIR: set to hypefile directory"
    else
        test_failed "HYPE_DIR: set to hypefile directory"
    fi
    
    # Cleanup
    rm -rf "$test_root" "$test_empty_root"
}

# Main test execution
main() {
    echo "HYPE CLI Test Suite"
    echo "==================="
    
    # Check prerequisites
    check_build
    
    # Run test suites
    test_basic_functionality
    test_command_parsing
    test_plugin_structure
    test_core_modules
    test_hypefile_discovery
    test_shellcheck
    
    # Show results
    echo
    echo "Test Results:"
    echo "============="
    echo -e "Total tests: $TESTS_TOTAL"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# Execute main function
main "$@"