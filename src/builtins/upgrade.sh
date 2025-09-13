#!/bin/bash

# HYPE CLI Upgrade Plugin
# Handles self-upgrade functionality

# Builtin metadata (standardized)
BUILTIN_NAME="upgrade"
BUILTIN_VERSION="1.0.0"
BUILTIN_DESCRIPTION="Self-upgrade functionality builtin"

# Register commands in global BUILTIN_COMMANDS array
BUILTIN_COMMANDS+=("upgrade")

# Help functions
help_upgrade() {
    cat <<EOF
Usage: hype upgrade

Upgrade HYPE CLI to latest version

This command downloads and installs the latest version of HYPE CLI
from the official GitHub repository.

Examples:
  hype upgrade                    Upgrade to latest version
EOF
}

help_upgrade_brief() {
    echo "Upgrade HYPE CLI to latest version"
}

# Self-upgrade command
cmd_upgrade() {
    info "Checking for HYPE CLI updates..."
    
    # Check if curl or wget is available
    local download_tool=""
    if command -v curl >/dev/null 2>&1; then
        download_tool="curl"
    elif command -v wget >/dev/null 2>&1; then
        download_tool="wget"
    else
        die "Neither curl nor wget found. Please install one of them to use upgrade functionality."
    fi
    
    # Get latest release information from GitHub API
    local repo_owner="${HYPE_REPO_OWNER:-foontype}"
    local repo_name="${HYPE_REPO_NAME:-hype}"
    local api_url="https://api.github.com/repos/${repo_owner}/${repo_name}/releases/latest"
    local release_info
    
    if [[ "$download_tool" == "curl" ]]; then
        if ! release_info=$(curl -s "$api_url"); then
            die "Failed to fetch release information from GitHub API"
        fi
    else
        if ! release_info=$(wget -qO- "$api_url"); then
            die "Failed to fetch release information from GitHub API"
        fi
    fi
    
    # Extract latest version and download URL
    local latest_version download_url
    if ! command -v jq >/dev/null 2>&1; then
        # Fallback parsing without jq (basic regex)
        latest_version=$(echo "$release_info" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
        download_url=$(echo "$release_info" | grep '"browser_download_url".*hype"' | head -1 | sed 's/.*"browser_download_url": *"\([^"]*\)".*/\1/')
    else
        latest_version=$(echo "$release_info" | jq -r '.tag_name')
        download_url=$(echo "$release_info" | jq -r '.assets[] | select(.name == "hype") | .browser_download_url')
    fi
    
    if [[ -z "$latest_version" || -z "$download_url" ]]; then
        die "Failed to extract version or download URL from GitHub API response"
    fi
    
    # Remove 'v' prefix from version for comparison
    latest_version_clean="${latest_version#v}"
    
    debug "Current version: $HYPE_VERSION"
    debug "Latest version: $latest_version_clean"
    debug "Download URL: $download_url"
    
    # Compare versions
    if [[ "$HYPE_VERSION" == "$latest_version_clean" ]]; then
        info "HYPE CLI is already up to date (version $HYPE_VERSION)"
        return 0
    fi
    
    info "New version available: $latest_version_clean (current: $HYPE_VERSION)"
    info "Downloading update from: $download_url"
    
    # Determine the path of the current script
    local script_path
    script_path=$(readlink -f "${BASH_SOURCE[0]}")
    local backup_path="${script_path}.backup"
    
    debug "Script path: $script_path"
    debug "Backup path: $backup_path"
    
    # Create backup of current version
    if ! cp "$script_path" "$backup_path"; then
        die "Failed to create backup of current version"
    fi
    
    info "Created backup: $backup_path"
    
    # Download new version to temporary file
    local temp_file
    temp_file=$(mktemp)
    
    if [[ "$download_tool" == "curl" ]]; then
        if ! curl -L -o "$temp_file" "$download_url"; then
            rm -f "$temp_file"
            die "Failed to download new version"
        fi
    else
        if ! wget -O "$temp_file" "$download_url"; then
            rm -f "$temp_file"
            die "Failed to download new version"
        fi
    fi
    
    # Verify download (basic check - file should not be empty and should be executable script)
    if [[ ! -s "$temp_file" ]]; then
        rm -f "$temp_file"
        die "Downloaded file is empty"
    fi
    
    # Check if it's a bash script
    if ! head -1 "$temp_file" | grep -q "#!/bin/bash"; then
        rm -f "$temp_file"
        die "Downloaded file does not appear to be a valid bash script"
    fi
    
    # Replace current script with new version
    if ! cp "$temp_file" "$script_path"; then
        # Restore from backup if replacement fails
        cp "$backup_path" "$script_path"
        rm -f "$temp_file"
        die "Failed to replace script. Restored from backup."
    fi
    
    # Set executable permissions
    if ! chmod +x "$script_path"; then
        # Restore from backup if chmod fails
        cp "$backup_path" "$script_path"
        rm -f "$temp_file"
        die "Failed to set executable permissions. Restored from backup."
    fi
    
    # Clean up
    rm -f "$temp_file"
    
    info "Successfully updated HYPE CLI to version $latest_version_clean"
    info "Backup of previous version saved as: $backup_path"
    info "Run 'hype --version' to verify the update"
}