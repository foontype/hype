# HYPE CLI Development Guide

This document provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Imports

* @prompts/agent-tomes/github/workflow.md
* @prompts/agent-tomes/github/release-system.md
* @prompts/agent-tomes/github/pull-request-branch-switching.md
* @prompts/agent-tomes/github/copy-agent-tomes.md

## Project Overview

HYPE is a modular command-line tool written in Bash for Kubernetes AI deployments. It uses a modular architecture with separate core modules and builtins for different commands. The tool follows a build system approach where individual components are combined into a single executable.

## Language Guidelines
- **Chat responses**: 日本語で応答してください (Respond in Japanese)
- **Code comments and commit messages**: Must be written in English

## Essential Commands

### Testing
```bash
# Build and test the CLI
task build
task test

# Test built binary functionality
./build/hype --version
./build/hype --help

# Run linting on all components
task lint

# Individual component testing
shellcheck src/core/*.sh
shellcheck src/builtins/*.sh
shellcheck src/main.sh
```

### Smoke Testing
```bash
# Run comprehensive smoke test following prompts/smoke-test.md
# Note: This test should be run from the prompts/nginx-example directory
# and requires kubectl and helmfile to be properly configured

# Follow the complete test sequence in prompts/smoke-test.md for smoke testing
# This covers trait management, parsing, initialization, templating,
# and deployment/destruction workflows
```

### Development Installation
```bash
# Build and install locally
task build
task install

# Or test the install script
./install.sh

# For development work, use built binary
./build/hype --version
```

### Code Quality
```bash
# Lint all components
task lint

# Format bash scripts (if shfmt is available)
shfmt -w -ci src/core/*.sh src/plugins/*.sh src/main.sh

# Clean build artifacts
task clean
```

## Project Structure

- `src/core/` - Core modules (config, common, hypefile, dependencies)
- `src/builtins/` - Builtin modules (init, template, parse, trait, upgrade, task, helmfile)
- `src/main.sh` - Main entry point and command routing
- `build/` - Build artifacts (generated executable)
- `tests/` - Test framework and unit tests
- `Taskfile.yml` - Build system configuration
- `install.sh` - Installation script
- `.github/workflows/` - CI/CD pipelines for testing and release

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

### Creating Releases

#### Version Update Process
1. **Update version in `src/core/config.sh` script**:
   - Locate `HYPE_VERSION="x.x.x"` line in `src/core/config.sh`
   - Update to new version number (e.g., `HYPE_VERSION="0.6.0"`)

2. **Create/Update release notes in `release-notes.yaml`**:
   - Add new version key (e.g., `v0.5.0:`)
   - Generate release notes from recent git log:
     ```bash
     git log --oneline --since="last release date" --format="- %s"
     ```
   - Add generated notes under the version key in YAML format

3. **Create pull request for version update**:
   - Create feature branch for version update (e.g., `feature/version-0.5.0`)
   - Commit version and release notes changes
   - Create PR using GitHub MCP:
     ```
     mcp__github__create_pull_request
     ```
   - Wait for user to review and merge the PR

4. **Create and push tag** (only after PR is merged):
   ```bash
   git tag v0.5.0
   git push origin v0.5.0
   ```

5. **GitHub Actions automatically creates release** via `.github/workflows/release.yml`

#### Example release-notes.yaml structure:
```yaml
v0.5.0:
  - Add new feature X
  - Fix bug in command Y  
  - Improve error handling
  - Update documentation
v0.4.0:
  - Previous release notes
```

## Adding New Features

### Adding New Builtins
1. Create new builtin file in `src/builtins/` (e.g., `src/builtins/newfeature.sh`)
2. Follow the builtin template structure in `src/builtins/builtin-template.sh`
3. Add builtin metadata and command functions
4. Update main command routing in `src/main.sh`
5. Add tests in `tests/unit/`
6. Run `task build` and `task test`
7. Update help text if needed
8. Create PR using the workflow above

### Adding Core Functionality
1. Add functions to appropriate core module in `src/core/`
2. Update other modules that depend on the new functionality
3. Add unit tests
4. Run `task build` and `task test`
5. Create PR using the workflow above

## Important Implementation Notes
- POSIX compatible, requires Bash 4.0+
- Modular architecture with builtins and build system
- Version defined in `src/core/config.sh`: `HYPE_VERSION="0.6.0"`
- Error handling uses consistent exit codes
- Modular design allows independent development of features
- Built executable is single self-contained file