# Pull Requests and Issues Workflow Guide

This document provides detailed guidance for GitHub workflows in project.

## Language Convention
**All commit messages and code comments must be written in English.**

## Creating Pull Requests
**IMPORTANT: Never push directly to main branch. Always use feature branches.**

**NOTE: Use GitHub MCP server tools for all GitHub operations. The `gh` command is not installed and not available.**

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