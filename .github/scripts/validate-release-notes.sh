#!/bin/bash

# validate-release-notes.sh
# Script to validate that release notes exist for a given version

set -euo pipefail

# Function to display usage
usage() {
    echo "Usage: $0 <version>"
    echo "Example: $0 v1.0.0"
    exit 1
}

# Check arguments
if [ $# -ne 1 ]; then
    echo "Error: Version argument required"
    usage
fi

VERSION="$1"
RELEASE_NOTES_FILE="release-notes.yaml"

# Check if release notes file exists
if [ ! -f "$RELEASE_NOTES_FILE" ]; then
    echo "Error: Release notes file '$RELEASE_NOTES_FILE' not found"
    exit 1
fi

# Check if yq is available
if ! command -v yq &> /dev/null; then
    echo "Error: yq command not found. Please install yq first."
    echo "Install with: sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq"
    exit 1
fi

echo "Validating release notes for version: $VERSION"

# Check if version exists in release notes
if yq eval ".\"$VERSION\"" "$RELEASE_NOTES_FILE" | grep -q "null"; then
    echo "Error: No release notes found for version '$VERSION' in $RELEASE_NOTES_FILE"
    echo ""
    echo "Available versions in release notes:"
    yq eval 'keys' "$RELEASE_NOTES_FILE" | sed 's/^/  /'
    echo ""
    echo "Please add release notes for version '$VERSION' to $RELEASE_NOTES_FILE"
    echo "Example format:"
    echo "\"$VERSION\": |"
    echo "  ## What's New in $VERSION"
    echo "  - Feature 1"
    echo "  - Bug fix 2"
    exit 1
fi

# Check if release notes are not empty
NOTES_CONTENT=$(yq eval ".\"$VERSION\"" "$RELEASE_NOTES_FILE")
if [ -z "$NOTES_CONTENT" ] || [ "$NOTES_CONTENT" = "null" ] || [ "$NOTES_CONTENT" = "" ]; then
    echo "Error: Release notes for version '$VERSION' are empty"
    exit 1
fi

echo "✅ Release notes validation passed for version: $VERSION"
echo "Release notes preview:"
echo "----------------------------------------"
echo "$NOTES_CONTENT"
echo "----------------------------------------"