# Pull Requests Branch Switching Guide

## Overview
This guide explains how to handle requests to switch to pull request branches for work tasks.

## Common Request Patterns
Users may request to switch to pull request branches using various phrasings:
- "プルリクエスト123に切り替え" (Switch to pull request 123)
- "プルリクエスト234のブランチに切り替え" (Switch to pull request 234's branch)
- "プルリクエスト345で作業" (Work on pull request 345)
- "pr456で作業" (Work on pr456)

## Required Actions
When you receive such instructions:

1. **Identify the pull request number** from the user's request
2. **Fetch pull request details** using the GitHub MCP tools:
   ```
   mcp__github__get_pull_request
   ```
3. **Extract the source branch** from the pull request data (the `head.ref` field)
4. **Switch to the branch** using git checkout:
   ```bash
   git checkout <branch-name>
   ```

## Important Notes
- These instructions are typically given before starting work tasks
- Always confirm the branch switch was successful
- The source branch is found in the pull request's `head.ref` field, not the `base.ref`
- If the branch doesn't exist locally, git will automatically set up tracking from origin

## Example Workflow
```
User: "プルリクエスト128に切り替え"
1. Call mcp__github__get_pull_request with pullNumber: 128
2. Extract head.ref value (e.g., "test/pr125-verification")
3. Execute: git checkout test/pr125-verification
4. Confirm successful branch switch
```