# HYPE CLI Specification

## Overview

HYPE is a command-line tool that provides a wrapper around the `helmfile` command with preprocessing capabilities for ConfigMap management.

## Command Structure

```bash
hype helmfile <helmfile options>
```

The `hype` command passes all options to the underlying `helmfile` command but performs preprocessing before execution.

## Preprocessing Workflow

### 1. Template Generation

Before executing the target helmfile command, hype runs:

```bash
helmfile <base options> template
```

This generates the helmfile.yaml template.

### 2. ConfigMap Management

After template generation, hype processes the `templates.hype` object list from the generated template:

- For each item in `templates.hype[]`:
  - Create a ConfigMap named `templates.hype[].name`
  - Store the structure from `templates.hype[].values` in the ConfigMap
  - **Important**: If the ConfigMap already exists, skip creation (no-op)

### 3. Value File Generation

For each ConfigMap:
- Extract values from the ConfigMap `templates.hype[].name`
- Save values to a temporary file
- Pass the temporary file to helmfile via `--state-value-file`

### 4. Final Execution

Execute helmfile with the generated value files:

```bash
helmfile <pre options> --state-value-file <temp_file_1> --state-value-file <temp_file_2> ... <mode> <post options>
```

## Example Usage

```bash
hype helmfile apply
```

**Processing Flow:**
1. Run `helmfile template` to generate helmfile.yaml
2. Process `templates.hype` objects (e.g., `templates.hype[0].name = "hoge"`)
3. Create/verify ConfigMap "hoge" with values from `templates.hype[0].values`
4. Extract values from ConfigMap "hoge" to temporary file
5. Execute `helmfile --state-value-file <temp_file> apply`

## Configuration Structure

### templates.hype Format

```yaml
templates:
  hype:
    - name: "config-name-1"
      values:
        key1: value1
        key2: value2
    - name: "config-name-2" 
      values:
        key3: value3
        key4: value4
```

## Implementation Requirements

- POSIX compatible Bash script
- Error handling for kubectl/helmfile commands
- Temporary file cleanup
- ConfigMap existence checking
- Support for multiple state value files

## Dependencies

- kubectl (for ConfigMap operations)
- helmfile (target command)
- Bash 4.0+