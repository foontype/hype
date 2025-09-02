# HYPE CLI v0.6.0 Implementation Plan

## Overview

This document outlines the step-by-step implementation plan for migrating HYPE CLI from the current monolithic structure to the plugin-based architecture defined in the v0.6.0 specification.

## Current State Analysis

### Existing Structure
- **Single file**: `src/hype` (1,278 lines)
- **Commands identified**: 8 command functions
  - `cmd_init` (line 575)
  - `cmd_deinit` (line 615)
  - `cmd_check_resources` (line 655)
  - `cmd_template_hype_section` (line 696)
  - `cmd_template` (line 713)
  - `cmd_template_state_value` (line 734)
  - `cmd_parse` (line 795)
  - `cmd_parse_section` (line 832)
  - `cmd_trait` (line 869)
  - `cmd_upgrade` (line 997)
  - `cmd_task` (line 1070)
  - `cmd_helmfile` (line 1097)

### Core Functions to Extract
- Logging functions: `debug()`, `info()`, `warn()`, `error()`, `die()`
- Configuration: Version, environment variables
- Hypefile parsing: `parse_hypefile()` and related functions
- Utility functions: Color constants, cleanup functions

## Implementation Phases

### Phase 1: Structure Setup ⏳
**Estimated time**: 1-2 hours

#### Tasks:
1. **Create directory structure**
   ```bash
   mkdir -p src/core src/plugins build tests/unit tests/integration
   ```

2. **Create .gitignore updates**
   ```gitignore
   # Add to existing .gitignore:
   build/
   *.tmp
   ```

3. **Create Makefile skeleton**
   - Basic build, lint, clean, test targets
   - Variables for core and plugin files

4. **Create plugin template file**
   - Standard plugin structure for developers

#### Deliverables:
- [ ] Directory structure created
- [ ] Updated .gitignore
- [ ] Basic Makefile
- [ ] Plugin template documentation

### Phase 2: Core Module Extraction ⏳
**Estimated time**: 3-4 hours

#### Tasks:
1. **Extract `src/core/common.sh`**
   - Logging functions (debug, info, warn, error, die)
   - Color constants
   - Silent function
   - Utility functions

2. **Extract `src/core/config.sh`**
   - HYPE_VERSION
   - Environment variables (HYPEFILE, HYPE_LOG, DEBUG, TRACE)
   - Default configurations

3. **Extract `src/core/hypefile.sh`**
   - `parse_hypefile()` function
   - Template variable substitution
   - Section file management
   - Cleanup functions

4. **Extract `src/core/dependencies.sh`**
   - Dependency checking functions
   - Tool availability verification

#### Deliverables:
- [ ] `src/core/common.sh` with logging and utilities
- [ ] `src/core/config.sh` with configuration management
- [ ] `src/core/hypefile.sh` with parsing functionality
- [ ] `src/core/dependencies.sh` with validation functions

### Phase 3: Plugin Extraction ⏳
**Estimated time**: 4-6 hours

#### Plugin Mapping:
1. **`src/plugins/init.sh`**
   - `cmd_init()` → `cmd_init()`
   - `cmd_deinit()` → `cmd_deinit()`
   - `cmd_check_resources()` → `cmd_check()`

2. **`src/plugins/template.sh`**
   - `cmd_template()` → `cmd_template()`
   - `cmd_template_hype_section()` → helper function
   - `cmd_template_state_value()` → helper function

3. **`src/plugins/parse.sh`**
   - `cmd_parse()` → `cmd_parse()`
   - `cmd_parse_section()` → helper function

4. **`src/plugins/trait.sh`**
   - `cmd_trait()` → `cmd_trait()`

5. **`src/plugins/upgrade.sh`**
   - `cmd_upgrade()` → `cmd_upgrade()`

6. **`src/plugins/task.sh`**
   - `cmd_task()` → `cmd_task()`

7. **`src/plugins/helmfile.sh`**
   - `cmd_helmfile()` → `cmd_helmfile()`

#### Tasks per plugin:
1. Extract command function from monolithic script
2. Add plugin metadata header
3. Identify and include helper functions
4. Add plugin interface compliance
5. Test individual plugin functionality

#### Deliverables:
- [ ] 7 plugin files following standard interface
- [ ] Helper functions properly encapsulated
- [ ] Plugin metadata included

### Phase 4: Build System Implementation ⏳
**Estimated time**: 2-3 hours

