# Current Version Workflow Guide

## Overview

This guide defines the workflow for version-specific development activities including idea documentation, specification creation, implementation planning, and testing.

## Prerequisites

Before performing any version-specific activities, the current version must be identified by referencing `prompts/current-version.md`. If this file does not exist, notify the user and halt execution.

## Workflow Steps

### 1. Idea Documentation
When requested to document ideas:
- Record in `prompts/<current version>/idea.md`
- Example: `prompts/v0.8.0/idea.md`

### 2. Specification Creation
When requested to create specifications:
- Document in `prompts/<current version>/spec.md`

### 3. Implementation Planning
When requested to create implementation plans:
- Use information from `prompts/<current version>/spec.md`
- Record planning details in `prompts/<current version>/plan.md`

### 4. Testing
When requested to execute tests:
- Follow the test procedures defined in `prompts/<current version>/test.md`
- If test creation is requested, document in this same file

## File Structure

```
prompts/
├── current-version.md
└── <version>/
    ├── idea.md
    ├── spec.md
    ├── plan.md
    └── test.md
```

## Error Handling

If `prompts/current-version.md` does not exist:
1. Notify the user that the current version file is missing
2. Stop execution until the file is created or the issue is resolved