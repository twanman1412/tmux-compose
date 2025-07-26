#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="${1:-/usr/local/bin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[install]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[install]${NC} WARNING: $*"
}

error() {
    echo -e "${RED}[install]${NC} ERROR: $*"
    exit 1
}

# Check dependencies
check_dependencies() {
    local missing=()
    
    if ! command -v tmux >/dev/null 2>&1; then
        missing+=("tmux")
    fi
    
    if ! command -v docker-compose >/dev/null 2>&1; then
        missing+=("docker-compose")
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        missing+=("jq")
    fi
    
    if ! command -v yq >/dev/null 2>&1; then
        missing+=("yq")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required dependencies: ${missing[*]}"
    fi
}

# Install tmux-compose
install_tmux_compose() {
    log "Installing tmux-compose to $INSTALL_DIR"
    
    # Check if install directory exists and is writable
    if [[ ! -d "$INSTALL_DIR" ]]; then
        error "Install directory does not exist: $INSTALL_DIR"
    fi
    
    if [[ ! -w "$INSTALL_DIR" ]]; then
        error "Install directory is not writable: $INSTALL_DIR"
    fi
    
    # Copy main script
    cp "$SCRIPT_DIR/tmux-compose" "$INSTALL_DIR/tmux-compose"
    chmod +x "$INSTALL_DIR/tmux-compose"
    
    # Create lib directory
    local lib_dir="$INSTALL_DIR/tmux-compose-lib"
    mkdir -p "$lib_dir"
    
    # Copy library files
    cp -r "$SCRIPT_DIR/lib/"* "$lib_dir/"
    
    # Update script to use installed lib directory
    sed -i "s|source \"\${SCRIPT_DIR}/lib/|source \"$lib_dir/|g" "$INSTALL_DIR/tmux-compose"
    
    log "tmux-compose installed successfully!"
    log "Usage: tmux-compose --help"
}

main() {
    echo "tmux-compose installer"
    echo "====================="
    
    check_dependencies
    install_tmux_compose
    
    echo
    log "Installation complete!"
    log "Run 'tmux-compose --help' to get started"
}

main "$@"
