#!/bin/bash

# Post-create command for HYPE development container

set -euo pipefail

echo "Setting up HYPE development environment..."

# Install additional tools if needed
# (Currently no additional tools required)

# Make sure hype script is executable
chmod +x src/hype

# Add src directory to PATH for current session
echo 'export PATH="/workspaces/hype/src:$PATH"' >> ~/.bashrc
echo 'export PATH="/workspaces/hype/src:$PATH"' >> ~/.zshrc

# Test installation
echo "Testing hype installation..."
./src/hype --version

echo "HYPE development environment setup complete!"
echo "You can now run 'hype' from anywhere in the container."