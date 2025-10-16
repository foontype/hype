#!/bin/bash
set -euo pipefail

TARGET="$1"

# Combine core files
for file in src/core/*.sh; do
    tail -n +2 "$file" >> "$TARGET"
    echo "" >> "$TARGET"
done

# Combine builtin files
for file in src/builtins/*.sh; do
    tail -n +2 "$file" >> "$TARGET"
    echo "" >> "$TARGET"
done

# Add main.sh
tail -n +2 src/main.sh >> "$TARGET"