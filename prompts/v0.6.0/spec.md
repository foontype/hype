# HYPE CLI v0.6.0 Plugin System Specification

## Overview

This specification defines the modular plugin-based architecture for HYPE CLI v0.6.0, designed to improve maintainability and development efficiency while preserving the single-script distribution model.

## Current State Analysis

### Existing Architecture Issues

The current `src/hype` is a monolithic 1,278-line bash script containing:
- Basic utility functions (logging, error handling)
- Individual `cmd_*` functions for each subcommand
- Main router function
- All functionality in a single file

### Problems to Solve

1. **Maintainability**: Large single file is difficult to navigate and modify
2. **Development Efficiency**: Changes to one command affect the entire file
3. **Testing**: Individual commands cannot be tested in isolation
4. **Code Reuse**: Common patterns are duplicated across commands
5. **Collaboration**: Multiple developers cannot work on different commands simultaneously

## Proposed Architecture

### Directory Structure

```
src/
├── core/
│   ├── common.sh          # Common utilities, logging, error handling
│   ├── config.sh          # Configuration and environment variables
│   ├── hypefile.sh        # hypefile.yaml parsing functionality
│   └── dependencies.sh    # Dependency checking
├── plugins/
│   ├── init.sh           # init/deinit/check commands
│   ├── template.sh       # template command
│   ├── parse.sh          # parse command
│   ├── trait.sh          # trait command
│   ├── task.sh           # task command
│   ├── helmfile.sh       # helmfile command
│   └── upgrade.sh        # upgrade command
├── main.sh               # Main entry point, plugin discovery and execution
└── hype                  # Current monolithic script (to be removed after refactor)
build/
└── hype                  # Build artifact (Git ignored)
tests/
├── unit/                 # Unit tests for individual plugins
├── integration/          # Integration tests
└── test-suite.sh         # Test runner
.gitignore               # Updated to include build/
```

## Core System Design

### Plugin Discovery and Execution System

```bash
# Plugin discovery mechanism
discover_plugins() {
    local cmd="$1"
    local plugin_file="$SCRIPT_DIR/plugins/${cmd}.sh"
    
    if [[ -f "$plugin_file" ]]; then
        echo "$plugin_file"
        return 0
    fi
    return 1
}

# Plugin execution framework
execute_plugin() {
    local plugin_file="$1"
    local cmd="$2"
    shift 2
    
    # Export core functions to plugin environment
    export -f debug info warn error die
    export -f parse_hypefile cleanup
    
    # Source and execute plugin
    source "$plugin_file"
    "cmd_${cmd}" "$@"
}
```

### Development vs Production Modes

**Development Mode** (`HYPE_DEV_MODE=true`):
- Dynamically sources individual plugin files
- Allows real-time plugin development and testing
- Enables individual plugin linting and testing

**Production Mode** (Default):
- Uses single compiled script from `build/hype`
- Optimized for performance and distribution
- Self-contained executable

## Plugin Interface Standard

### Plugin Structure Template

```bash
#!/bin/bash
# Plugin: <plugin-name>
# Description: <plugin-description>

# Plugin metadata (optional)
PLUGIN_NAME="<plugin-name>"
PLUGIN_DESCRIPTION="<plugin-description>"
PLUGIN_VERSION="1.0.0"

# Main command function (required)
# Must follow naming convention: cmd_<plugin-name>
cmd_<plugin-name>() {
    local hype_name="$1"
    shift
    local args=("$@")
    
    # Plugin implementation
    info "Executing <plugin-name> command for: $hype_name"
    
    # Access core functionality
    parse_hypefile "$hype_name"
    
    # Plugin-specific logic here
}

# Sub-command handler (optional)
cmd_<plugin-name>_<subcommand>() {
    local hype_name="$1" 
    local sub_cmd="$2"
    shift 2
    
    case "$sub_cmd" in
        "sub1")
            # Handle subcommand
            ;;
        *)
            error "Unknown subcommand: $sub_cmd"
            exit 1
            ;;
    esac
}

# Plugin-specific helper functions (private to plugin)
_<plugin-name>_helper_function() {
    # Private helper function
    return 0
}
```

### Core Module Interfaces

**common.sh**: Utility functions available to all plugins
- `debug()`, `info()`, `warn()`, `error()`, `die()`
- `silent()` function for output suppression
- Color constants and logging configuration

**config.sh**: Configuration management
- Version information (`HYPE_VERSION`)
- Environment variable handling
- Default configuration values

**hypefile.sh**: hypefile.yaml processing
- `parse_hypefile()` function
- Template variable substitution
- Section file management and cleanup

**dependencies.sh**: Dependency validation
- `check_dependencies()` function
- Tool availability verification
- Version compatibility checks

## Build System

### Taskfile Configuration

```yaml
version: '3'

vars:
  BUILD_DIR: build
  SRC_DIR: src
  TARGET: "{{.BUILD_DIR}}/hype"
  INSTALL_DIR: "{{.HOME}}/.local/bin"

tasks:
  build:    # Build the final executable
  lint:     # Run ShellCheck validation on all source files
  test:     # Run test suite with build dependency
  dev-run:  # Run in development mode
  clean:    # Remove build artifacts
  install:  # Install to ~/.local/bin with build dependency
  validate: # CI/CD pipeline target (build + lint + test)
```

### Build Process

