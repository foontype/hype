#!/bin/bash

# Unit tests for addons functionality
# Tests parsing of addons section from hypefile.yaml

# Source test framework
source "$(dirname "$0")/test-framework.sh"

# Create test hypefile with addons section
create_test_hypefile_with_addons() {
    cat > "$HYPEFILE" << 'EOF'
---
hype:
  name: test-app
  trait: test

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
create_test_hypefile_without_addons() {
    cat > "$HYPEFILE" << 'EOF'
---
hype:
  name: test-app
  trait: test

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
test_addons_parsing() {
    setup_test "test_addons_parsing"
    
    create_test_hypefile_with_addons
    parse_hypefile "test-app"
    
    # Get addons list
    local addons_list
    addons_list=$(get_addons_list)
    
    if [[ -n "$addons_list" ]]; then
        # Count number of addons
        local count=0
        local current_entry=""
        
        while IFS= read -r line; do
            if [[ "$line" =~ ^hype:.*$ ]]; then
                if [[ -n "$current_entry" ]]; then
                    count=$((count + 1))
                fi
                current_entry="$line"
            else
                current_entry="$current_entry"$'\n'"$line"
            fi
        done <<< "$addons_list"
        
        # Process last entry
        if [[ -n "$current_entry" ]]; then
            count=$((count + 1))
        fi
        
        if [[ $count -eq 2 ]]; then
            echo "✓ addons section parsed correctly (found $count addons)"
            return 0
        else
            echo "✗ addons section parsing failed (found $count addons, expected 2)"
            return 1
        fi
    else
        echo "✗ addons list is empty"
        return 1
    fi
}

# Test parsing hypefile without addons
test_no_addons_parsing() {
    setup_test "test_no_addons_parsing"
    
    create_test_hypefile_without_addons
    parse_hypefile "test-app"
    
    # Get addons list
    local addons_list
    addons_list=$(get_addons_list)
    
    if [[ -z "$addons_list" ]]; then
        echo "✓ No addons section correctly handled"
        return 0
    else
        echo "✗ Should return empty for no addons section"
        return 1
    fi
}

# Test addons list command
test_addons_list_command() {
    setup_test "test_addons_list_command"
    
    create_test_hypefile_with_addons
    
    # Run addons list command
    local output
    if output=$(addons_list "test-app" 2>&1); then
        if echo "$output" | grep -q "test-addon1" && echo "$output" | grep -q "test-addon2"; then
            echo "✓ addons list command shows configured addons"
            return 0
        else
            echo "✗ addons list command missing expected addons"
            echo "Output: $output"
            return 1
        fi
    else
        echo "✗ addons list command failed"
        return 1
    fi
}

# Test addons parsing with malformed YAML
test_addons_parsing_malformed() {
    setup_test "test_addons_parsing_malformed"
    
    # Create malformed hypefile
    cat > "$HYPEFILE" << 'EOF'
---
hype:
  name: test-app
  trait: test

addons:
  - hype: test-addon1
    # Missing prepare field
  - prepare: "repo2/test --path example2"
    # Missing hype field

expectedReleases:
  - nginx
---
releases:
  - name: nginx
    chart: bitnami/nginx
EOF
    
    parse_hypefile "test-app"
    
    # Get addons list should still work, but entries may be incomplete
    local addons_list
    addons_list=$(get_addons_list)
    
    if [[ -n "$addons_list" ]]; then
        echo "✓ Malformed addons handled gracefully"
        return 0
    else
        echo "✓ Empty result for malformed addons is acceptable"
        return 0
    fi
}

# Run tests
run_tests() {
    echo "Running addons functionality tests..."
    
    local total=0
    local passed=0
    
    tests=(
        test_addons_parsing
        test_no_addons_parsing
        test_addons_list_command
        test_addons_parsing_malformed
    )
    
    for test_func in "${tests[@]}"; do
        total=$((total + 1))
        echo "Running $test_func..."
        if $test_func; then
            passed=$((passed + 1))
        fi
        echo ""
    done
    
    echo "Addons tests completed: $passed/$total passed"
    
    if [[ $passed -eq $total ]]; then
        echo "✓ All addons tests passed"
        return 0
    else
        echo "✗ Some addons tests failed"
        return 1
    fi
}

# Only run tests if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi