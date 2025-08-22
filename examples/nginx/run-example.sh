#!/bin/bash

# HYPE CLI nginx example
# This script demonstrates how to use the HYPE CLI to deploy nginx with ConfigMap management

set -euo pipefail

echo "=== HYPE CLI nginx Example ==="
echo ""

# Check dependencies
echo "Checking dependencies..."
if ! command -v ../../src/hype &> /dev/null; then
    echo "Error: hype command not found. Please ensure ../../src/hype exists and is executable."
    exit 1
fi

if ! command -v helmfile &> /dev/null; then
    echo "Error: helmfile not found. Please install helmfile."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl not found. Please install kubectl."
    exit 1
fi

echo "All dependencies found!"
echo ""

# Display the helmfile configuration
echo "=== Helmfile Configuration ==="
cat helmfile.yaml
echo ""

# Example 1: Generate template to see what HYPE would process
echo "=== Example 1: Template Generation ==="
echo "Running: hype helmfile -f helmfile.yaml -e hype-example template"
echo ""
DEBUG=1 ../../src/hype helmfile -f helmfile.yaml -e hype-example template
echo ""

# Example 2: Show what would happen with diff (dry-run)
echo "=== Example 2: Diff Mode (what would be deployed) ==="
echo "Running: hype helmfile -f helmfile.yaml -e hype-example diff"
echo ""
# Note: This will create ConfigMaps but show what would be deployed
DEBUG=1 ../../src/hype helmfile -f helmfile.yaml -e hype-example diff
echo ""

# Example 3: Actual deployment (commented out for safety)
echo "=== Example 3: Deployment (commented out) ==="
echo "To actually deploy nginx, run:"
echo "  hype helmfile -f helmfile.yaml -e hype-example apply"
echo ""
echo "This would:"
echo "1. Create 'hype-example-nginx-config' ConfigMap with nginx configuration"
echo "2. Create 'hype-example-nginx-secrets' ConfigMap with default auth values"
echo "3. Generate temporary value files from ConfigMaps"
echo "4. Execute 'helmfile apply' with the generated value files"
echo ""

echo "=== ConfigMaps that would be created ==="
echo "1. hype-example-nginx-config:"
echo "   - Contains nginx replica count, image tag, service config"
echo "   - Type: state-value-file"
echo ""
echo "2. hype-example-nginx-secrets:"  
echo "   - Contains default auth credentials"
echo "   - Type: secrets-default"
echo ""

echo "Example completed!"