# HYPE v0.3.5 Release Notes

## What's New

### Template State-Value Subcommand
Added a new `template state-value` subcommand to inspect StateValueConfigmap content:

```bash
hype <name> template state-value <configmap-name>
```

This command allows you to:
- View the YAML content that would be passed to helmfile as state-value-file
- Validate ConfigMap existence and type before helmfile execution
- Debug state-value configurations more easily

## Changes

- **New Feature**: `template state-value` subcommand for ConfigMap inspection
- **Improvement**: Better debugging capabilities for state-value configurations  
- **Backward Compatibility**: All existing commands work unchanged

## Usage

```bash
# View state-value content from a ConfigMap
hype test template state-value test-nginx-state-value

# Original template command still works
hype test helmfile template
```

**Full Changelog**: [v0.3.4...v0.3.5](https://github.com/foontype/hype/compare/v0.3.4...v0.3.5)