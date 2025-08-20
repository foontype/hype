# HYPE CLI Implementation Plan

## Overview
Implement `hype helmfile` command that executes helmfile commands with special template processing, ConfigMap/Secret auto-creation, and caching functionality.

## Implementation Steps

### 1. Command Structure Enhancement
- [ ] Modify main argument parsing in `src/hype` to handle `helmfile` subcommand
- [ ] Implement `cmd_helmfile()` function
- [ ] Add helmfile help text to existing help system

### 2. Argument Parsing for helmfile Command
- [ ] Parse command line: `hype helmfile [pre-options] <execution-mode> [post-options]`
- [ ] Identify execution modes: `sync`, `apply`, `diff`, `template`, etc.
- [ ] Separate pre-options (for template generation) from post-options (for final execution)
- [ ] Handle special cases and edge cases in argument parsing

### 3. Template Generation System
- [ ] Execute `helmfile [pre-options] template` command
- [ ] Capture template output for processing
- [ ] Parse YAML output to extract template metadata
- [ ] Implement error handling for invalid helmfile configurations

### 4. ConfigMap Processing Logic
- [ ] Extract `templates.hype-name` key from generated templates
- [ ] Validate that `templates.hype-name` exists (error if missing)
- [ ] Check if named ConfigMap exists in Kubernetes cluster
- [ ] If ConfigMap doesn't exist:
  - Create ConfigMap using `templates.hype-configmap` contents
- [ ] Read existing ConfigMap contents
- [ ] Overwrite `templates.hype-configmap` with ConfigMap data
- [ ] Handle Kubernetes API access errors

### 5. Secrets Processing Logic
- [ ] Check if Kubernetes secret `<hype-name>-secrets` exists
- [ ] If secret doesn't exist:
  - Create secret using `templates.hype-secrets` contents
- [ ] Implement proper error handling for Kubernetes operations
- [ ] Handle authentication and permission issues

### 6. Caching System
- [ ] Create `.cache/` directory if it doesn't exist
- [ ] Generate cached helmfile: `.cache/<hype-name>.helmfile.yaml`
- [ ] Write modified template with updated ConfigMap data to cache file
- [ ] Implement cache cleanup mechanisms (optional)

### 7. Final Helmfile Execution
- [ ] Execute `helmfile -f .cache/<hype-name>.helmfile.yaml <execution-mode> [post-options]`
- [ ] Preserve original post-options in final command
- [ ] Handle helmfile execution errors and output

### 8. Error Handling and Validation
- [ ] Validate helmfile installation and availability
- [ ] Validate kubectl/kubernetes access
- [ ] Handle missing `templates.hype-name` key (mandatory error)
- [ ] Handle YAML parsing errors
- [ ] Handle Kubernetes API errors
- [ ] Provide meaningful error messages for all failure scenarios

### 9. Dependencies and Requirements
- [ ] Check for `helmfile` command availability
- [ ] Check for `kubectl` command availability
- [ ] Verify Kubernetes cluster connectivity
- [ ] Validate required permissions for ConfigMap/Secret operations

### 10. Testing and Validation
- [ ] Create test helmfile configurations
- [ ] Test with various pre-options and post-options combinations
- [ ] Test ConfigMap auto-creation scenarios
- [ ] Test Secret auto-creation scenarios
- [ ] Test error conditions and edge cases
- [ ] Validate caching functionality

### 11. Documentation Updates
- [ ] Update help text for `hype helmfile` command
- [ ] Add usage examples in help output
- [ ] Update main help to include helmfile subcommand

## Technical Implementation Notes

### File Structure
```
src/hype (main script)
├── cmd_helmfile() function
├── parse_helmfile_args() helper
├── process_templates() helper
├── handle_configmap() helper
├── handle_secrets() helper
└── execute_helmfile() helper
```

### Key Functions to Implement
1. `cmd_helmfile()` - Main helmfile command handler
2. `parse_helmfile_args()` - Parse complex argument structure
3. `process_templates()` - Generate and process templates
4. `handle_configmap()` - ConfigMap creation and processing
5. `handle_secrets()` - Secret creation and processing
6. `execute_helmfile()` - Final helmfile execution

### External Dependencies
- `helmfile` command (required)
- `kubectl` command (required)
- `yq` or similar YAML processor (for parsing templates)
- Kubernetes cluster access with appropriate permissions

### Error Exit Codes
- 1: General error
- 2: Missing dependencies (helmfile, kubectl)
- 3: Kubernetes access error
- 4: Missing required template keys
- 5: YAML parsing error

## Implementation Priority
1. Basic command structure and argument parsing
2. Template generation and processing
3. ConfigMap handling logic
4. Caching system
5. Final helmfile execution
6. Secrets processing
7. Comprehensive error handling
8. Testing and validation