#### Tasks:
1. **Complete Makefile implementation**
   - Build target: concatenate core + plugins + main
   - Lint target: ShellCheck all source files
   - Clean target: remove build artifacts
   - Test target: run test suite
   - Dev-run target: development mode execution
   - Install target: copy to ~/.local/bin

2. **Create `src/main.sh`**
   - Plugin discovery mechanism
   - Plugin execution framework
   - Command routing logic
   - Development vs production mode handling

3. **Build process implementation**
   - Header generation (shebang, set options)
   - Core module concatenation
   - Plugin concatenation
   - Main script addition
   - Executable permissions

#### Deliverables:
- [ ] Complete Makefile with all targets
- [ ] `src/main.sh` entry point
- [ ] Working build process
- [ ] Development mode support

### Phase 5: Testing Framework ⏳
**Estimated time**: 3-4 hours

#### Tasks:
1. **Unit test framework**
   - Individual plugin test scripts
   - Core module test scripts
   - Mock function framework

2. **Integration test framework**
   - Full command execution tests
   - Plugin discovery tests
   - Build artifact validation

3. **Test runner implementation**
   - `tests/test-suite.sh` main runner
   - Test result aggregation
   - CI-friendly output format

#### Test Coverage Goals:
- [ ] All core functions tested
- [ ] All plugins tested individually
- [ ] Integration tests for main commands
- [ ] Build artifact validation

#### Deliverables:
- [ ] Unit tests for core modules
- [ ] Unit tests for plugins
- [ ] Integration test suite
- [ ] Test runner script

### Phase 6: CI/CD Integration ⏳
**Estimated time**: 1-2 hours

#### Tasks:
1. **Update GitHub Actions workflows**
   - Build and test workflow (`.github/workflows/build-and-test.yml`)
   - Release workflow updates
   - Artifact management

2. **Quality gates integration**
   - ShellCheck validation
   - Test execution requirements
   - Build success validation

#### Deliverables:
- [ ] Updated CI/CD workflows
- [ ] Build artifacts in CI
- [ ] Quality gates enforcement

### Phase 7: Documentation and Cleanup ⏳
**Estimated time**: 2-3 hours

#### Tasks:
1. **Update documentation**
   - README.md updates
   - CLAUDE.md updates
   - Plugin development guide

2. **Cleanup legacy code**
   - Remove monolithic `src/hype` (after validation)
   - Update install.sh if needed
   - Archive old structure

3. **Version update**
   - Update version to 0.6.0
   - Create release notes
   - Tag release

#### Deliverables:
- [ ] Updated documentation
- [ ] Legacy code cleanup
- [ ] Version 0.6.0 ready for release

## Risk Mitigation Strategies

### Technical Risks
1. **Build complexity**
   - Mitigation: Comprehensive testing at each phase
   - Rollback: Keep original script until full validation

2. **Performance impact**
   - Mitigation: Benchmark against original script
   - Optimization: Build-time optimizations

3. **Plugin interface conflicts**
   - Mitigation: Strict naming conventions
   - Validation: Plugin interface compliance tests

### Process Risks
1. **Migration complexity**
   - Mitigation: Phased approach with validation at each step
   - Backup: Git branch for rollback

2. **Backward compatibility**
   - Mitigation: Extensive integration testing
   - Validation: Existing test suite execution

## Success Criteria

### Phase Completion Criteria
Each phase must meet the following criteria before proceeding:
1. All deliverables completed and tested
2. No regressions in existing functionality
3. ShellCheck validation passes
4. Git commit with clear description

### Final Success Criteria
1. **Functional**: All existing commands work identically
2. **Performance**: No significant performance degradation
3. **Quality**: 100% ShellCheck compliance
4. **Maintainability**: Individual plugins can be developed independently
5. **CI/CD**: Automated build and test pipeline working

## Timeline

**Total estimated time**: 16-25 hours over 1-2 weeks

### Week 1
- Phases 1-3: Structure setup and core extraction
- Daily progress reviews and validation

### Week 2
- Phases 4-7: Build system, testing, and finalization
- Integration testing and documentation

## Dependencies

### Required Tools
- bash 4.0+
- make
- shellcheck
- git

### Optional Tools
- shfmt (for formatting)
- bats (for testing framework)

## Rollback Plan

If migration fails or introduces critical issues:
1. Revert to original `src/hype` script
2. Remove new directory structure
3. Restore original .gitignore and workflows
4. Document lessons learned for future attempts

---

This implementation plan provides a structured approach to migrating HYPE CLI to the v0.6.0 plugin architecture while minimizing risk and ensuring backward compatibility.