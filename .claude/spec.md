# HYPE CLI Specification

## Overview

HYPE is a command-line tool that serves as a Helmfile wrapper to support AI Kubernetes deployments. It reads configuration from `hypefile.yaml` to create default Kubernetes resources and execute Helmfile commands.

## Implementation

- **Language**: Bash
- **Main script**: `src/hype`
- **Tests**: `tests/` directory using bats framework

## Configuration File

### hypefile.yaml Format

The configuration file `hypefile.yaml` defines default resources and Helmfile settings.

#### Default Resources Types

1. **StateValueConfigmap**
   - Created during `hype <name> init`
   - Name and values specified in configuration
   - Content passed as `--state-value-file` option during `hype <name> helmfile`

2. **ConfigMap**
   - Created during `hype <name> init`
   - Name and values specified in configuration
   - Standard Kubernetes ConfigMap resource

3. **Secrets**
   - Created during `hype <name> init`
   - Name and values specified in configuration
   - Standard Kubernetes Secret resource

#### Template Variables

- `{{ .Hype.Name }}`: Environment name passed to hype command

### Example Configuration

```yaml
defaultResources:
  - name: {{ .Hype.Name }}-state-value
    type: StateValueConfigmap
    values:
      hoge: 12345

  - name: {{ .Hype.Name }}-configmap
    type: Configmap
    values:
      fuga: 23456

  - name: {{ .Hype.Name }}-secrets
    type: Secrets
    values:
      piyo: 34567

helmfile:
  releases:
    ...
```

## Command Interface

### hype <name> init

- **Purpose**: Creates default Kubernetes resources
- **Behavior**: 
  - Reads `hypefile.yaml` configuration
  - Creates ConfigMaps and Secrets as defined in `defaultResources`
  - Replaces template variables with actual environment name

### hype <name> helmfile <helmfile-options>

- **Purpose**: Executes Helmfile commands with pre-configured state values
- **Behavior**:
  - Passes StateValueConfigmap content as `--state-value-file` option
  - Passes `<name>` as `-e` option to Helmfile
  - Forwards additional `<helmfile-options>` to Helmfile command

## Usage Examples

### Basic Deployment

```bash
# Initialize environment resources
hype my-nginx init

# Apply Helmfile configuration
hype my-nginx helmfile apply
```

This will:
1. Create default resources with names prefixed by "my-nginx"
2. Execute `helmfile apply` with environment name "my-nginx"
3. Pass StateValueConfigmap content as state value file

### Development Workflow

```bash
# Initialize development environment
hype dev init

# Deploy to development environment
hype dev helmfile sync

# Check deployment status
hype dev helmfile status
```

## Technical Requirements

- Bash 4.0+ compatibility
- kubectl available in PATH
- helmfile available in PATH
- Kubernetes cluster access configured
- YAML parsing capability (using yq or similar)

## Error Handling

- Exit with non-zero status on configuration parsing errors
- Exit with non-zero status on Kubernetes resource creation failures
- Exit with non-zero status on Helmfile command failures
- Provide meaningful error messages for debugging

## Template Processing

- Support Go template syntax in `hypefile.yaml`
- Available variables:
  - `.Hype.Name`: Environment name from command line
- Process templates before resource creation and Helmfile execution