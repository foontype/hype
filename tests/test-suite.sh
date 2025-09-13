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

# Test builtin structure
test_builtin_structure() {
    echo
    echo "Testing builtin structure..."
    
    local builtins_found=0
    local expected_builtins=("init" "template" "parse" "trait" "upgrade" "task" "helmfile")
    
    for builtin in "${expected_builtins[@]}"; do
        if [[ -f "$PROJECT_ROOT/src/builtins/${builtin}.sh" ]]; then
            builtins_found=$((builtins_found + 1))
            test_passed "Builtin file exists: ${builtin}.sh"
        else
            test_failed "Builtin file missing: ${builtin}.sh"
        fi
    done
    
    if [[ $builtins_found -eq ${#expected_builtins[@]} ]]; then
        test_passed "All expected builtins found"
    else
        test_failed "Builtin count mismatch" "Found: $builtins_found, Expected: ${#expected_builtins[@]}"
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
    echo "[DEBUG] Created test directory: $test_root" >&2
    local test_hypefile="$test_root/hypefile.yaml"
    echo "# Test hypefile" > "$test_hypefile"
    echo "[DEBUG] Created test hypefile: $test_hypefile" >&2
    
    # Test 1: Find hypefile in current directory
    echo "hype: test-hype" > "$test_hypefile"
    echo "[DEBUG] Test 1: Starting hypefile discovery test from current directory" >&2
    
    # Add timeout to prevent hanging
    local test1_output
    if test1_output=$(timeout 10s bash -c "cd '$test_root' && env DEBUG=true HYPE_LOG=stdout '$HYPE_BINARY' test-hype init 2>&1 | sed 's/\x1b\[[0-9;]*m//g'") && echo "$test1_output" | grep -q "\[DEBUG\] Found hypefile at: $test_hypefile"; then
        test_passed "Hypefile discovery: current directory"
    else
        echo "[DEBUG] Test 1 failed. Full output:" >&2
        echo "$test1_output" >&2
        test_failed "Hypefile discovery: current directory" "Expected: [DEBUG] Found hypefile at: $test_hypefile, Actual output: $test1_output"
    fi
    
    # Test 2: Find hypefile from subdirectory
    local test_subdir="$test_root/subdir/nested"
    mkdir -p "$test_subdir"
    echo "[DEBUG] Test 2: Starting hypefile discovery test from subdirectory: $test_subdir" >&2
    
    local test2_output
    if test2_output=$(timeout 10s bash -c "cd '$test_subdir' && env DEBUG=true HYPE_LOG=stdout '$HYPE_BINARY' test-hype init 2>&1 | sed 's/\x1b\[[0-9;]*m//g'") && echo "$test2_output" | grep -q "\[DEBUG\] Found hypefile at: $test_hypefile"; then
        test_passed "Hypefile discovery: parent directory search"
    else
        echo "[DEBUG] Test 2 failed. Full output:" >&2
        echo "$test2_output" >&2
        test_failed "Hypefile discovery: parent directory search" "Expected: [DEBUG] Found hypefile at: $test_hypefile, Actual output: $test2_output"
    fi
    
    # Test 3: Error when no hypefile found
    local test_empty_root
    test_empty_root=$(mktemp -d)
    echo "[DEBUG] Test 3: Testing error when no hypefile found in: $test_empty_root" >&2
    
    local error_output
    error_output=$(timeout 5s bash -c "cd '$test_empty_root' && '$HYPE_BINARY' test-hype init 2>&1") || true
    if echo "$error_output" | grep -q "Error: hypefile.yaml not found in current or parent directories"; then
        test_passed "Hypefile discovery: error when not found"
    else
        echo "[DEBUG] Test 3 failed. Full output:" >&2
        echo "$error_output" >&2
        test_failed "Hypefile discovery: error when not found" "Expected: Error: hypefile.yaml not found..., Actual output: $error_output"
    fi
    
    # Test 4: HYPE_DIR set correctly when hypefile found
    echo "[DEBUG] Test 4: Testing HYPE_DIR setting from subdirectory: $test_subdir" >&2
    
    local test4_output
    if test4_output=$(timeout 10s bash -c "cd '$test_subdir' && env DEBUG=true HYPE_LOG=stdout '$HYPE_BINARY' test-hype init 2>&1 | sed 's/\x1b\[[0-9;]*m//g'") && echo "$test4_output" | grep -q "\[DEBUG\] Set HYPE_DIR to hypefile directory: $test_root"; then
        test_passed "HYPE_DIR: set to hypefile directory"
    else
        echo "[DEBUG] Test 4 failed. Full output:" >&2
        echo "$test4_output" >&2
        test_failed "HYPE_DIR: set to hypefile directory" "Expected: [DEBUG] Set HYPE_DIR to hypefile directory: $test_root, Actual output: $test4_output"
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
    test_builtin_structure
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