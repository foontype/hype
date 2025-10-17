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

### 5. Implementation Remake
When requested to remake implementation from scratch:

#### Prerequisites
- Check for existence of `prompts/initial-files.md`
- If this file does not exist, notify the user to create it and halt execution

#### Process
1. **Read initial file list**: Load `prompts/initial-files.md` to get the list of files to keep
   - Example format:
     ```
     prompts/
     README.md
     CLAUDE.md
     ```

2. **Clean project**: Remove all files from the project except those listed in `initial-files.md`

3. **Update implementation plan**:
   - Use `prompts/<current version>/spec.md` as source
   - Update `prompts/<current version>/plan.md` based on the specifications

4. **Create implementation**:
   - Use `prompts/<current version>/plan.md` as source
   - Create the implementation according to the plan

## File Structure

```
prompts/
└── projects/
    ├── current-version.md
    ├── initial-files.md
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

If `prompts/initial-files.md` does not exist during implementation remake:
1. Notify the user that the initial files list is missing
2. Provide example format for the file
3. Stop execution until the file is created

## Creating initial-files.md

When creating `prompts/initial-files.md`, follow these steps:

1. **List current directory contents**: Generate a list of all files and directories in the project's top-level directory

2. **Create the initial-files.md**: Record the essential files and directories that should be preserved during implementation restart in `prompts/initial-files.md`

3. **Example content for current project**:
   ```
   CLAUDE.md
   README.md
   prompts/
   ```

4. **Format guidelines**:
   - List one file or directory per line
   - Use relative paths from the project root
   - Include trailing slash for directories if desired (optional)
   - Only include essential files needed for the project structure