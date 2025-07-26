#!/usr/bin/env bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[tmux-compose]${NC} $*" >&2
}

warn() {
    echo -e "${YELLOW}[tmux-compose]${NC} WARNING: $*" >&2
}

error() {
    echo -e "${RED}[tmux-compose]${NC} ERROR: $*" >&2
    exit 1
}

debug() {
    if [[ "${DEBUG:-}" == "1" ]]; then
        echo -e "${BLUE}[tmux-compose]${NC} DEBUG: $*" >&2
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate dependencies
check_dependencies() {
    local missing=()
    
    if ! command_exists tmux; then
        missing+=("tmux")
    fi
    
    if ! command_exists docker-compose; then
        missing+=("docker-compose")
    fi
    
    if ! command_exists jq; then
        missing+=("jq")
    fi
    
    if ! command_exists yq; then
        missing+=("yq")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required dependencies: ${missing[*]}"
    fi
}

# Find docker-compose file in current or parent directories
find_compose_file() {
    local dir="$PWD"
    local compose_files=("docker-compose.yml" "docker-compose.yaml" "compose.yml" "compose.yaml")
    
    while [[ "$dir" != "/" ]]; do
        for file in "${compose_files[@]}"; do
            if [[ -f "$dir/$file" ]]; then
                echo "$dir/$file"
                return 0
            fi
        done
        dir="$(dirname "$dir")"
    done
    
    return 1
}

# JSON helper functions
json_get() {
    local json="$1"
    local key="$2"
    local default="${3:-}"
    
    echo "$json" | jq -r ".$key // \"$default\""
}

json_get_array() {
    local json="$1"
    local key="$2"
    
    echo "$json" | jq -r ".$key[]? // empty"
}

# Sanitize string for tmux/shell use
sanitize_name() {
    echo "$1" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/_/g'
}
