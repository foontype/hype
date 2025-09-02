#!/bin/bash

# HYPE CLI Installation Script

set -euo pipefail

# Configuration
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="hype"
REPO_OWNER="${HYPE_REPO_OWNER:-foontype}"
REPO_NAME="${HYPE_REPO_NAME:-hype}"
REPO_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/src/hype"
RELEASE_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Output control based on INSTALL_LOG environment variable
output_log() {
    local message="$1"
    case "${INSTALL_LOG:-stdout}" in
        "false") 
            # Log disabled, do nothing
            ;;
        "stdout") 
            echo -e "$message"
            ;;
        *) 
            # Output to file specified in INSTALL_LOG
            echo -e "$message" >> "$INSTALL_LOG"
            ;;
    esac
}

# Logging functions
log_info() {
    output_log "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    output_log "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    output_log "${RED}[ERROR]${NC} $*"
}

# Silent function - temporarily disables logging and executes command
silent() {
    local original_install_log="${INSTALL_LOG:-}"
    INSTALL_LOG="false"
    
    # Execute the command with all arguments
    "$@"
    local exit_code=$?
    
    # Restore original INSTALL_LOG setting
    if [[ -n "$original_install_log" ]]; then
        INSTALL_LOG="$original_install_log"
    else
        unset INSTALL_LOG
    fi
    
    return $exit_code
}

# Check if running as root for system-wide installation
check_permissions() {
    if [[ $EUID -eq 0 ]]; then
        log_info "Installing system-wide to $INSTALL_DIR"
    else
        if [[ ! -w "$INSTALL_DIR" ]]; then
            log_warn "No write permission to $INSTALL_DIR"
            log_info "Installing to ~/.local/bin instead"
            INSTALL_DIR="$HOME/.local/bin"
            mkdir -p "$INSTALL_DIR"
        fi
    fi
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v bash >/dev/null 2>&1; then
        missing_deps+=("bash")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Please install the missing dependencies and try again."
        exit 1
    fi
    
    log_info "All dependencies are satisfied"
}

# Get latest release version from GitHub API
get_latest_release() {
    local api_url="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest"
    local latest_version
    
    log_info "Fetching latest release information..."
    
    if command -v curl >/dev/null 2>&1; then
        latest_version=$(curl -fsSL "$api_url" | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
    elif command -v wget >/dev/null 2>&1; then
        latest_version=$(wget -qO- "$api_url" | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
    else
        log_error "Neither curl nor wget is available. Cannot fetch release information."
        exit 1
    fi
    
    if [[ -z "$latest_version" ]]; then
        log_error "Failed to get latest release version"
        exit 1
    fi
    
    echo "$latest_version"
}

# Download and install hype
install_hype() {
    local target_path="$INSTALL_DIR/$SCRIPT_NAME"
    local download_url
    local version_to_install
    
    log_info "Installing hype to $target_path"
    
    # If we're in a development environment, copy from src/
    if [[ -f "src/hype" ]]; then
        log_info "Using local development version"
        cp "src/hype" "$target_path"
    else
        # Determine version and download URL
        if [[ -n "${INSTALL_VERSION:-}" ]]; then
            version_to_install="$INSTALL_VERSION"
            log_info "Installing specific version: $version_to_install"
        else
            version_to_install=$(silent get_latest_release)
            log_info "Installing latest version: $version_to_install"
        fi
        
        download_url="$RELEASE_URL/$version_to_install/$SCRIPT_NAME"
        
        # Download from GitHub release
        log_info "Downloading from $download_url"
        if command -v curl >/dev/null 2>&1; then
            if ! curl -fsSL "$download_url" -o "$target_path"; then
                log_error "Failed to download from release. Falling back to main branch."
                download_url="$REPO_URL"
                curl -fsSL "$download_url" -o "$target_path"
            fi
        elif command -v wget >/dev/null 2>&1; then
            if ! wget -q "$download_url" -O "$target_path"; then
                log_error "Failed to download from release. Falling back to main branch."
                download_url="$REPO_URL"
                wget -q "$download_url" -O "$target_path"
            fi
        else
            log_error "Neither curl nor wget is available. Cannot download hype."
            exit 1
        fi
    fi
    
    # Make executable
    chmod +x "$target_path"
    
    log_info "hype installed successfully!"
}

# Verify installation
verify_installation() {
    if command -v hype >/dev/null 2>&1; then
        local version
        version=$(hype --version)
        log_info "Installation verified: $version"
    else
        log_warn "hype command not found in PATH."
        log_info "You may need to add $INSTALL_DIR to your PATH:"
        log_info "  export PATH=\"$INSTALL_DIR:\$PATH\""
        log_info "Add this line to your ~/.bashrc or ~/.zshrc file."
    fi
}

# Show usage information
show_usage() {
    log_info "hype has been installed!"
    log_info ""
    log_info "Quick start:"
    log_info "  hype           # Say hello world"
    log_info "  hype hello     # Say hello"
    log_info "  hype --help    # Show help"
    log_info ""
    log_info "For more information, run: hype --help"
}

# Main installation process
main() {
    log_info "Starting hype installation..."
    
    check_permissions
    check_dependencies
    install_hype
    verify_installation
    show_usage
    
    log_info "Installation complete!"
}

# Run main function
main "$@"