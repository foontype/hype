# GitHub Release System

GitHub Actionsを使用した自動化されたリリースシステムの実装パターンです。このシステムでは、タグのプッシュによってリリースが自動的にトリガーされ、事前定義されたリリースノートからGitHubリリースが作成されます。

## Overview

このリリースシステムは3つの主要コンポーネントで構成されています：

1. **GitHub Actions Workflow** (`.github/workflows/release.yml`) - リリース自動化
2. **Release Notes File** (`release-notes.yaml`) - バージョン別リリースノート
3. **Validation Script** (`.github/scripts/validate-release-notes.sh`) - リリースノート検証

## Files to Copy

### 1. GitHub Workflow (`.github/workflows/release.yml`)

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      
    - name: Install dependencies
      run: |
        sudo apt-get update
        sudo apt-get install -y shellcheck
        
        # Install go-task
        sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin
        echo "$HOME/.local/bin" >> $GITHUB_PATH
        
    - name: Build and test
      run: |
        # Build the project
        task build
        
        # Run linting
        task lint
        
        # Test commands
        ./build/hype --help
        ./build/hype --version
        
    - name: Install yq
      run: |
        sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
        sudo chmod +x /usr/local/bin/yq
        
    - name: Validate release notes
      run: |
        # Extract version from tag 
        VERSION=${GITHUB_REF#refs/tags/}
        echo "Validating release notes for version: $VERSION"
        
        # Run validation script
        ./.github/scripts/validate-release-notes.sh "$VERSION"
        
    - name: Get release notes
      id: get_release_notes
      run: |
        # Extract version from tag
        VERSION=${GITHUB_REF#refs/tags/}
        echo "version=$VERSION" >> $GITHUB_OUTPUT
        
        # Get release notes from YAML (validation already passed)
        yq eval ".\"$VERSION\"" release-notes.yaml > release_notes.md
        
        # Set release name
        echo "release_name=Release $VERSION" >> $GITHUB_OUTPUT
        
    - name: Create Release
      id: create_release
      uses: actions/create-release@v1
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        tag_name: ${{ github.ref }}
        release_name: ${{ steps.get_release_notes.outputs.release_name }}
        body_path: ./release_notes.md
        draft: false
        prerelease: false
        
    - name: Upload hype binary
      uses: actions/upload-release-asset@v1
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        upload_url: ${{ steps.create_release.outputs.upload_url }}
        asset_path: ./build/hype
        asset_name: hype
        asset_content_type: application/octet-stream
```

### 2. Release Notes Template (`release-notes.yaml`)

```yaml
"v1.0.0": |
  ## What's New in v1.0.0

  ### New Features
  - Added new feature X
  - Implemented functionality Y
  - Enhanced user experience with Z

  ### Improvements
  - Improved performance of component A
  - Better error handling in module B
  - Enhanced logging capabilities

  ### Bug Fixes
  - Fixed issue with authentication
  - Resolved parsing error in configuration
  - Corrected display problems in UI

  ### Technical Changes
  - Version bump to 1.0.0
  - Updated dependencies
  - Improved code structure

  ### Dependencies
  - Dependency A v2.0+
  - Dependency B v1.5+
  - Optional: Dependency C for advanced features

"v0.9.0": |
  ## What's New in v0.9.0
  
  ### Previous release notes here
  - Feature from previous version
  - Bug fixes from previous version
```

### 3. Validation Script (`.github/scripts/validate-release-notes.sh`)

```bash
#!/bin/bash

# validate-release-notes.sh
# Script to validate that release notes exist for a given version

set -euo pipefail

# Function to display usage
usage() {
    echo "Usage: $0 <version>"
    echo "Example: $0 v1.0.0"
    exit 1
}

# Check arguments
if [ $# -ne 1 ]; then
    echo "Error: Version argument required"
    usage
fi

VERSION="$1"
RELEASE_NOTES_FILE="release-notes.yaml"

# Check if release notes file exists
if [ ! -f "$RELEASE_NOTES_FILE" ]; then
    echo "Error: Release notes file '$RELEASE_NOTES_FILE' not found"
    exit 1
fi

# Check if yq is available
if ! command -v yq &> /dev/null; then
    echo "Error: yq command not found. Please install yq first."
    echo "Install with: sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq"
    exit 1
fi

echo "Validating release notes for version: $VERSION"

# Check if version exists in release notes
if yq eval ".\"$VERSION\"" "$RELEASE_NOTES_FILE" | grep -q "null"; then
    echo "Error: No release notes found for version '$VERSION' in $RELEASE_NOTES_FILE"
    echo ""
    echo "Available versions in release notes:"
    yq eval 'keys' "$RELEASE_NOTES_FILE" | sed 's/^/  /'
    echo ""
    echo "Please add release notes for version '$VERSION' to $RELEASE_NOTES_FILE"
    echo "Example format:"
    echo "\"$VERSION\": |"
    echo "  ## What's New in $VERSION"
    echo "  - Feature 1"
    echo "  - Bug fix 2"
    exit 1
fi

# Check if release notes are not empty
NOTES_CONTENT=$(yq eval ".\"$VERSION\"" "$RELEASE_NOTES_FILE")
if [ -z "$NOTES_CONTENT" ] || [ "$NOTES_CONTENT" = "null" ] || [ "$NOTES_CONTENT" = "" ]; then
    echo "Error: Release notes for version '$VERSION' are empty"
    exit 1
fi

echo "✅ Release notes validation passed for version: $VERSION"
echo "Release notes preview:"
echo "----------------------------------------"
echo "$NOTES_CONTENT"
echo "----------------------------------------"
```

## How It Works

### Workflow Process

1. **Trigger**: タグ（`v*` pattern）がpushされると自動実行
2. **Build & Test**: プロジェクトのビルドとテストを実行
3. **Validation**: リリースノートの存在と形式を検証
4. **Release Creation**: GitHubリリースを作成し、アセットをアップロード

### Release Notes Format

- YAML形式でバージョン別にリリースノートを管理
- Markdown形式の詳細なリリース内容を記述
- セマンティックバージョニング（`v1.0.0`形式）をサポート

### Validation System

- リリース作成前にリリースノートの存在を検証
- 空のリリースノートや形式エラーを防止
- 利用可能なバージョン一覧を表示してデバッグを支援

## Setup Instructions

### 1. File Structure Creation

```bash
# Create necessary directories
mkdir -p .github/workflows
mkdir -p .github/scripts

# Copy workflow file
cp /path/to/source/.github/workflows/release.yml .github/workflows/

# Copy and make validation script executable
cp /path/to/source/.github/scripts/validate-release-notes.sh .github/scripts/
chmod +x .github/scripts/validate-release-notes.sh

# Copy release notes template
cp /path/to/source/release-notes.yaml .
```

### 2. Customize for Your Project

#### Workflow Customization (`.github/workflows/release.yml`)

```yaml
# Update build steps for your project
- name: Build and test
  run: |
    # Replace with your project's build commands
    npm install    # for Node.js projects
    npm run build  # or your build command
    npm test       # or your test command
    
    # Test your executable/application
    ./dist/your-app --version  # Replace with your app path
```

#### Asset Upload Customization

```yaml
# Update asset upload for your project
- name: Upload release asset
  uses: actions/upload-release-asset@v1
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  with:
    upload_url: ${{ steps.create_release.outputs.upload_url }}
    asset_path: ./dist/your-app          # Update path
    asset_name: your-app                 # Update name
    asset_content_type: application/octet-stream
```

### 3. Release Notes Setup

#### Initial Release Notes (`release-notes.yaml`)

```yaml
"v1.0.0": |
  ## What's New in YourProject v1.0.0

  ### New Features
  - Initial release of YourProject
  - Core functionality implemented
  - Basic CLI interface available

  ### Dependencies
  - Node.js 16+ (or your project's dependencies)
  - Other required dependencies

  ### Installation
  ```bash
  # Installation instructions
  curl -sSL https://github.com/yourusername/yourproject/releases/latest/download/yourproject | sudo tee /usr/local/bin/yourproject > /dev/null
  sudo chmod +x /usr/local/bin/yourproject
  ```
```

### 4. Version Management in Code

プロジェクトのバージョン管理ファイルも更新してください：

```bash
# Example for different project types:

# Node.js (package.json)
jq '.version = "1.0.0"' package.json > tmp.json && mv tmp.json package.json

# Bash script (config file)
echo 'VERSION="1.0.0"' > src/config.sh

# Python (setup.py or __version__.py)
echo '__version__ = "1.0.0"' > src/__version__.py

# Go (version.go)
echo 'const Version = "1.0.0"' > version.go
```

## Release Process

### 1. Version Update

```bash
# 1. Update version in your project code
vim src/config.sh  # or your version file
# Change: VERSION="1.0.0"

# 2. Update release notes
vim release-notes.yaml
# Add new version entry at the top
```

### 2. Create Release

```bash
# 3. Commit changes
git add .
git commit -m "Version 1.0.0 - Feature improvements and bug fixes"

# 4. Create and push tag
git tag v1.0.0
git push origin v1.0.0
```

### 3. Monitor Release

```bash
# Check GitHub Actions
# Go to: https://github.com/yourusername/yourrepo/actions

# Verify release creation
# Go to: https://github.com/yourusername/yourrepo/releases
```

## Best Practices

### Release Notes Writing

1. **Consistent Format**: 統一されたフォーマットを使用
2. **User-Focused**: ユーザーへの影響を中心に記述
3. **Categorization**: 機能、改善、バグ修正で分類
4. **Dependencies**: 必要な依存関係を明記

### Version Management

1. **Semantic Versioning**: `v1.2.3` 形式を使用
2. **Code Sync**: コードのバージョンとタグを同期
3. **Testing**: リリース前に必ずテストを実行

### Security Considerations

1. **GITHUB_TOKEN**: 自動的に提供される、追加設定不要
2. **Asset Security**: アップロードするアセットの検証
3. **Branch Protection**: main/master ブランチの保護設定

## Troubleshooting

### Common Issues

1. **Missing Release Notes**
   ```bash
   Error: No release notes found for version 'v1.0.0'
   # Solution: Add version entry to release-notes.yaml
   ```

2. **Build Failures**
   ```bash
   # Check GitHub Actions logs
   # Update build commands in workflow
   ```

3. **Asset Upload Failures**
   ```bash
   # Verify asset path exists
   # Check file permissions
   # Ensure build step completed successfully
   ```

### Testing Validation Script

```bash
# Test validation script locally
chmod +x .github/scripts/validate-release-notes.sh
./.github/scripts/validate-release-notes.sh v1.0.0
```

This release system provides a robust, automated workflow for managing project releases with proper documentation and validation.