#!/bin/bash

# Unit tests for addons module

# Source required modules
source "$(dirname "${BASH_SOURCE[0]}")/../../src/core/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../src/core/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../src/core/hypefile.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../../src/builtins/addons.sh"

# Create test hypefile with addons section
create_test_hypefile() {
    local test_file="$1"
    cat > "$test_file" << 'EOF'
defaultResources:
  - name: "test-resource"
    type: StateValuesConfigmap

addons:
  - hype: test-addon1
    prepare: "repo1/test --path example1"
  - hype: test-addon2
    prepare: "repo2/test --path example2"

expectedReleases:
  - nginx
---
releases:
  - name: nginx
    chart: bitnami/nginx
EOF
}

# Create test hypefile without addons
create_test_hypefile_no_addons() {
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

# Test parsing addons section
test_parse_addons_section() {
    local test_hypefile=$(mktemp)
    create_test_hypefile "$test_hypefile"
    
    # Set HYPEFILE for parsing
    HYPEFILE="$test_hypefile"
    
    # Parse the hypefile
    parse_hypefile "test-app"
    
    # Get addons list
    local addons_list
    addons_list=$(get_addons_list)
    
    # Check if we got the addons
    local count
    count=$(echo "$addons_list" | grep -c "hype:" || true)
    
    rm -f "$test_hypefile"
    
    if [[ $count -eq 2 ]]; then
        echo "✓ addons section parsed correctly (found $count addons)"
        return 0
    else
        echo "✗ addons section parsing failed (found $count addons, expected 2)"
        return 1
    fi
}

# Test parsing when no addons exist
test_parse_no_addons() {
    local test_hypefile=$(mktemp)
    create_test_hypefile_no_addons "$test_hypefile"
    
    # Set HYPEFILE for parsing
    HYPEFILE="$test_hypefile"
    
    # Parse the hypefile
    parse_hypefile "test-app"
    
    # Get addons list
    local addons_list
    addons_list=$(get_addons_list)
    
    rm -f "$test_hypefile"
    
    if [[ -z "$addons_list" ]]; then
        echo "✓ No addons found when none configured"
        return 0
    else
        echo "✗ Found addons when none should exist"
        return 1
    fi
}

# Test addon field extraction
test_addons_field_extraction() {
    local test_hypefile=$(mktemp)
    create_test_hypefile "$test_hypefile"
    
    # Set HYPEFILE for parsing
    HYPEFILE="$test_hypefile"
    
    # Parse the hypefile
    parse_hypefile "test-app"
    
    # Get addons list and extract first addon
    local addons_list
    addons_list=$(get_addons_list)
    
    # Build first complete entry by processing line by line
    local first_addon=""
    local line_count=0
    while IFS= read -r line && [[ $line_count -lt 2 ]]; do
        if [[ -n "$line" ]]; then
            if [[ -z "$first_addon" ]]; then
                first_addon="$line"
            else
                first_addon="$first_addon"$'\n'"$line"
            fi
            ((line_count++))
        fi
    done <<< "$addons_list"
    
    # Extract hype and prepare fields
    local addon_hype
    local addon_prepare
    addon_hype=$(echo "$first_addon" | yq eval '.hype' -)
    addon_prepare=$(echo "$first_addon" | yq eval '.prepare' -)
    
    rm -f "$test_hypefile"
    
    if [[ "$addon_hype" == "test-addon1" && "$addon_prepare" == "repo1/test --path example1" ]]; then
        echo "✓ Addon fields extracted correctly"
        return 0
    else
        echo "✗ Addon field extraction failed: hype='$addon_hype', prepare='$addon_prepare'"
        return 1
    fi
}

# Test help function exists
test_help_function() {
    if declare -f help_addons > /dev/null; then
        echo "✓ help_addons function exists"
        return 0
    else
        echo "✗ help_addons function missing"
        return 1
    fi
}

# Test brief help function exists
test_brief_help_function() {
    if declare -f help_addons_brief > /dev/null; then
        echo "✓ help_addons_brief function exists"
        return 0
    else
        echo "✗ help_addons_brief function missing"
        return 1
    fi
}

# Test command function exists
test_command_function() {
    if declare -f cmd_addons > /dev/null; then
        echo "✓ cmd_addons function exists"
        return 0
    else
        echo "✗ cmd_addons function missing"
        return 1
    fi
}

# Run tests
echo "Addons Module Unit Tests"
echo "========================"

test_parse_addons_section
test_parse_no_addons
test_addons_field_extraction
test_help_function
test_brief_help_function
test_command_function

echo "Addons tests completed"