#!/bin/bash

# Test matchTraits filtering functionality

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Import test framework
source "$SCRIPT_DIR/../framework/framework.sh"

# Mock functions for testing
mock_get_hype_trait() {
    local hype_name="$1"
    case "$hype_name" in
        "test-app")
            echo "production"
            return 0
            ;;
        "test-app-dev")
            echo "development"
            return 0
            ;;
        "test-app-staging")
            echo "staging"
            return 0
            ;;
        "test-app-no-trait")
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

# Override the actual function
get_hype_trait() {
    mock_get_hype_trait "$@"
}

# Test should_process_entry_by_traits function
test_should_process_entry_by_traits() {
    echo "Running test_should_process_entry_by_traits"

    # Test 1: Entry without matchTraits should always be processed
    local entry_no_match_traits='hype: my-depend
prepare: foontype/hype --path prompts/nginx-example'

    if should_process_entry_by_traits "$entry_no_match_traits" "test-app"; then
        echo "✓ Entry without matchTraits is processed correctly"
    else
        echo "✗ Entry without matchTraits should be processed"
        return 1
    fi

    # Test 2: Entry with matching trait should be processed
    local entry_matching_trait='hype: my-depend
prepare: foontype/hype --path prompts/nginx-example
matchTraits: [production, staging]'

    if should_process_entry_by_traits "$entry_matching_trait" "test-app"; then
        echo "✓ Entry with matching trait is processed correctly"
    else
        echo "✗ Entry with matching trait should be processed"
        return 1
    fi

    # Test 3: Entry with non-matching trait should not be processed
    local entry_non_matching_trait='hype: my-depend
prepare: foontype/hype --path prompts/nginx-example
matchTraits: [development, staging]'

    if ! should_process_entry_by_traits "$entry_non_matching_trait" "test-app"; then
        echo "✓ Entry with non-matching trait is skipped correctly"
    else
        echo "✗ Entry with non-matching trait should be skipped"
        return 1
    fi

    # Test 4: Entry with matchTraits but no current trait should not be processed
    local entry_with_match_traits='hype: my-depend
prepare: foontype/hype --path prompts/nginx-example
matchTraits: [production]'

    if ! should_process_entry_by_traits "$entry_with_match_traits" "test-app-no-trait"; then
        echo "✓ Entry with matchTraits but no current trait is skipped correctly"
    else
        echo "✗ Entry with matchTraits but no current trait should be skipped"
        return 1
    fi

    # Test 5: Entry with multiple matchTraits, one matching
    local entry_multiple_traits='hype: my-depend
prepare: foontype/hype --path prompts/nginx-example
matchTraits: [development, production, staging]'

    if should_process_entry_by_traits "$entry_multiple_traits" "test-app-dev"; then
        echo "✓ Entry with multiple matchTraits (one matching) is processed correctly"
    else
        echo "✗ Entry with multiple matchTraits (one matching) should be processed"
        return 1
    fi

    echo "All should_process_entry_by_traits tests passed"
}

# Test that trait filtering is applied in depends processing
test_depends_trait_filtering() {
    echo "Running test_depends_trait_filtering"

    # Create test hypefile
    local test_hypefile=$(mktemp)
    cat > "$test_hypefile" << 'EOF'
depends:
  - hype: my-depend1
    prepare: foontype/hype --path prompts/nginx-example
    matchTraits: [production]
  - hype: my-depend2
    prepare: foontype/hype --path prompts/nginx-example
    matchTraits: [development]
  - hype: my-depend3
    prepare: foontype/hype --path prompts/nginx-example
EOF

    # Mock parse_hypefile to use our test file
    HYPE_SECTION_FILE="$test_hypefile"

    # Test that get_depends_list returns all entries
    local depends_list
    depends_list=$(get_depends_list)
    local entry_count=$(echo "$depends_list" | grep -c "^hype:" || echo "0")

    if [[ "$entry_count" == "3" ]]; then
        echo "✓ get_depends_list returns all 3 entries"
    else
        echo "✗ get_depends_list should return 3 entries, got $entry_count"
        return 1
    fi

    # Clean up
    rm -f "$test_hypefile"

    echo "Depends trait filtering test passed"
}

# Test that trait filtering is applied in addons processing
test_addons_trait_filtering() {
    echo "Running test_addons_trait_filtering"

    # Create test hypefile
    local test_hypefile=$(mktemp)
    cat > "$test_hypefile" << 'EOF'
addons:
  - hype: my-addon1
    prepare: foontype/hype --path prompts/nginx-example
    matchTraits: [production]
  - hype: my-addon2
    prepare: foontype/hype --path prompts/nginx-example
    matchTraits: [development]
  - hype: my-addon3
    prepare: foontype/hype --path prompts/nginx-example
EOF

    # Mock parse_hypefile to use our test file
    HYPE_SECTION_FILE="$test_hypefile"

    # Test that get_addons_list returns all entries
    local addons_list
    addons_list=$(get_addons_list)
    local entry_count=$(echo "$addons_list" | grep -c "^hype:" || echo "0")

    if [[ "$entry_count" == "3" ]]; then
        echo "✓ get_addons_list returns all 3 entries"
    else
        echo "✗ get_addons_list should return 3 entries, got $entry_count"
        return 1
    fi

    # Clean up
    rm -f "$test_hypefile"

    echo "Addons trait filtering test passed"
}

# Main test execution
main() {
    echo "Starting matchTraits filtering tests"

    # Source the required modules
    source "$PROJECT_ROOT/src/core/hypefile.sh"

    # Run tests
    test_should_process_entry_by_traits
    test_depends_trait_filtering
    test_addons_trait_filtering

    echo "All matchTraits filtering tests completed successfully"
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi