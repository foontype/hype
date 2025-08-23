# HYPE CLI Specification

## Overview

HYPE CLI is a Helmfile wrapper tool designed to assist with AI Kubernetes deployments. It reads configuration from `hypefile.yaml`, creates default resources, and performs container deployment via Helmfile.

## Implementation Details

- **Language**: Bash
- **Main Script**: `src/hype`
- **Tests**: `tests/` directory using BATS framework

## Configuration File Format

### hypefile.yaml Structure

The configuration file is split into two sections separated by `---`:

1. **Hype Section**: Contains default resource definitions
2. **Helmfile Section**: Standard Helmfile configuration

### Template Processing

- `{{ .Hype.Name }}` placeholders are replaced with `<hype name>` during processing
- File is split into two temporary files based on the `---` separator

## Default Resource Types

### StateValueConfigmap
- **Created**: During `hype <name> init`
- **Purpose**: Creates Kubernetes ConfigMap with specified name and values
- **Usage**: Content is passed as `--state-value-file` option during `hype <name> helmfile` execution

### Configmap
- **Created**: During `hype <name> init`
- **Purpose**: Creates standard Kubernetes ConfigMap with specified name and values

### Secrets
- **Created**: During `hype <name> init`
- **Purpose**: Creates Kubernetes Secret with specified name and values

## Command Interface

### Command Structure
```
hype <hype name> <subcommand> [options]
```

### Subcommands

#### init
```
hype <hype name> init
```
- Creates default resources as defined in hypefile.yaml
- Processes template variables ({{ .Hype.Name }} → <hype name>)
- Creates Kubernetes resources (ConfigMaps, Secrets)

#### helmfile
```
hype <hype name> helmfile <helmfile options>
```
- Executes helmfile command with processed configuration
- Automatically passes StateValueConfigmap content via `--state-value-file`
- Passes `<hype name>` as environment variable via `-e` option
- Forwards all additional options to helmfile command

#### deinit (implied)
- Removes default resources created during init

## Usage Examples

### Basic Deployment
```bash
hype my-nginx helmfile apply
```
- Environment name: `my-nginx`
- Applies Helmfile configuration from hypefile.yaml
- Pre-creates default resources with `my-nginx` as the name template

### Initialization Only
```bash
hype my-nginx init
```
- Creates default resources for `my-nginx` environment
- Does not execute Helmfile deployment

## File Processing Workflow

1. Read `hypefile.yaml`
2. Split content at `---` separator into:
   - Hype section (default resources)
   - Helmfile section (deployment configuration)
3. Create temporary files for each section
4. Process template variables in hype section
5. Execute appropriate operations based on subcommand

## Resource Management

### Resource Naming Convention
- All resources use the pattern: `<hype name>-<resource-type>`
- Example: For name `my-nginx`:
  - StateValueConfigmap: `my-nginx-state-value`
  - Configmap: `my-nginx-configmap`
  - Secrets: `my-nginx-secrets`

### Lifecycle Management
- Resources are created during `init` subcommand
- Resources are used during `helmfile` subcommand
- Resources should be cleaned up during `deinit` operation

## Integration Points

### Helmfile Integration
- StateValueConfigmap content is exported to temporary file
- File path passed to helmfile via `--state-value-file`
- Environment name passed via `-e <hype name>`
- All other helmfile options are passed through unchanged

### Kubernetes Integration
- Direct kubectl commands for resource creation/deletion
- Standard Kubernetes resource formats (ConfigMap, Secret)
- Namespace-aware operations (default or specified namespace)