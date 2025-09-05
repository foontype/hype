# HYPE CLI v0.7.0 Specification: Repository Management

## Overview

HYPE CLI v0.7.0 introduces repository management functionality that allows users to bind specific hype environments to Git repositories and manage them in isolated working areas. This feature enables efficient context switching between multiple projects and automated repository synchronization.

## Implementation

- Language: Bash
- New core module: `src/core/repository.sh`
- Configuration: Kubernetes ConfigMap for repository bindings
- Working directory: Temporary isolated areas for each repository

## Repository Management Architecture

### Configuration Storage

Repository bindings are stored in a Kubernetes ConfigMap with the following structure:
- ConfigMap name: `hype-repository-config`
- Namespace: Current kubectl context namespace
- Data format: Key-value pairs where key is hype name and value is repository URL

### Working Directory Structure

```
/tmp/hype-repos/
├── <hype-name-1>/
│   └── <repository-clone>/
│       ├── main/          # main branch working directory
│       │   └── <path>/    # optional subdirectory path (if specified)
│       ├── develop/       # develop branch working directory
│       │   └── <path>/    # optional subdirectory path (if specified)
│       └── feature-xyz/   # feature branch working directory
│           └── <path>/    # optional subdirectory path (if specified)
├── <hype-name-2>/
│   └── <repository-clone>/
│       ├── main/
│       │   └── services/webapp/  # example: specific service path
│       └── staging/
│           └── configs/k8s/      # example: configuration path
└── ...
```

## Command Interface

### Repository Binding Commands

