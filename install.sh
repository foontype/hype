#!/bin/bash

# HYPE CLI Installation Script

set -euo pipefail

# Check for dry-run mode
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    shift
else
    DRY_RUN=false
fi

# Configuration
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="hype"
REPO_OWNER="${HYPE_REPO_OWNER:-foontype}"
REPO_NAME="${HYPE_REPO_NAME:-hype}"
REPO_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/src/hype"
RELEASE_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download"

# Colors for output (disabled during downloads to prevent contamination)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Flag to control color output during critical operations
DISABLE_COLORS=false

# Logging functions
log_info() {
    if [[ "$DISABLE_COLORS" == "true" ]]; then
        echo "[INFO] $*"
    else
        echo -e "${GREEN}[INFO]${NC} $*"
    fi
}

log_warn() {
    if [[ "$DISABLE_COLORS" == "true" ]]; then
        echo "[WARN] $*"
    else
        echo -e "${YELLOW}[WARN]${NC} $*"
    fi
}

log_error() {
    if [[ "$DISABLE_COLORS" == "true" ]]; then
        echo "[ERROR] $*"
    else
        echo -e "${RED}[ERROR]${NC} $*"
    fi
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
    
    # Temporarily disable colors during API call to prevent contamination
    DISABLE_COLORS=true
    log_info "Fetching latest release information..."
    
    if command -v curl >/dev/null 2>&1; then
        latest_version=$(curl -fsSL "$api_url" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
    elif command -v wget >/dev/null 2>&1; then
        latest_version=$(wget -qO- "$api_url" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
    else
        DISABLE_COLORS=false
        log_error "Neither curl nor wget is available. Cannot fetch release information."
        exit 1
    fi
    
    # Re-enable colors
    DISABLE_COLORS=false
    
    if [[ -z "$latest_version" ]]; then
        log_error "Failed to get latest release version"
        exit 1
    fi
    
    # Clean the version string to ensure no contamination
    latest_version=$(echo "$latest_version" | tr -d '\033' | sed 's/\[[0-9;]*m//g')
    
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
            version_to_install=$(get_latest_release)
            log_info "Installing latest version: $version_to_install"
        fi
        
        # Disable colors during critical download operations to prevent URL contamination
        DISABLE_COLORS=true
        
        # Construct download URL with clean variable substitution
        download_url="${RELEASE_URL}/${version_to_install}/${SCRIPT_NAME}"
        
        # Download from GitHub release
        log_info "Downloading from $download_url"
        
        # In dry-run mode, just verify URL construction
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "DRY RUN: Would download from URL: $download_url"
            log_info "DRY RUN: Target path would be: $target_path"
            # Create a dummy file for testing
            echo "# HYPE CLI dry-run test" > "$target_path"
        else
            if command -v curl >/dev/null 2>&1; then
                # Use clean curl command without any potential variable contamination
                if ! curl -fsSL "$download_url" -o "$target_path" 2>/dev/null; then
                    log_error "Failed to download from release. Falling back to main branch."
                    download_url="$REPO_URL"
                    if ! curl -fsSL "$download_url" -o "$target_path" 2>/dev/null; then
                        DISABLE_COLORS=false
                        log_error "Failed to download hype from both release and main branch."
                        exit 1
                    fi
                fi
            elif command -v wget >/dev/null 2>&1; then
                # Use clean wget command without any potential variable contamination
                if ! wget -q "$download_url" -O "$target_path" 2>/dev/null; then
                    log_error "Failed to download from release. Falling back to main branch."
                    download_url="$REPO_URL"
                    if ! wget -q "$download_url" -O "$target_path" 2>/dev/null; then
                        DISABLE_COLORS=false
                        log_error "Failed to download hype from both release and main branch."
                        exit 1
                    fi
                fi
            else
                DISABLE_COLORS=false
                log_error "Neither curl nor wget is available. Cannot download hype."
                exit 1
            fi
        fi
        
        # Re-enable colors after download
        DISABLE_COLORS=false
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