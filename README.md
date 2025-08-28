# HYPE CLI

A simple command-line tool that wraps Helmfile for Kubernetes AI deployments, providing streamlined management of default resources and configurations.

## Overview

HYPE is a Bash-based CLI tool that simplifies the deployment and management of Kubernetes applications using Helmfile. It introduces the concept of "hypefile.yaml" - a structured configuration file that separates default resources from Helmfile configurations.

## Features

- **Default Resource Management**: Automatically create and manage ConfigMaps and Secrets
- **Template Rendering**: Process hypefile.yaml templates with dynamic values
- **Helmfile Integration**: Seamless integration with existing Helmfile workflows
- **Resource Status Checking**: Monitor the status of managed resources
- **Debug Support**: Built-in debug logging for troubleshooting

## Installation

### Quick Install

```bash
curl -sSL https://raw.githubusercontent.com/foontype/hype/main/install.sh | bash
```

### Install Specific Version

You can install a specific version using the `INSTALL_VERSION` environment variable:

```bash
# Install specific version
curl -sSL https://raw.githubusercontent.com/foontype/hype/main/install.sh | INSTALL_VERSION=v0.2.1 bash

# Or download and run locally
curl -sSL https://raw.githubusercontent.com/foontype/hype/main/install.sh -o install.sh
INSTALL_VERSION=v0.2.1 ./install.sh
```

### Manual Install

```bash
git clone https://github.com/foontype/hype.git
cd hype
./install.sh
```

### Development Install

```bash
chmod +x src/hype
ln -s $(pwd)/src/hype ~/.local/bin/hype
```

## Usage

### Basic Commands

```bash
# Initialize default resources for a deployment
hype <hype-name> init

# Check status of default resources
hype <hype-name> check

# Show rendered hype section template
hype <hype-name> template

# Run helmfile commands with generated configuration
hype <hype-name> helmfile <helmfile-options>

# Clean up default resources
hype <hype-name> deinit

# Show version and help
hype --version
hype --help
```

### Environment Variables

- `HYPEFILE`: Path to hypefile.yaml (default: hypefile.yaml)
- `DEBUG`: Enable debug output (default: false)

## Hypefile Format

The `hypefile.yaml` file consists of two sections separated by `---`:

1. **Hype Section**: Defines default resources (ConfigMaps, Secrets)
2. **Helmfile Section**: Standard Helmfile configuration

### Example: nginx deployment

```yaml
defaultResources:
  - name: "{{ .Hype.Name }}-nginx-state-value"
    type: StateValuesConfigmap
    values:
      nginx:
        replicaCount: 2
        image:
          tag: "1.21.6"
        service:
          type: ClusterIP
          port: 80
        ingress:
          enabled: true
          hosts:
            - host: "nginx-{{ .Hype.Name }}.example.com"
              paths:
                - path: /
                  pathType: Prefix

  - name: "{{ .Hype.Name }}-nginx-secrets"
    type: Secrets
    values:
      nginx:
        auth:
          username: "admin"
          password: "changeme123"

---
releases:
  - name: nginx
    namespace: default
    chart: bitnami/nginx
    version: "13.2.23"
    values:
    - replicaCount: "{{ .Values.nginx.replicaCount | default 1 }}"
    - image:
        tag: "{{ .Values.nginx.image.tag | default \"latest\" }}"
    - service:
        type: "{{ .Values.nginx.service.type | default \"ClusterIP\" }}"
        port: "{{ .Values.nginx.service.port | default 80 }}"
    - ingress:
        enabled: "{{ .Values.nginx.ingress.enabled | default false }}"
        hosts: "{{ .Values.nginx.ingress.hosts | default list }}"

repositories:
  - name: bitnami
    url: https://charts.bitnami.com/bitnami
```

## Examples

### Deploy nginx with custom configuration

```bash
# Initialize resources for my-nginx deployment
hype my-nginx init

# Check resource status
hype my-nginx check

# View rendered configuration
hype my-nginx template

# Apply the deployment
hype my-nginx helmfile apply

# Update the deployment
hype my-nginx helmfile diff
hype my-nginx helmfile apply

# Clean up
hype my-nginx deinit
```

### Debug mode

```bash
DEBUG=true hype my-nginx init
```

## Resource Types

HYPE supports the following default resource types:

### StateValuesConfigmap / Configmap
Creates Kubernetes ConfigMaps that can be used as state values in Helmfile templates.

### Secrets
Creates Kubernetes Secrets for sensitive configuration data.

## Dependencies

- Bash 4.0+
- kubectl
- helmfile
- yq

## Development

### Running Tests

```bash
# Test the main script
./src/hype --help
./src/hype --version

# Test with example
cd examples/nginx
../../src/hype test-nginx init
../../src/hype test-nginx check
../../src/hype test-nginx template
../../src/hype test-nginx deinit
```

### Code Quality

```bash
# Lint bash scripts
shellcheck src/hype
shellcheck install.sh

# Format (if shfmt is available)
shfmt -w -ci src/hype
```

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make changes and test thoroughly
4. Run linting: `shellcheck src/hype`
5. Commit with descriptive messages
6. Push to your fork and create a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

- Create an issue for bug reports or feature requests
- Check existing issues and discussions
- Review the documentation and examples