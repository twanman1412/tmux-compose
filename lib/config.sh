#!/usr/bin/env bash

# Default configuration
DEFAULT_CONFIG='{
  "services": "window",
  "services_panes": 4,
  "shell_access": "split",
  "shell_priority": ["bash", "sh", "ash"],
  "session_naming": "{project_name}",
  "session_cleanup": "store",
  "split_direction": "horizontal",
  "keybinds": {
    "shell_access": "Space"
  }
}'

# Load configuration from various sources
load_config() {
    local config="$DEFAULT_CONFIG"
    
    # Load global config if exists
    if [[ -f "$DEFAULT_CONFIG_PATH" ]]; then
        debug "Loading global config: $DEFAULT_CONFIG_PATH"
        local global_config
        global_config="$(cat "$DEFAULT_CONFIG_PATH")"
        config="$(merge_json_configs "$config" "$global_config")"
    fi
    
    # Load project config if exists
    if [[ -f "$PROJECT_CONFIG_PATH" ]]; then
        debug "Loading project config: $PROJECT_CONFIG_PATH"
        local project_config
        project_config="$(cat "$PROJECT_CONFIG_PATH")"
        config="$(merge_json_configs "$config" "$project_config")"
    fi
    
    # Override with environment variables if set
    if [[ -n "${TMUX_COMPOSE_CONFIG:-}" ]]; then
        debug "Loading config from environment"
        config="$(merge_json_configs "$config" "$TMUX_COMPOSE_CONFIG")"
    fi
    
    echo "$config"
}

# Merge two JSON configurations (second overrides first)
merge_json_configs() {
    local base="$1"
    local override="$2"
    
    echo "$base" | jq --argjson override "$override" '. * $override'
}

# Get configuration value
config_get() {
    local key="$1"
    local default="${2:-}"
    json_get "$CONFIG" "$key" "$default"
}

# Get configuration array
config_get_array() {
    local key="$1"
    json_get_array "$CONFIG" "$key"
}

# Initialize configuration directory and create default config
init_config() {
    local config_dir
    config_dir="$(dirname "$DEFAULT_CONFIG_PATH")"
    
    if [[ ! -d "$config_dir" ]]; then
        log "Creating config directory: $config_dir"
        mkdir -p "$config_dir"
    fi
    
    if [[ ! -f "$DEFAULT_CONFIG_PATH" ]]; then
        log "Creating default configuration: $DEFAULT_CONFIG_PATH"
        echo "$DEFAULT_CONFIG" | jq '.' > "$DEFAULT_CONFIG_PATH"
    fi
}

# Create example project configuration
create_project_config() {
    local example_config='{
  "services": "window",
  "services_panes": 4,
  "shell_access": "split",
  "split_direction": "horizontal",
  "session_cleanup": "store",
  "keybinds": {
    "shell_access": "C-s"
  }
}'
    
    if [[ ! -f "$PROJECT_CONFIG_PATH" ]]; then
        log "Creating example project config: $PROJECT_CONFIG_PATH"
        echo "$example_config" | jq '.' > "$PROJECT_CONFIG_PATH"
    fi
}

# Resolve session name template
resolve_session_name() {
    local template
    template="$(config_get "session_naming" "{project_name}")"
    
    # Replace template variables
    template="${template//\{project_name\}/$PROJECT_NAME}"
    template="${template//\{project_dir\}/$(basename "$PROJECT_DIR")}"
    
    # Sanitize for tmux
    sanitize_name "$template"
}
