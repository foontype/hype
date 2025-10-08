# HYPE CLI Current Version Guide

## Overview
This document explains how to retrieve the current version of HYPE CLI.

## Version Location

The current version of HYPE CLI is defined in the following file:
- **File**: `src/core/common.sh`
- **Variable**: `HYPE_VERSION`
- **Line**: 7

### Getting the Version

#### From Source Code
The version can be found at `src/core/common.sh:7`:
```bash
HYPE_VERSION="0.8.0"
```

#### From Built Binary
After building the project, you can check the version using:
```bash
./build/hype --version
```

#### During Development
When working with the source code, you can extract the version programmatically:
```bash
grep 'HYPE_VERSION=' src/core/common.sh | cut -d'"' -f2
```

## Version Update Process

When updating the version:
1. Modify the `HYPE_VERSION` variable in `src/core/common.sh`
2. Update `release-notes.yaml` with the new version and changes
3. Create a pull request for the version update
4. After merging, create and push a git tag (e.g., `v0.8.0`)
5. GitHub Actions will automatically create a release

## Related Files
- `src/core/common.sh` - Contains the version definition
- `release-notes.yaml` - Contains release notes for each version
- `CLAUDE.md` - Contains the complete release workflow documentation