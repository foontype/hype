# HYPE CLI Development Guide

This document contains information for Claude Code to help with development of the HYPE CLI tool.

## Project Overview

HYPE is a simple command-line tool written in Bash that demonstrates basic CLI patterns. It's inspired by the navarch project structure and follows similar development practices.

## Development Commands

### Testing
```bash
# Run the main script
./src/hype

# Test all functionality
./src/hype hello
./src/hype world
./src/hype --version
./src/hype --help

# Run linting
shellcheck src/hype
shellcheck install.sh
shellcheck .devcontainer/post-create-command.sh
```

### Local Installation Testing
```bash
# Test the install script locally
./install.sh
```

## Project Structure

- `src/hype` - Main CLI script (Bash)
- `install.sh` - Installation script following navarch pattern
- `.devcontainer/` - Development container setup with Ubuntu + claude-code
- `.github/workflows/` - CI/CD pipelines for testing and release
- `tests/` - Test scripts (future)

## Code Style

- Follow shellcheck recommendations
- Use proper error handling with `set -euo pipefail`
- Include debug logging capabilities
- Follow the argument parsing pattern from navarch

## Dependencies

- Bash 4.0+
- Git (for development)
- curl or wget (for installation)

## Adding New Features

When adding new subcommands:
1. Add the function (e.g., `cmd_newfeature()`)
2. Add the case statement in main()
3. Update help text
4. Add tests
5. Update README.md