# HYPE CLI Examples

This directory contains practical examples demonstrating HYPE CLI's helmfile wrapper functionality.

## nginx Example

### Files
- `nginx/helmfile.yaml` - Complete helmfile configuration with HYPE templates
- `nginx/run-example.sh` - Demonstration script showing HYPE CLI usage

### Features Demonstrated

**HYPE Template Configuration:**
- `state-value-file` type for nginx application configuration
- `secrets-default` type for default authentication values
- Environment-specific ConfigMap naming

**nginx Deployment:**
- Bitnami nginx Helm chart integration
- Environment-specific configuration (dev/prod)
- Ingress configuration with dynamic host names
- Service and replica configuration

### Usage

```bash
cd examples/nginx

# Run the demonstration script
./run-example.sh

# Or run commands directly:

# 1. Generate template to see HYPE processing
DEBUG=1 ../../src/hype helmfile -f helmfile.yaml -e hype-example template

# 2. Show diff (creates ConfigMaps, shows what would deploy)
../../src/hype helmfile -f helmfile.yaml -e hype-example diff

# 3. Deploy nginx (creates ConfigMaps and deploys)
../../src/hype helmfile -f helmfile.yaml -e hype-example apply
```

### What Happens

1. **Template Processing**: HYPE CLI detects `templates.hype` configuration
2. **ConfigMap Creation**: 
   - `hype-example-nginx-config` with application settings
   - `hype-example-nginx-secrets` with authentication defaults
3. **Value Injection**: Temporary value files generated from ConfigMaps
4. **Helmfile Execution**: Final helmfile command with `--state-values-file`

### Environment Variables

- `DEBUG=1` - Enable verbose logging to see HYPE processing steps
- Custom environment values can be passed via helmfile's standard mechanisms

### Prerequisites

- kubectl (configured with cluster access)
- helmfile
- yq (for YAML processing)
- Bitnami Helm repository added: `helm repo add bitnami https://charts.bitnami.com/bitnami`
