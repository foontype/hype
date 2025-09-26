#!/bin/bash

# Unit tests for depends module

# Source required modules
source "$(dirname "${BASH_SOURCE[0]}")/../../src/core/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../src/core/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../src/core/hypefile.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../src/builtins/depends.sh"

# Create test hypefile with depends section
create_test_hypefile() {
    local test_file="$1"
    cat > "$test_file" << 'EOF'
defaultResources:
  - name: "test-resource"
    type: StateValuesConfigmap

depends:
  - hype: test-dep1
    prepare: "repo1/test --path example1"
  - hype: test-dep2
    prepare: "repo2/test --path example2"

expectedReleases:
  - nginx
---
releases:
  - name: nginx
    chart: bitnami/nginx
EOF
}

# Create test hypefile without dependencies
create_test_hypefile_no_deps() {
    local test_file="$1"
    cat > "$test_file" << 'EOF'
defaultResources:
  - name: "test-resource"
    type: StateValuesConfigmap

expectedReleases:
  - nginx
---
releases:
  - name: nginx
    chart: bitnami/nginx
EOF
}

# Test parsing depends section
test_parse_depends_section() {
    local test_hypefile=$(mktemp)
    create_test_hypefile "$test_hypefile"
    
    # Set HYPEFILE for parsing
    HYPEFILE="$test_hypefile"
    
    # Parse the hypefile
    parse_hypefile "test-app"
    
    # Get depends list
    local depends_list
    depends_list=$(get_depends_list)
    
    # Check if we got the dependencies
    local count
    count=$(echo "$depends_list" | grep -c "hype:" || true)
    
    rm -f "$test_hypefile"
    
    if [[ $count -eq 2 ]]; then
        echo "✓ depends section parsed correctly (found $count dependencies)"
        return 0
    else
        echo "✗ depends section parsing failed (found $count dependencies, expected 2)"
        return 1
    fi
}

# Test parsing when no dependencies exist
test_parse_no_depends() {
    local test_hypefile=$(mktemp)
    create_test_hypefile_no_deps "$test_hypefile"
    
    # Set HYPEFILE for parsing
    HYPEFILE="$test_hypefile"
    
    # Parse the hypefile
    parse_hypefile "test-app"
    
    # Get depends list
    local depends_list
    depends_list=$(get_depends_list)
    
    rm -f "$test_hypefile"
    
    if [[ -z "$depends_list" ]]; then
        echo "✓ No dependencies found when none configured"
        return 0
    else
        echo "✗ Found dependencies when none should exist"
        return 1
    fi
}

# Test dependency field extraction
test_depends_field_extraction() {
    local test_hypefile=$(mktemp)
    create_test_hypefile "$test_hypefile"
    
    # Set HYPEFILE for parsing
    HYPEFILE="$test_hypefile"
    
    # Parse the hypefile
    parse_hypefile "test-app"
    
    # Get depends list and extract first dependency
    local depends_list
    depends_list=$(get_depends_list)
    
    # Build first complete entry by processing line by line
    local first_dep=""
    local line_count=0
    local line
    while IFS= read -r line && [[ $line_count -lt 2 ]]; do
        if [[ -n "$line" ]]; then
            if [[ -z "$first_dep" ]]; then
                first_dep="$line"
            else
                first_dep="$first_dep"$'\n'"$line"
            fi
            ((line_count++))
        fi
    done <<< "$depends_list"
    
    # Extract hype and prepare fields
    local dep_hype
    local dep_prepare
    dep_hype=$(echo "$first_dep" | yq eval '.hype' -)
    dep_prepare=$(echo "$first_dep" | yq eval '.prepare' -)
    
    rm -f "$test_hypefile"
    
    if [[ "$dep_hype" == "test-dep1" && "$dep_prepare" == "repo1/test --path example1" ]]; then
        echo "✓ Dependency fields extracted correctly"
        return 0
    else
        echo "✗ Dependency field extraction failed: hype='$dep_hype', prepare='$dep_prepare'"
        return 1
    fi
}

# Test help function exists
test_help_function() {
    if declare -f help_depends > /dev/null; then
        echo "✓ help_depends function exists"
        return 0
    else
        echo "✗ help_depends function missing"
        return 1
    fi
}

# Test brief help function exists
test_brief_help_function() {
    if declare -f help_depends_brief > /dev/null; then
        echo "✓ help_depends_brief function exists"
        return 0
    else
        echo "✗ help_depends_brief function missing"
        return 1
    fi
}

# Test command function exists
test_command_function() {
    if declare -f cmd_depends > /dev/null; then
        echo "✓ cmd_depends function exists"
        return 0
    else
        echo "✗ cmd_depends function missing"
        return 1
    fi
}

# Run tests
echo "Depends Module Unit Tests"
echo "========================="

test_parse_depends_section
test_parse_no_depends
test_depends_field_extraction
test_help_function
test_brief_help_function
test_command_function

echo "Depends tests completed"