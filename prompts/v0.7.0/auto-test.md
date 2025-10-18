# HYPE v0.7.0 Repository Binding - Testing Guide

This document provides testing instructions for the new repository binding feature in HYPE v0.7.0.

## New Feature Overview

HYPE v0.7.0 introduces repository binding functionality that allows hype configurations to be linked with Git repositories, enabling direct usage of hypefile configurations stored in remote repositories.

## Prerequisites

- `git` command available
- `kubectl` available for ConfigMap operations (optional, commands will warn if not available)
- Built HYPE CLI v0.7.0

## Testing Commands

### 1. Version Check
```bash
./build/hype --version
# Expected output: HYPE CLI version 0.7.0
```

### 2. Repository Commands Help
```bash
./build/hype test-app repo --help
# Should display help for repository binding commands
```

### 3. Check Repository Binding Status (No Binding)
```bash
./build/hype test-app repo
# Expected output: No repository binding found
```

### 4. Test Repository Binding (Simulation)

**Note**: The following commands require `kubectl` access to a Kubernetes cluster. If not available, the commands will fail gracefully with appropriate error messages.

#### Bind a Repository
```bash
./build/hype myapp repo bind https://github.com/foontype/hype.git --branch main --path prompts/nginx-example
```

Expected behavior:
- If kubectl is available: Store binding in ConfigMap and clone repository
- If kubectl is not available: Show error message about kubectl requirement

#### Check Binding Information
```bash
./build/hype myapp repo
```

#### Update Repository Cache
```bash
./build/hype myapp repo update
```

#### Unbind Repository
```bash
./build/hype myapp repo unbind
```

### 5. URL Validation Testing

Test various URL formats:

```bash
# Valid URLs (should work)
./build/hype test1 repo bind https://github.com/user/repo.git
./build/hype test2 repo bind https://github.com/user/repo
./build/hype test3 repo bind git@github.com:user/repo.git

# Invalid URLs (should show error)
./build/hype test4 repo bind invalid-url
./build/hype test5 repo bind https://example.com/not-a-repo
```

### 6. Integration Testing

Test that existing hype commands still work:

```bash
# These should work without repository binding (if hypefile.yaml exists)
./build/hype test-app init
./build/hype test-app template
./build/hype test-app resources check
```

## Expected Behavior

### With kubectl Available
- Repository binding commands should work normally
- ConfigMap `hype-repos` should be created/updated
- Repository should be cloned to `~/.hype/cache/repo/<hype-name>`
- Existing hype commands should automatically use bound repository when available

### Without kubectl Available
- Repository binding commands should show helpful error messages
- Other hype commands should continue to work normally
- The system should gracefully fall back to local hypefile usage

## Testing Scenarios

### Scenario 1: Fresh Installation
1. Build the CLI: `task build`
2. Test version: `./build/hype --version`
3. Test help: `./build/hype test-app repo --help`
4. Test info with no binding: `./build/hype test-app repo`

### Scenario 2: With Kubernetes Access
1. Test binding: `./build/hype myapp repo bind <valid-repo-url>`
2. Test info: `./build/hype myapp repo`
3. Test update: `./build/hype myapp repo update`
4. Test unbind: `./build/hype myapp repo unbind`

### Scenario 3: Without Kubernetes Access
1. Test binding (should fail gracefully): `./build/hype myapp repo bind <repo-url>`
2. Verify appropriate error messages are shown
3. Test that other commands still work

## File Structure Verification

After successful implementation, these files should exist:

```
src/core/
├── cache.sh           # Cache management functions
├── repo.sh            # Repository binding core functions
└── (existing files)

src/plugins/
├── repo.sh            # Repository command plugin
└── (existing files)
```

## Configuration

### Environment Variables
- `HYPE_CACHE_DIR`: Base directory for repository caches (default: `~/.hype/cache`)

### Kubernetes Resources
- ConfigMap `hype-repos`: Stores binding information
- Namespace: Same as hype installation namespace

## Troubleshooting

### Common Issues

1. **kubectl not found**: Repository binding requires kubectl for ConfigMap operations
2. **Git clone failures**: Check repository URL and network connectivity
3. **Permission issues**: Ensure appropriate file system permissions for cache directory

### Debug Mode

Enable debug output for detailed information:
```bash
DEBUG=true ./build/hype myapp repo bind <repo-url>
```

## Cleanup

To clean up test data:
```bash
# Remove ConfigMap (if created)
kubectl delete configmap hype-repos

# Remove cache directory
rm -rf ~/.hype/cache
```