# HYPE CLI Specification

## Commands

### hype helmfile

Execute helmfile commands with special template processing.

#### Behavior

1. **Command Parsing**: Parse `hype helmfile [pre-options] <execution-mode> [post-options]`
   - Pre-options: Options before the execution mode (used with `helmfile template`)
   - Execution mode: Commands like `sync`, `apply`, `diff`, etc.
   - Post-options: Options after the execution mode (preserved for final execution)
2. **Template Generation**: Execute `helmfile [pre-options] template` to generate templates
3. **ConfigMap Processing**: 
   - Validate that `templates.hype-name` key exists (error if missing)
   - Read the configmap specified by the `templates.hype-name` key
   - If the hype-name configmap doesn't exist, create it using `templates.hype-configmap` contents
   - Overwrite `templates.hype-configmap` with the contents from the hype-name configmap
   - Output the modified template to `.cache/<hype-name>.helmfile.yaml`
4. **Secrets Processing**:
   - Check if Kubernetes secret `<hype-name>-secrets` exists
   - If the secret doesn't exist, create it using `templates.hype-secrets` contents
5. **Helmfile Execution**: Execute `helmfile` against the cached file with execution mode and post-options

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
- Pre-options are passed to `helmfile template` command for template generation
- Execution mode and post-options are preserved for the final helmfile execution against cached file
- Error handling should be implemented for:
  - Missing `templates.hype-name` key (mandatory)
  - Invalid helmfile configurations
  - Kubernetes API access errors during configmap/secret operations
- ConfigMap and Secret auto-creation requires appropriate Kubernetes permissions
- The `templates.hype-configmap` and `templates.hype-secrets` should contain valid YAML data for initialization