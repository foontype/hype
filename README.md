# HYPE CLI Tool

A helmfile wrapper with ConfigMap and Secret management.

HYPE automatically extracts `templates.hype` objects from helmfile template output, creates corresponding ConfigMaps or Secrets based on their type, and injects ConfigMap values back into the helmfile execution.

## Installation

### Quick Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/foontype/hype/main/install.sh | bash
```

### Manual Installation

1. Download the `hype` script:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/foontype/hype/main/src/hype -o hype
   ```

2. Make it executable:
   ```bash
   chmod +x hype
   ```

3. Move to a directory in your PATH:
   ```bash
   sudo mv hype /usr/local/bin/
   # or for user installation:
   # mv hype ~/.local/bin/
   ```

## Prerequisites

- `kubectl` - Kubernetes command-line tool
- `helmfile` - Declarative spec for deploying helm charts
- `yq` - YAML processor

## Usage

### Basic Commands

```bash
# Run helmfile with ConfigMap management
hype helmfile apply

# Generate diff with ConfigMap values
hype helmfile diff

# Template with debug logging
HYPE_DEBUG=true hype helmfile template

# Show version
hype --version

# Show help
hype --help
```

### Template Types

HYPE supports two template types in `templates.hype` annotations:

#### state-value-file (Default)
Creates ConfigMaps and injects their values into helmfile execution:
```yaml
metadata:
  annotations:
    templates.hype: |
      {
        "my-config": {
          "type": "state-value-file",
          "namespace": "default",
          "key1": "value1",
          "key2": "value2"
        }
      }
```

#### secret-defaults
Creates Secrets if they don't exist (no injection):
```yaml
metadata:
  annotations:
    templates.hype: |
      {
        "my-secret": {
          "type": "secret-defaults",
          "namespace": "default",
          "username": "admin",
          "password": "secret123"
        }
      }
```

### Environment Variables

- `HYPE_DEBUG` - Set to `true` to enable debug logging

## How It Works

1. **Template Discovery**: HYPE runs `helmfile template` to discover resources with `templates.hype` annotations
2. **Resource Management**: Creates ConfigMaps or Secrets based on template type if they don't exist
3. **Value Injection**: For `state-value-file` templates, extracts ConfigMap values and injects them into helmfile execution
4. **Execution**: Runs the original helmfile command with injected values

## Development

### Prerequisites

- Bash 4.0+
- Git
- kubectl
- helmfile
- yq

### Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/foontype/hype.git
   cd hype
   ```

2. Open in dev container (if using VS Code):
   ```bash
   code .
   # Then select "Reopen in Container"
   ```

3. Or run locally:
   ```bash
   ./src/hype helmfile --help
   ```

### Testing

Run ShellCheck for linting:
```bash
shellcheck src/hype
shellcheck install.sh
shellcheck .devcontainer/post-create-command.sh
```

Test the CLI:
```bash
./src/hype --version
./src/hype --help
HYPE_DEBUG=true ./src/hype helmfile template
```

## Project Structure

```
hype/
├── .devcontainer/          # Development container configuration
├── .github/workflows/      # GitHub Actions CI/CD
├── src/
│   └── hype               # Main CLI script
├── tests/                 # Test scripts
├── install.sh            # Installation script
├── CLAUDE.md             # Development guide
└── README.md
```

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes
4. Run tests: `shellcheck src/hype`
5. Commit changes: `git commit -am 'Add feature'`
6. Push to branch: `git push origin feature-name`
7. Submit a pull request

## License

MIT License - see LICENSE file for details.