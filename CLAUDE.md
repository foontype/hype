# HYPE CLI Development Guide

This document provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HYPE is a simple command-line tool written in Bash that demonstrates basic CLI patterns. It's inspired by the navarch project structure and follows similar development practices.

## Language Guidelines
- **Chat responses**: 日本語で応答してください (Respond in Japanese)
- **Code comments and commit messages**: Must be written in English

## Essential Commands

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

### Development Installation
```bash
# Test the install script locally
./install.sh

# Make script executable and create symlink for development
chmod +x src/hype
ln -s $(pwd)/src/hype ~/.local/bin/hype
```

### Code Quality
```bash
# Lint bash scripts
shellcheck src/hype

# Format bash scripts (if shfmt is available)
shfmt -w -ci src/hype
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

## Git Workflow

### Language Convention
**All commit messages and code comments must be written in English.**

### Creating Pull Requests
**IMPORTANT: Never push directly to main branch. Always use feature branches.**

1. Check existing PRs:
   ```
   mcp__github__list_pull_requests
   ```

2. Create new branch (naming: `feature/<description>`):
   ```bash
   git checkout -b feature/<feature-name>
   ```

3. Format code before push:
   ```bash
   shellcheck src/hype
   # Fix any shellcheck issues before committing
   ```

4. Push branch:
   ```bash
   git push -u origin feature/<feature-name>
   ```

5. Create PR using GitHub MCP:
   ```
   mcp__github__create_pull_request
   ```

### Creating Issues
Use GitHub MCP tools to create issues:
```
mcp__github__create_issue
```

Include:
- Clear description of the problem or feature request
- Steps to reproduce (for bugs)
- Expected vs actual behavior
- Environment details if relevant

### Creating Releases
1. Update version in `src/hype` script
2. Create and push tag:
   ```bash
   git tag v0.2.0
   git push origin v0.2.0
   ```
3. GitHub Actions automatically creates release via `.github/workflows/release.yml`

## Adding New Features

When adding new subcommands:
1. Add the function (e.g., `cmd_newfeature()`)
2. Add the case statement in main()
3. Update help text
4. Add tests
5. Update README.md
6. Create PR using the workflow above

## Important Implementation Notes
- POSIX compatible, requires Bash 4.0+
- No build process - direct script execution
- Version defined in script: `HYPE_VERSION="0.1.0"`
- Error handling uses consistent exit codes
- Follow navarch patterns for argument parsing