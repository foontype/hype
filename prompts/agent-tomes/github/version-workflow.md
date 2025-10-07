# Version Workflow Guide

## Overview
This guide explains the version-based branch workflow for pull request creation.

## Pull Request Creation with Version Branches

When requested to create a pull request, follow this workflow:

### 1. Version Verification
Before creating any pull request:
- Check for the existence of `prompts/version.md`
- If the file does not exist, inform the user and stop the operation
- Extract the current version number from the file content

### 2. Version Branch Creation
Create a version branch from main branch before pull request creation:

```bash
# Format: version/v{major}.{minor}.{patch}
# Example: If version is 0.8.1, branch name is version/v0.8.1
git checkout main
git checkout -b version/v{VERSION}
git push -u origin version/v{VERSION}
```

**Branch Naming Convention:**
- Format: `version/v{VERSION}`
- Example: `version/v0.8.1` for version 0.8.1
- If the version branch already exists, skip creation

### 3. Pull Request Base Branch
When creating pull requests:
- Set the base branch to the version branch (not main)
- Use GitHub MCP tools with the base parameter set to the version branch

```
mcp__github__create_pull_request
base: version/v{VERSION}
head: {feature-branch}
```

## Implementation Steps

1. **Version Check**
   ```bash
   # Verify prompts/version.md exists
   if [ ! -f "prompts/version.md" ]; then
       echo "Error: prompts/version.md not found. Operation stopped."
       exit 1
   fi

   # Extract version number
   VERSION=$(cat prompts/version.md | grep -E "v?[0-9]+\.[0-9]+\.[0-9]+" | head -1)
   ```

2. **Version Branch Management**
   ```bash
   BRANCH_NAME="version/v${VERSION}"

   # Check if branch exists
   if ! git show-branch origin/"${BRANCH_NAME}" &>/dev/null; then
       # Create version branch
       git checkout main
       git checkout -b "${BRANCH_NAME}"
       git push -u origin "${BRANCH_NAME}"
   fi
   ```

3. **Pull Request Creation**
   ```
   # Use version branch as base
   mcp__github__create_pull_request:
     base: version/v{VERSION}
     head: {feature-branch}
     title: {PR title}
     body: {PR description}
   ```

## Important Notes

- **Always check prompts/version.md first** - If missing, inform user and stop
- **Version branch creation is mandatory** before PR creation
- **Base branch must be version branch** not main
- **Skip branch creation if it already exists**
- Version branches serve as staging areas for release preparation

## Error Handling

### Missing Version File
```
Error: prompts/version.md file not found.
Please create the version file with the current version number before proceeding.
Operation stopped.
```

### Invalid Version Format
```
Error: Invalid version format in prompts/version.md.
Expected format: v{major}.{minor}.{patch} (e.g., v0.8.1)
Operation stopped.
```

### Branch Creation Failure
```
Error: Failed to create version branch version/v{VERSION}.
Please check git repository status and permissions.
```