#!/bin/bash
set -euo pipefail

TARGET="$1"

# Combine core files
for file in src/core/*.sh; do
    echo "# Source: $file" >> "$TARGET"
    tail -n +2 "$file" >> "$TARGET"
    echo "" >> "$TARGET"
done

# Combine plugin files
for file in src/plugins/*.sh; do
    echo "# Source: $file" >> "$TARGET"
    tail -n +2 "$file" >> "$TARGET"
    echo "" >> "$TARGET"
done

# Add main.sh
echo "# Source: src/main.sh" >> "$TARGET"
tail -n +2 src/main.sh >> "$TARGET"