#### `use repo`
```
hype <hype name> use repo <repository> [--branch <branch>] [--path <path>]
```
- Binds a repository to the specified hype name
- Updates the ConfigMap with the binding information
- Clones the repository to `/tmp/hype-repos/<hype-name>/<repository-name>/`
- Creates branch-specific working directory
- Switches to specified branch (defaults to repository's default branch)
- Optionally sets working subdirectory within repository

**Parameters:**
- `<hype name>`: Environment identifier
- `<repository>`: Git repository URL (supports HTTPS, SSH, local paths)
- `--branch <branch>`: Optional branch to checkout (defaults to main/master)
- `--path <path>`: Optional subdirectory path within repository (defaults to repository root)

**Behavior:**
- If binding already exists, updates to new repository, branch, and/or path
- Creates separate working directory for each branch
- If repository already cloned for the branch, performs git pull
- If new branch specified, creates new working directory and checks out branch
- If path specified, validates subdirectory exists after clone/pull
- Validates repository accessibility before binding
- Path is relative to repository root and must exist in the specified branch

#### `unuse`
```
hype <hype name> unuse
```
- Removes repository binding for the specified hype name
- Updates ConfigMap to remove the entry
- Optionally removes local working directory

**Parameters:**
- `<hype name>`: Environment identifier to unbind

**Behavior:**
- Prompts for confirmation before removing working directory
- Preserves local changes by default (user confirmation required)

### Repository Management Commands

#### `update`
```
hype update
```
- Updates all bound repositories
- Performs git pull on each cloned repository
- Clones repositories that are bound but not yet cloned
- Reports update status for each repository

**Behavior:**
- Processes all entries from the ConfigMap
- Handles git conflicts gracefully
- Provides detailed status output
- Continues processing even if individual repositories fail

#### `list`
```
hype list
```
- Lists all hype names and their repository bindings
- Shows working directory status for each binding

**Output format:**
```
HYPE NAME          REPOSITORY                     STATUS
my-app             git@github.com:user/app.git    cloned
staging-env        https://github.com/user/web    not-cloned
local-dev          .                              current-dir
```

**Status indicators:**
- `cloned`: Repository is bound and cloned in working directory
- `not-cloned`: Repository is bound but not yet cloned
- `current-dir`: No repository bound (uses current directory)

## Command Execution Behavior

### Repository-aware Command Execution

When executing hype commands:

1. **Check for repository binding:**
   - Look up hype name in ConfigMap
   - If bound: change to repository working directory
   - If not bound: use current directory

2. **Working directory resolution:**
   ```
   if repository bound:
       if path specified:
           cd /tmp/hype-repos/<hype-name>/<repo-name>/<branch>/<path>/
       else:
           cd /tmp/hype-repos/<hype-name>/<repo-name>/<branch>/
   else:
       use current directory
   ```

3. **Execute command:**
   - Run the requested hype subcommand
   - All file operations occur in the resolved directory

### Existing Command Integration

All existing hype commands (`init`, `deinit`, `check`, `helmfile`, etc.) automatically benefit from repository management without modification.

## Configuration Management

### ConfigMap Structure

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: hype-repository-config
  namespace: <current-namespace>
data:
  my-app: '{"repository": "git@github.com:user/my-app.git", "branch": "main", "path": ""}'
  staging: '{"repository": "https://github.com/user/staging-repo", "branch": "develop", "path": "services/webapp"}'
  feature-env: '{"repository": "git@github.com:user/my-app.git", "branch": "feature-xyz", "path": "configs/k8s"}'
  local-dev: ""  # Empty string indicates no binding
```

### Configuration Operations

- **Read**: `kubectl get configmap hype-repository-config -o json`
- **Update**: `kubectl patch configmap hype-repository-config --patch`
- **Create**: Automatically created on first `use repo` command

## Error Handling

### Repository Operations
- Invalid repository URLs
- Git authentication failures
- Network connectivity issues
- Insufficient disk space
- Git conflicts during updates
- Specified path does not exist in repository
- Path permission issues

### ConfigMap Operations
- Kubernetes cluster connectivity
- Insufficient permissions
- ConfigMap corruption
- Namespace access issues

### Error Exit Codes
- `10`: Repository not accessible
- `11`: Git operation failed
- `12`: ConfigMap operation failed
- `13`: Working directory creation failed
- `14`: Kubernetes cluster not accessible
- `15`: Specified path does not exist in repository

## Security Considerations

### Repository Access
- Support both SSH and HTTPS authentication
- Respect existing Git credentials and SSH keys
- No credential storage in ConfigMap
- User responsible for repository access permissions

### File System Security
- Working directories created with appropriate permissions
- Temporary directories cleaned up on system reboot
- No sensitive data persisted in temporary areas

## Migration and Compatibility

### Backward Compatibility
- All existing commands work without modification
- No breaking changes to command interface
- Existing hypefile.yaml files remain valid

### Migration Path
- New functionality is opt-in
- Users can gradually adopt repository management
- Existing workflows continue to work in current directory

## Dependencies

### Required
- Bash 4.0+
- kubectl (for ConfigMap operations)
- git (for repository operations)
- Kubernetes cluster access

### Optional
- SSH key setup (for SSH repository access)
- Git credential helper (for HTTPS repositories)

## Usage Examples

### Basic Repository Management
```bash
# Bind a repository to hype environment
hype my-app use repo git@github.com:user/my-app.git

# Bind a repository with specific path
hype webapp use repo git@github.com:user/monorepo.git --path services/webapp

# List all bindings
hype list

# Work with the bound repository
hype my-app init
hype my-app helmfile apply

# Work with specific path in repository
hype webapp init  # Works in services/webapp subdirectory

# Update all repositories
hype update

# Remove binding
hype my-app unuse
```

### Multi-environment Workflow
```bash
# Set up multiple environments with specific branches and paths
hype prod use repo git@github.com:company/prod-config.git --branch main --path k8s/prod
hype staging use repo git@github.com:company/prod-config.git --branch develop --path k8s/staging
hype dev use repo git@github.com:company/prod-config.git --branch feature-new-feature --path k8s/dev

# Or use different repositories for different environments
hype prod use repo git@github.com:company/prod-config.git --path environments/production
hype staging use repo git@github.com:company/staging-config.git --path k8s
hype dev use repo git@github.com:company/dev-config.git

# Switch between environments seamlessly
hype prod helmfile apply       # Uses main branch
hype staging helmfile sync     # Uses develop branch
hype dev init                  # Uses feature branch

# Keep all environments up to date
hype update
```

### Local Development
```bash
# Some environments use repositories, others use current directory
hype remote-env use repo git@github.com:user/remote.git
hype local-env init  # Uses current directory

hype list
# Output:
# HYPE NAME     REPOSITORY                        STATUS
# remote-env    git@github.com:user/remote.git    cloned
# local-env     .                                 current-dir
```