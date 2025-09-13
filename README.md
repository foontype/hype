# HYPE CLI

A modular command-line tool written in Bash for Kubernetes AI deployments, providing streamlined management of default resources and configurations through a modular architecture.

## Overview

HYPE is a Bash-based CLI tool that simplifies the deployment and management of Kubernetes applications using Helmfile. It uses a modular architecture with separate core modules and builtins for different commands, following a build system approach where individual components are combined into a single executable. The tool introduces the concept of "hypefile.yaml" - a structured configuration file that separates default resources from Helmfile configurations.

## Features

- **Default Resource Management**: Automatically create and manage ConfigMaps and Secrets
- **Template Rendering**: Process hypefile.yaml templates with dynamic values
- **Helmfile Integration**: Seamless integration with existing Helmfile workflows
- **Resource Status Checking**: Monitor the status of managed resources
- **Debug Support**: Built-in debug logging for troubleshooting

## Project Structure

- `src/core/` - Core modules (config, common, hypefile, dependencies)
- `src/builtins/` - Builtin modules (init, template, parse, trait, upgrade, task, helmfile)
- `src/main.sh` - Main entry point and command routing
- `build/` - Build artifacts (generated executable)
- `tests/` - Test framework and unit tests
- `Taskfile.yml` - Build system configuration
- `install.sh` - Installation script
- `.github/workflows/` - CI/CD pipelines for testing and release

## Installation

### Quick Install

```bash
curl -sSL https://raw.githubusercontent.com/foontype/hype/main/install.sh | bash
```

For system-wide installation (installs to `/usr/local/bin`):
```bash
curl -sSL https://raw.githubusercontent.com/foontype/hype/main/install.sh | sudo bash
```

### Install Specific Version

You can install a specific version using the `INSTALL_VERSION` environment variable:

```bash
# Install specific version
curl -sSL https://raw.githubusercontent.com/foontype/hype/main/install.sh | INSTALL_VERSION=v0.6.1 bash

# Or download and run locally
curl -sSL https://raw.githubusercontent.com/foontype/hype/main/install.sh -o install.sh
INSTALL_VERSION=v0.6.1 ./install.sh
```

### Manual Install

```bash
git clone https://github.com/foontype/hype.git
cd hype
./install.sh
```

### Development Install

```bash
# Build and install locally
git clone https://github.com/foontype/hype.git
cd hype
task build
task install

# Or test the install script
./install.sh

# For development work, use built binary
./build/hype --version
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
  - name: "{{ .Hype.Name }}-nginx-state-values"
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
- Git (for development)
- kubectl
- helmfile
- yq

## Development

### Essential Commands

```bash
# Build and test the CLI
task build
task test

# Test built binary functionality
./build/hype --version
./build/hype --help

# Run linting on all components
task lint

# Individual component testing
shellcheck src/core/*.sh
shellcheck src/builtins/*.sh
shellcheck src/main.sh
```

### Code Quality

```bash
# Lint all components
task lint

# Format bash scripts (if shfmt is available)
shfmt -w -ci src/core/*.sh src/builtins/*.sh src/main.sh

# Clean build artifacts
task clean
```

### Smoke Testing

Follow the comprehensive smoke test in `prompts/smoke-test.md` for complete workflow testing. This test should be run from the `prompts/nginx-example` directory and requires kubectl and helmfile to be properly configured.

## Contributing

**IMPORTANT: Never push directly to main branch. Always use feature branches.**

### Git Workflow

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make changes and test thoroughly
4. Run linting and tests:
   ```bash
   task lint
   task build
   task test
   ```
5. Commit with descriptive messages (must be in English)
6. Push to your fork: `git push -u origin feature/my-feature`
7. Create a pull request

### Code Style Guidelines

- Follow shellcheck recommendations
- Use proper error handling with `set -euo pipefail`
- Include debug logging capabilities
- All commit messages and code comments must be written in English
- Follow the argument parsing pattern from navarch

### Adding New Features

- For new builtins: Create files in `src/builtins/` following the builtin template structure
- For core functionality: Add functions to appropriate core module in `src/core/`
- Always add tests and update help text if needed
- Run full test suite before submitting PR

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

- Create an issue for bug reports or feature requests
- Check existing issues and discussions
- Review the documentation and examples