# HYPE CLI Tool

A simple command-line tool that says hello to the world!

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

## Usage

```bash
# Default hello world
hype

# Say hello
hype hello

# Say hello world
hype world

# Show version
hype --version

# Show help
hype --help
```

## Development

### Prerequisites

- Bash 4.0+
- Git

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
   ./src/hype
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
./src/hype
./src/hype hello
./src/hype --version
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