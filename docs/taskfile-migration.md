# Taskfile Migration Guide

This document describes the migration from Makefile to Taskfile for the HYPE CLI build system.

## Overview

We've migrated from GNU Make to [Taskfile](https://taskfile.dev/) for better cross-platform compatibility and improved developer experience.

## Available Tasks

| Task | Description |
|------|-------------|
| `task build` | Build the final executable (default) |
| `task clean` | Remove build artifacts |
| `task lint` | Run ShellCheck on all scripts |
| `task test` | Run test suite |
| `task install` | Install to `~/.local/bin` |
| `task dev-run` | Run built executable in development mode |
| `task version-check` | Check version of built binary |
| `task help-check` | Show help from built binary |
| `task validate` | Run comprehensive validation |

## Usage Examples

```bash
# Basic build
task build

# Run with arguments
task dev-run CLI_ARGS="--version"

# Full validation
task validate
```

## Migration Benefits

1. **Cross-platform compatibility** - Works on Windows, Mac, Linux
2. **Better YAML syntax** - More readable than Makefile
3. **Improved dependency management** - Clearer task dependencies
4. **Built-in file watching** - Future feature for development
5. **Variables and templating** - More flexible configuration

## Backward Compatibility

The existing `make` commands still work if Taskfile is not available, ensuring smooth transition.

## Installation

Taskfile is already available in the development environment. For local development:

```bash
# macOS
brew install go-task/tap/go-task

# Linux
sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d
```