1. **Preparation**: Create build directory and target file with header
2. **Core Integration**: Concatenate core modules (excluding shebang lines)
3. **Plugin Integration**: Append all plugin files (excluding shebang lines)
4. **Main Script**: Add main.sh entry point
5. **Finalization**: Set executable permissions and validate output

### Git Integration

**Updated .gitignore**:
```gitignore
# Build artifacts
build/

# Temporary files  
*.tmp
.DS_Store
*~

# IDE files
.vscode/
.idea/

# OS files
Thumbs.db
```

## CI/CD Integration

### GitHub Actions Workflow

**Build and Test Workflow** (`.github/workflows/build-and-test.yml`):
```yaml
name: Build and Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Install dependencies
      run: |
        sudo apt-get update
        sudo apt-get install -y shellcheck
        sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin
    
    - name: Build hype
      run: task build
    
    - name: Run linting
      run: task lint
    
    - name: Run tests  
      run: task test
    
    - name: Upload build artifact
      uses: actions/upload-artifact@v4
      with:
        name: hype-binary
        path: build/hype
        retention-days: 30
```

**Release Workflow** (`.github/workflows/release.yml`):
```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Install dependencies
      run: |
        sudo apt-get update
        sudo apt-get install -y shellcheck
        sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin
    
    - name: Build and test
      run: task validate
    
    - name: Upload release asset
      uses: actions/upload-release-asset@v1
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        asset_path: build/hype
        asset_name: hype
        asset_content_type: application/x-sh
```

## Development Workflow

### Development Commands

```bash
# Development mode execution
task dev-run CLI_ARGS="my-nginx --help"
export HYPE_DEV_MODE=true && bash src/main.sh my-nginx init

# Individual plugin development
shellcheck src/plugins/init.sh
bash -n src/plugins/init.sh  # Syntax check

# Build and test cycle
task build         # Build single script
task lint         # Lint all files
task test         # Run test suite
task install      # Install to ~/.local/bin
```

### Plugin Development Process

1. **Create Plugin File**: `src/plugins/<command>.sh`
2. **Implement Interface**: Follow plugin structure template
3. **Add Tests**: Create corresponding test in `tests/unit/`
4. **Lint and Test**: Validate individual plugin
5. **Integration Test**: Test with full build
6. **Documentation**: Update help text and README

### Testing Strategy

**Unit Tests**: Individual plugin testing
- Test each plugin in isolation
- Mock core functions as needed
- Validate plugin interface compliance

**Integration Tests**: Full system testing
- Test plugin discovery and execution
- Validate core module integration
- End-to-end command testing

**Build Tests**: Artifact validation
- Verify build process completeness
- ShellCheck validation of final script
- Installation and execution testing

## Migration Plan

### Phase 1: Structure Setup
- Create new directory structure
- Set up build system (Makefile)
- Update .gitignore
- Create plugin templates

### Phase 2: Core Module Extraction
- Extract common utilities to `src/core/common.sh`
- Extract configuration to `src/core/config.sh`
- Extract hypefile parsing to `src/core/hypefile.sh`
- Extract dependency checking to `src/core/dependencies.sh`

### Phase 3: Plugin Extraction
- Convert each `cmd_*` function to individual plugin
- Maintain API compatibility
- Test each plugin individually

### Phase 4: Build System Integration
- Implement concatenation build process
- Add ShellCheck integration
- Create test framework

### Phase 5: CI/CD Update
- Update GitHub Actions workflows
- Add artifact management
- Update release process

### Phase 6: Documentation and Cleanup
- Update documentation
- Remove old monolithic script
- Add plugin development guide

## Compatibility and Quality Assurance

### Backward Compatibility
- All existing commands maintain identical interfaces
- Environment variables remain unchanged
- Exit codes and error messages preserved
- Configuration file formats unchanged

### Quality Standards
- All code passes ShellCheck validation
- 100% test coverage for core modules
- Plugin interface compliance testing
- Performance benchmarking against monolithic version

### Performance Considerations
- Build-time optimization for production script
- Minimal runtime overhead from plugin system
- Preserved dependency checking and validation
- Maintained error handling and logging performance

## Success Metrics

### Development Efficiency
- Reduced time to add new commands
- Improved code review process
- Enhanced parallel development capability

### Code Quality
- Reduced code duplication
- Improved test coverage
- Enhanced maintainability metrics

### User Experience
- Preserved command-line interface
- Maintained performance characteristics
- Consistent error handling and logging

## Risks and Mitigation

### Technical Risks
- **Build complexity**: Mitigated by comprehensive testing and documentation
- **Performance impact**: Mitigated by benchmarking and optimization
- **Plugin conflicts**: Mitigated by naming conventions and interfaces

### Process Risks
- **Migration complexity**: Mitigated by phased rollout approach
- **Developer adoption**: Mitigated by clear documentation and training
- **Testing coverage**: Mitigated by automated test framework

## Future Enhancements

### Extensibility
- Third-party plugin support
- Plugin dependency management
- Dynamic plugin loading

### Tooling
- Plugin generator tools
- Automated testing frameworks
- Performance profiling tools

### Distribution
- Package manager integration
- Container-based distribution
- Multi-architecture support

---

This specification serves as the technical blueprint for HYPE CLI v0.6.0's modular plugin architecture, ensuring maintainable development practices while preserving production simplicity and performance.