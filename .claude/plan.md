# HYPE Implementation Plan

## Phase 1: Core Infrastructure
- [ ] Update `src/hype` script structure to handle `helmfile` subcommand
- [ ] Add dependency validation (kubectl, helmfile, yq)
- [ ] Implement proper error handling with exit codes
- [ ] Add debug logging capability

## Phase 2: Template Generation
- [ ] Implement `helmfile template` execution with user options
- [ ] Parse generated helmfile.yaml for `templates.hype` objects
- [ ] Extract ConfigMap specifications from template output

## Phase 3: ConfigMap Management  
- [ ] Check ConfigMap existence using kubectl
- [ ] Create ConfigMaps only if they don't exist (no-op for existing)
- [ ] Store values from `templates.hype[].values` in ConfigMaps
- [ ] Handle multiple ConfigMap creation

## Phase 4: Value File Processing
- [ ] Extract values from existing ConfigMaps
- [ ] Generate temporary value files for each ConfigMap
- [ ] Implement cleanup mechanism for temporary files

## Phase 5: Helmfile Execution
- [ ] Construct final helmfile command with `--state-value-file` options
- [ ] Pass through all original user options correctly
- [ ] Execute helmfile with generated value files

## Phase 6: Error Handling & Cleanup
- [ ] Implement proper error handling at each step
- [ ] Ensure temporary file cleanup on exit/error
- [ ] Add comprehensive validation for YAML parsing
- [ ] Handle missing dependencies gracefully

## Phase 7: Testing & Documentation
- [ ] Create test scenarios for ConfigMap workflows
- [ ] Add help documentation for new helmfile subcommand
- [ ] Test with various helmfile options and edge cases
- [ ] Update version information

## Implementation Notes

### File Structure Changes
- Remove existing `hello`, `world` commands (not needed)
- Implement `helmfile` as the primary subcommand
- Maintain current CLI argument parsing pattern

### Dependencies
- kubectl: ConfigMap operations
- helmfile: Target command execution  
- yq: YAML parsing (if needed)
- Bash 4.0+: Script execution

### Key Functions to Implement
- `cmd_helmfile()`: Main helmfile wrapper logic
- `generate_template()`: Run helmfile template command
- `parse_hype_objects()`: Extract templates.hype from YAML
- `manage_configmaps()`: Create/check ConfigMaps
- `extract_values()`: Get values from ConfigMaps to temp files
- `cleanup_temp_files()`: Clean temporary files
- `execute_helmfile()`: Final helmfile execution

### Error Handling Strategy
- Validate dependencies before execution
- Check kubectl context and permissions
- Validate YAML parsing results
- Proper exit codes for different failure modes
- Cleanup temporary files on any exit path