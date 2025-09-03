# GitHub Workflow Guide

This document provides detailed guidance for GitHub workflows in the HYPE CLI project.

## Language Convention
**All commit messages and code comments must be written in English.**

## Creating Pull Requests
**IMPORTANT: Never push directly to main branch. Always use feature branches.**

1. Check existing PRs:
   ```
   mcp__github__list_pull_requests
   ```

2. Create new branch (naming: `feature/<description>`):
   ```bash
   git checkout -b feature/<feature-name>
   ```

3. Format code before push:
   ```bash
   task lint
   # Fix any shellcheck issues before committing
   ```

4. Push branch:
   ```bash
   git push -u origin feature/<feature-name>
   ```

5. Create PR using GitHub MCP:
   ```
   mcp__github__create_pull_request
   ```

## Creating Issues
Use GitHub MCP tools to create issues:
```
mcp__github__create_issue
```

Include:
- Clear description of the problem or feature request
- Steps to reproduce (for bugs)
- Expected vs actual behavior
- Environment details if relevant

## Creating Releases

### Version Update Process
1. **Update version in `src/core/config.sh` script**:
   - Locate `HYPE_VERSION="x.x.x"` line in `src/core/config.sh`
   - Update to new version number (e.g., `HYPE_VERSION="0.6.0"`)

2. **Create/Update release notes in `release-notes.yaml`**:
   - Add new version key (e.g., `v0.5.0:`)
   - Generate release notes from recent git log:
     ```bash
     git log --oneline --since="last release date" --format="- %s"
     ```
   - Add generated notes under the version key in YAML format

3. **Create pull request for version update**:
   - Create feature branch for version update (e.g., `feature/version-0.5.0`)
   - Commit version and release notes changes
   - Create PR using GitHub MCP:
     ```
     mcp__github__create_pull_request
     ```
   - Wait for user to review and merge the PR

4. **Create and push tag** (only after PR is merged):
   ```bash
   git tag v0.5.0
   git push origin v0.5.0
   ```

5. **GitHub Actions automatically creates release** via `.github/workflows/release.yml`

### Example release-notes.yaml structure:
```yaml
v0.5.0:
  - Add new feature X
  - Fix bug in command Y  
  - Improve error handling
  - Update documentation
v0.4.0:
  - Previous release notes
```