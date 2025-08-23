# HYPE CLI Specification

## Overview

HYPE CLI is a Helmfile wrapper tool designed to assist with AI Kubernetes deployments. It reads configuration from `hypefile.yaml` and manages default resources creation and container deployment via Helmfile.

## Implementation

- Language: Bash
- Main script: `src/hype`
- Tests: `tests/` directory using bats framework

## Configuration File Format

### hypefile.yaml Structure

The configuration file is divided into two sections separated by `---`:

1. **HYPE Section**: Defines default Kubernetes resources
2. **Helmfile Section**: Standard Helmfile configuration

#### Template Variables

- `{{ .Hype.Name }}` is replaced with `<hype name>` specified in commands

#### Default Resources Types

**StateValueConfigmap**
- Created during `hype <name> init`
- Kubernetes ConfigMap with specified name and values
- Contents passed to Helmfile via `--state-value-file` option

**ConfigMap** 
- Created during `hype <name> init`
- Standard Kubernetes ConfigMap with specified name and values

**Secrets**
- Created during `hype <name> init` 
- Kubernetes Secret with specified name and values

## Command Interface

### Command Structure
```
hype <hype name> <subcommand> [options]
```

### Subcommands

#### `init`
```
hype <hype name> init
```
- Creates default resources defined in hypefile.yaml
- Skips creation if resources already exist
- Replaces `{{ .Hype.Name }}` with the provided name

#### `deinit`
```
hype <hype name> deinit
```
- Destroys default resources created by init
- Removes all resources associated with the hype name

#### `check`
```
hype <hype name> check
```
- Lists all default resources
- Shows creation status (created/not created) for each resource

#### `helmfile`
```
hype <hype name> helmfile <helmfile options>
```
- Executes Helmfile commands using the Helmfile section configuration
- StateValueConfigmap contents passed via `--state-value-file`
- Hype name passed as environment variable via `-e` option

## Usage Examples

### Basic Deployment
```bash
# Initialize resources for my-nginx environment
hype my-nginx init

# Deploy using Helmfile
hype my-nginx helmfile apply

# Check resource status
hype my-nginx check

# Clean up
hype my-nginx deinit
```

## File Processing Workflow

1. Parse `hypefile.yaml` and split at `---` separator
2. Create two temporary files:
   - HYPE section file (for init/deinit operations)
   - Helmfile section file (for helmfile operations)
3. Process template variables (`{{ .Hype.Name }}` � actual name)
4. Execute appropriate operations based on subcommand

## Dependencies

- Bash 4.0+
- kubectl (for Kubernetes operations)
- helmfile (for Helmfile operations)
- Access to Kubernetes cluster

## Error Handling

- Validate hypefile.yaml format before processing
- Check Kubernetes connectivity before resource operations
- Provide clear error messages for common failure scenarios
- Use consistent exit codes for different error types