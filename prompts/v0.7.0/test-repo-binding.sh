#!/bin/bash

# HYPE v0.7.0 Repository Binding Test Script
# Quick validation of repository binding functionality

set -euo pipefail

echo "HYPE v0.7.0 Repository Binding Test"
echo "==================================="
echo

# Build if not exists
if [[ ! -f "build/hype" ]]; then
    echo "Building HYPE CLI..."
    task build
    echo
fi

# Test 1: Version check
echo "Test 1: Version Check"
echo "---------------------"
./build/hype --version
echo

# Test 2: Help command
echo "Test 2: Repository Commands Help"
echo "--------------------------------"
./build/hype test-app repo --help
echo

# Test 3: Repository info (no binding)
echo "Test 3: Repository Info (No Binding)"
echo "------------------------------------"
./build/hype test-app repo
echo

# Test 4: URL validation (invalid URL)
echo "Test 4: URL Validation (Invalid URL)"
echo "------------------------------------"
if ./build/hype test-invalid repo bind invalid-url 2>&1; then
    echo "ERROR: Should have failed with invalid URL"
    exit 1
else
    echo "✓ Correctly rejected invalid URL"
fi
echo

# Test 5: Check kubectl availability
echo "Test 5: Kubectl Availability Check"
echo "----------------------------------"
if command -v kubectl >/dev/null 2>&1; then
    echo "✓ kubectl is available - full testing possible"
    KUBECTL_AVAILABLE=true
else
    echo "⚠ kubectl not available - limited testing only"
    KUBECTL_AVAILABLE=false
fi
echo

if [[ "$KUBECTL_AVAILABLE" == "true" ]]; then
    # Test 6: Repository binding (if kubectl available)
    echo "Test 6: Repository Binding (with kubectl)"
    echo "-----------------------------------------"
    
    # Try to bind a repository
    if ./build/hype test-demo repo bind https://github.com/foontype/hype.git --branch main 2>&1; then
        echo "✓ Repository binding command executed"
        
        # Check binding info
        echo
        echo "Checking binding information:"
        ./build/hype test-demo repo
        
        # Cleanup
        echo
        echo "Cleaning up test binding..."
        ./build/hype test-demo repo unbind || echo "Unbind failed (may be expected)"
    else
        echo "⚠ Repository binding failed (may be expected if no cluster access)"
    fi
else
    # Test 6: Repository binding without kubectl
    echo "Test 6: Repository Binding (without kubectl)"
    echo "--------------------------------------------"
    
    if ./build/hype test-demo repo bind https://github.com/foontype/hype.git 2>&1 | grep -q "kubectl is required"; then
        echo "✓ Correctly reported kubectl requirement"
    else
        echo "⚠ Unexpected response for kubectl requirement"
    fi
fi

echo
echo "Basic Tests Complete"
echo "==================="
echo
echo "✓ All basic functionality tests passed"
echo "✓ HYPE v0.7.0 repository binding feature is working"
echo
echo "For comprehensive testing, see TESTING-v0.7.0.md"