#!/bin/bash

# HYPE CLI Repository Module Unit Tests

set -euo pipefail

# Test configuration
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$TEST_DIR")")"
SRC_DIR="$PROJECT_ROOT/src"

# Source the repository module for testing
# shellcheck source=../../src/core/common.sh
source "$SRC_DIR/core/common.sh"
# shellcheck source=../../src/core/config.sh
source "$SRC_DIR/core/config.sh"
# shellcheck source=../../src/core/repository.sh
source "$SRC_DIR/core/repository.sh"

# Mock kubectl for testing
kubectl() {
    case "$1" in
        "config")
            echo "test-namespace"
            ;;
        "get")
            if [[ "$2" == "configmap" && "$3" == "hype-repository-config" ]]; then
                if [[ "${5:-}" == "-o" && "${6:-}" == "json" ]]; then
                    echo '{"data":{"test-hype":"{\"repository\":\"https://github.com/test/repo.git\",\"branch\":\"main\",\"path\":\"\"}"}}'
                elif [[ "${5:-}" == "-o" && "${6:-}" == "jsonpath={.data['test-hype']}" ]]; then
                    echo '{"repository":"https://github.com/test/repo.git","branch":"main","path":""}'
                fi
            fi
            ;;
        "create")
            echo "configmap/hype-repository-config created"
            ;;
        "patch")
            echo "configmap/hype-repository-config patched"
            ;;
        *)
            echo "mock kubectl command: $*" >&2
            ;;
    esac
}

# Mock git for testing
git() {
    case "$1" in
        "ls-remote")
            return 0
            ;;
        "clone")
            mkdir -p "$2"
            echo "Cloning into '$2'..."
            ;;
        "fetch"|"checkout"|"pull")
            echo "mock git $1"
            ;;
        *)
            echo "mock git command: $*" >&2
            ;;
    esac
}

# Mock jq for testing
jq() {
    local args=("$@")
    local json_input=""
    local field=""
    
    # Read from stdin if available
    if [ ! -t 0 ]; then
        json_input=$(cat)
    fi
    
    # Look for field extraction pattern
    for arg in "${args[@]}"; do
        if [[ "$arg" =~ \.([^[:space:]]+) ]]; then
            field="${BASH_REMATCH[1]}"
            break
        fi
    done
    
    # Return appropriate mock values based on field
    case "$field" in
        "repository")
            echo "https://github.com/test/repo.git"
            ;;
        "branch")
            echo "main"
            ;;
        "path")
            # Return empty string for path in most cases, or k8s for specific test
            if [[ "$json_input" == *"k8s"* ]]; then
                echo "k8s"
            else
                echo ""
            fi
            ;;
        *)
            # Default JSON creation
            if [[ "$*" == *"--arg repo"* && "$*" == *"--arg branch"* && "$*" == *"--arg path"* ]]; then
                echo "{\"repository\":\"$repository\",\"branch\":\"$branch\",\"path\":\"$path\"}"
            else
                echo "{\"repository\":\"https://github.com/test/repo.git\",\"branch\":\"main\",\"path\":\"\"}"
            fi
            ;;
    esac
}

# Mock rsync for testing
rsync() {
    echo "mock rsync: $*"
}

# Test repository name extraction
test_get_repo_name() {
    local result
    
    result=$(get_repo_name "https://github.com/user/test-repo.git")
    if [[ "$result" == "test-repo" ]]; then
        echo "✓ get_repo_name with .git suffix"
    else
        echo "✗ get_repo_name with .git suffix: expected 'test-repo', got '$result'"
        return 1
    fi
    
    result=$(get_repo_name "https://github.com/user/test-repo")
    if [[ "$result" == "test-repo" ]]; then
        echo "✓ get_repo_name without .git suffix"
    else
        echo "✗ get_repo_name without .git suffix: expected 'test-repo', got '$result'"
        return 1
    fi
    
    result=$(get_repo_name "git@github.com:user/test-repo.git")
    if [[ "$result" == "test-repo" ]]; then
        echo "✓ get_repo_name with SSH URL"
    else
        echo "✗ get_repo_name with SSH URL: expected 'test-repo', got '$result'"
        return 1
    fi
}

# Test binding JSON parsing
test_parse_binding() {
    # Override jq function for this specific test
    jq() {
        local field=""
        for arg in "$@"; do
            if [[ "$arg" =~ \.([^[:space:]]+) ]]; then
                field="${BASH_REMATCH[1]}"
                break
            fi
        done
        
        local input
        input=$(cat)
        
        if [[ "$input" == *"k8s"* ]]; then
            case "$field" in
                "repository") echo "https://github.com/test/repo.git" ;;
                "branch") echo "main" ;;
                "path") echo "k8s" ;;
                *) echo "" ;;
            esac
        else
            echo ""
        fi
    }
    
    local binding_json='{"repository":"https://github.com/test/repo.git","branch":"main","path":"k8s"}'
    local result
    
    result=$(parse_binding "$binding_json" "repository")
    if [[ "$result" == "https://github.com/test/repo.git" ]]; then
        echo "✓ parse_binding repository field"
    else
        echo "✗ parse_binding repository field: expected 'https://github.com/test/repo.git', got '$result'"
        return 1
    fi
    
    result=$(parse_binding "$binding_json" "branch")
    if [[ "$result" == "main" ]]; then
        echo "✓ parse_binding branch field"
    else
        echo "✗ parse_binding branch field: expected 'main', got '$result'"
        return 1
    fi
    
    result=$(parse_binding "$binding_json" "path")
    if [[ "$result" == "k8s" ]]; then
        echo "✓ parse_binding path field"
    else
        echo "✗ parse_binding path field: expected 'k8s', got '$result'"
        return 1
    fi
    
    result=$(parse_binding "" "repository")
    if [[ "$result" == "" ]]; then
        echo "✓ parse_binding empty input"
    else
        echo "✗ parse_binding empty input: expected '', got '$result'"
        return 1
    fi
}

# Test working directory resolution
test_get_working_directory() {
    local result
    
    # Mock current directory
    pwd() {
        echo "/current/dir"
    }
    
    # Mock get_repo_binding to return empty (no binding)
    get_repo_binding() {
        echo ""
    }
    
    result=$(get_working_directory "test-hype")
    if [[ "$result" == "/current/dir" ]]; then
        echo "✓ get_working_directory with no binding"
    else
        echo "✗ get_working_directory with no binding: expected '/current/dir', got '$result'"
        return 1
    fi
    
    # Mock get_repo_binding to return binding
    get_repo_binding() {
        echo '{"repository":"https://github.com/test/repo.git","branch":"main","path":""}'
    }
    
    # Override parse_binding for standard case
    parse_binding() {
        local binding_json="$1"
        local field="$2"
        
        if [[ -z "$binding_json" ]]; then
            echo ""
            return
        fi
        
        case "$field" in
            "repository") echo "https://github.com/test/repo.git" ;;
            "branch") echo "main" ;;
            "path") echo "" ;;
            *) echo "" ;;
        esac
    }
    
    result=$(get_working_directory "test-hype")
    if [[ "$result" == "/tmp/hype-repos/test-hype/repo/main" ]]; then
        echo "✓ get_working_directory with repository binding"
    else
        echo "✗ get_working_directory with repository binding: expected '/tmp/hype-repos/test-hype/repo/main', got '$result'"
        return 1
    fi
    
    # Mock get_repo_binding to return binding with path
    get_repo_binding() {
        echo '{"repository":"https://github.com/test/repo.git","branch":"main","path":"k8s"}'
    }
    
    # Override parse_binding to handle path correctly
    parse_binding() {
        local binding_json="$1"
        local field="$2"
        
        if [[ -z "$binding_json" ]]; then
            echo ""
            return
        fi
        
        case "$field" in
            "repository") echo "https://github.com/test/repo.git" ;;
            "branch") echo "main" ;;
            "path") 
                if [[ "$binding_json" == *"k8s"* ]]; then
                    echo "k8s"
                else
                    echo ""
                fi
                ;;
            *) echo "" ;;
        esac
    }
    
    result=$(get_working_directory "test-hype")
    if [[ "$result" == "/tmp/hype-repos/test-hype/repo/main/k8s" ]]; then
        echo "✓ get_working_directory with repository and path binding"
    else
        echo "✗ get_working_directory with repository and path binding: expected '/tmp/hype-repos/test-hype/repo/main/k8s', got '$result'"
        return 1
    fi
}

# Test repository validation
test_validate_repository() {
    if validate_repository "."; then
        echo "✓ validate_repository current directory"
    else
        echo "✗ validate_repository current directory"
        return 1
    fi
    
    if validate_repository "https://github.com/test/repo.git"; then
        echo "✓ validate_repository remote URL"
    else
        echo "✗ validate_repository remote URL"
        return 1
    fi
}

# Main test runner
main() {
    echo "Running Repository Module Unit Tests"
    echo "===================================="
    
    local tests_passed=0
    local tests_failed=0
    
    # Run tests
    for test_func in test_get_repo_name test_parse_binding test_get_working_directory test_validate_repository; do
        echo
        echo "Running $test_func..."
        if $test_func; then
            tests_passed=$((tests_passed + 1))
        else
            tests_failed=$((tests_failed + 1))
        fi
    done
    
    # Show results
    echo
    echo "Test Results:"
    echo "============="
    echo "Passed: $tests_passed"
    echo "Failed: $tests_failed"
    
    if [[ $tests_failed -eq 0 ]]; then
        echo "All repository module tests passed!"
        return 0
    else
        echo "Some repository module tests failed!"
        return 1
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi