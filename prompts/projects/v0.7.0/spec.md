# HYPE v0.7.0 Specification

## Overview

HYPE v0.7.0 introduces repository binding functionality, allowing hype configurations to be linked with Git repositories. This enables direct usage of hypefile configurations stored in remote repositories.

## New Feature: Repository Binding

### Core Concept

Repository binding allows associating a hype name with a Git repository, enabling automatic checkout and execution of hype operations within the context of that repository.

## Command Specifications

### `hype <hype-name>`

**Purpose**: Display information associated with a hype name

**Behavior**:
- **When unspecified**: Display the description from local hypefile
- **When bound to repository**: Display the description from the bound repository's hypefile  
- **When not bound**: Display message indicating no binding exists

### `hype <hype-name> repo bind <repository-url> [--branch <branch-name>] [--path <path>]`

**Purpose**: Bind a hype name to a Git repository

**Parameters**:
- `<repository-url>`: URL of the repository to bind
- `--branch <branch-name>` (optional): Branch name to use
- `--path <path>` (optional): Specific path within the repository

**Operations**:
1. Store hype name, repository URL, branch name, and path in ConfigMap `hype-repos`
2. Enable automatic repository checkout for subsequent hype operations
3. Clone/checkout to `$HYPE_CACHE_DIR/repo/<hype-name>`
4. Execute `git submodule update --init`
5. Change directory to specified path if provided

### `hype <hype-name> repo unbind`

**Purpose**: Remove repository binding for a hype name

**Operations**:
- Remove corresponding entry from ConfigMap `hype-repos`

### `hype <hype-name> repo update`

**Purpose**: Update cache for bound repository

**Operations**:
1. Delete existing cache directory
2. Re-checkout the repository
3. Update submodules

### `hype <hype-name> repo`

**Purpose**: Display binding information

**Behavior**:
- **When bound**: Display bound URL, branch, and path information
- **When not bound**: Display message indicating no binding exists

## Implementation Details

### Data Storage

**ConfigMap**: `hype-repos`
**Data Structure**: 
```json
{
  "<hype-name>": {
    "url": "<repository-url>",
    "branch": "<branch-name>",
    "path": "<path>"
  }
}
```

### Cache Management

**Cache Directory**: `$HYPE_CACHE_DIR/repo/<hype-name>`

**Git Operations**:
- **Initial setup**: `git clone <repository-url> --branch <branch-name>`
- **Updates**: Delete cache directory and re-clone, or `git pull`
- **Submodules**: `git submodule update --init`

### Execution Context Changes

For operations on bound hypes:
1. Retrieve binding information from ConfigMap
2. Verify cache directory exists
3. Clone/update repository if necessary
4. Change working directory to repository (and path if specified)
5. Execute hype command within repository context

### Fallback Behavior

- **Unbound hypes**: Use current directory (existing behavior)
- **Missing cache**: Automatically clone repository
- **Git failures**: Fall back to current directory with warning

## Backward Compatibility

- Existing local hypefile usage remains unchanged
- Unbound hypes continue to operate from current directory
- All existing commands and functionality preserved

## Configuration

### Environment Variables

- `$HYPE_CACHE_DIR`: Base directory for repository caches (default: `~/.hype/cache`)

### Kubernetes Resources

- ConfigMap `hype-repos`: Stores binding information
- Namespace: Same as hype installation namespace

## Error Handling

- **Invalid repository URL**: Display error and exit
- **Git clone failures**: Display error and fall back to current directory
- **Missing branch**: Display error and use default branch
- **Permission issues**: Display clear error message with resolution steps

## Security Considerations

- Repository URLs should be validated
- Private repositories require appropriate authentication
- Cache directories should have appropriate permissions
- ConfigMap access should be restricted to hype service account