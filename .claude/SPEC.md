# HYPE CLI Specification

## Commands

### hype helmfile

Execute helmfile commands with special template processing.

#### Behavior

1. **Command Parsing**: Parse `hype helmfile [helmfile-options]` and preserve all options after `helmfile`
2. **Template Generation**: Execute `helmfile template` to generate templates
3. **ConfigMap Processing**: 
   - Read the configmap specified by the `templates.hype-name` key
   - Overwrite `templates.hype-configmap` with the contents from the hype-name configmap
   - Output the modified template to `.cache/<hype-name>.helmfile.yaml`
4. **Helmfile Execution**: Execute helmfile with the preserved options against the cached file

#### Example Usage

```bash
# Basic usage
hype helmfile sync

# With additional options
hype helmfile --environment production sync --dry-run
```

#### Implementation Details

- The `.cache/` directory should be created if it doesn't exist
- The `<hype-name>` is extracted from the `templates.hype-name` key in the helmfile templates
- All helmfile options and arguments are preserved and passed through to the final helmfile execution
- Error handling should be implemented for missing configmaps or invalid helmfile configurations