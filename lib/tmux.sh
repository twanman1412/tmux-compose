#!/usr/bin/env bash

# Create or attach to tmux session
create_or_attach_session() {
    local session_name="$1"
    
    if tmux has-session -t "$session_name" 2>/dev/null; then
        log "Attaching to existing session: $session_name"
        exec tmux attach-session -t "$session_name"
    else
        log "Creating new session: $session_name"
        tmux new-session -d -s "$session_name" -c "$PROJECT_DIR"
        return 0
    fi
}

# Create window for service
create_service_window() {
    local session_name="$1"
    local service="$2"
    local window_id="$3"
    local window_name="$service"
    
    if [[ "$window_id" == "0" ]]; then
        # Rename the first window
        tmux rename-window -t "$session_name:0" "$window_name"
    else
        # Create new window
        tmux new-window -t "$session_name" -n "$window_name" -c "$PROJECT_DIR"
    fi
    
    # Start following logs for this service
    tmux send-keys -t "$session_name:$window_name" "docker-compose -f '$DOCKER_COMPOSE_FILE' -p '$PROJECT_NAME' logs -f '$service'" C-m
}

# Create pane for service in existing window
create_service_pane() {
    local session_name="$1"
    local service="$2"
    local window_name="$3"
    local pane_count="$4"
    local max_panes="$5"
    
    if [[ "$pane_count" -eq 1 ]]; then
        # First pane, just use existing window
        tmux send-keys -t "$session_name:$window_name" "docker-compose -f '$DOCKER_COMPOSE_FILE' -p '$PROJECT_NAME' logs -f '$service'" C-m
    else
        # Create new pane
        local split_direction
        split_direction="$(config_get "split_direction" "horizontal")"
        
        if [[ "$split_direction" == "vertical" ]]; then
            tmux split-window -t "$session_name:$window_name" -h -c "$PROJECT_DIR"
        else
            tmux split-window -t "$session_name:$window_name" -v -c "$PROJECT_DIR"
        fi
        
        # Start logs in new pane
        tmux send-keys -t "$session_name:$window_name" "docker-compose -f '$DOCKER_COMPOSE_FILE' -p '$PROJECT_NAME' logs -f '$service'" C-m
        
        # Arrange panes in tiled layout if we have multiple panes
        if [[ "$pane_count" -gt 2 ]]; then
            tmux select-layout -t "$session_name:$window_name" tiled
        fi
    fi
}

# Setup tmux session for docker-compose services
setup_tmux_session() {
    local session_name="$1"
    local services_mode
    services_mode="$(config_get "services" "window")"
    local max_panes
    max_panes="$(config_get "services_panes" "4")"
    
    # Get list of services
    local services
    mapfile -t services < <(get_services)
    
    if [[ ${#services[@]} -eq 0 ]]; then
        error "No services found in docker-compose file"
    fi
    
    log "Setting up tmux session for services: ${services[*]}"
    
    if [[ "$services_mode" == "window" ]]; then
        # Create one window per service
        for i in "${!services[@]}"; do
            create_service_window "$session_name" "${services[$i]}" "$i"
        done
    else
        # Create panes within windows
        local current_window=0
        local pane_count=0
        local window_name="services"
        
        # Create first window
        tmux rename-window -t "$session_name:0" "$window_name"
        
        for service in "${services[@]}"; do
            pane_count=$((pane_count + 1))
            
            # Check if we need a new window
            if [[ "$max_panes" -gt 0 && "$pane_count" -gt "$max_panes" ]]; then
                current_window=$((current_window + 1))
                window_name="services-$((current_window + 1))"
                pane_count=1
                
                tmux new-window -t "$session_name" -n "$window_name" -c "$PROJECT_DIR"
            fi
            
            create_service_pane "$session_name" "$service" "$window_name" "$pane_count" "$max_panes"
        done
        
        # Go back to first window
        tmux select-window -t "$session_name:0"
    fi
    
    # Setup keybindings
    setup_keybindings "$session_name"
    
    # Select first window
    tmux select-window -t "$session_name:0"
}

# Setup custom keybindings for the session
setup_keybindings() {
    local session_name="$1"
    local shell_keybind
    shell_keybind="$(config_get "keybinds.shell_access" "C-s")"
    
    log "Setting up keybind: $shell_keybind for shell access"
    
    # Get shell priority from config
    local shell_priority
    mapfile -t shell_priority < <(config_get_array "shell_priority")
    if [[ ${#shell_priority[@]} -eq 0 ]]; then
        shell_priority=("bash" "sh" "ash")
    fi
    
    debug "Shell priority: ${shell_priority[*]}"
    
    # Build shell command with fallbacks
    local shell_cmd=""
    for shell in "${shell_priority[@]}"; do
        if [[ -z "$shell_cmd" ]]; then
            shell_cmd="docker exec -it \\\$container_id $shell"
        else
            shell_cmd="$shell_cmd || docker exec -it \\\$container_id $shell"
        fi
    done
    
    debug "Shell command: $shell_cmd"
    
    # Bind key to open shell in current service container
    local split_direction
    split_direction="$(config_get "split_direction" "horizontal")"
    local split_flag="-v"
    if [[ "$split_direction" == "vertical" ]]; then
        split_flag="-h"
    fi
    
    tmux bind-key "$shell_keybind" run-shell "
        window_name=\$(tmux display-message -p '#W')
        cd '$PROJECT_DIR'
        container_id=\$(docker-compose -f '$DOCKER_COMPOSE_FILE' -p '$PROJECT_NAME' ps -q \"\$window_name\" 2>/dev/null | head -1)
        if [ -n \"\$container_id\" ]; then
            # Create split and immediately run shell with cleanup
            tmux split-window $split_flag
            tmux send-keys \"clear; docker exec -it \$container_id bash || docker exec -it \$container_id sh; exit\" C-m
        else
            tmux display-message \"No running container found for service: \$window_name\"
        fi
    "
    
    log "Keybind: Ctrl+B then $shell_keybind for shell access"
}

# Open shell in service container
open_service_shell() {
    local service="$1"
    local shell_mode
    shell_mode="$(config_get "shell_access" "split")"
    local split_direction
    split_direction="$(config_get "split_direction" "horizontal")"
    
    # Find available shell
    local shell
    shell="$(find_container_shell "$service")"
    
    if [[ "$shell_mode" == "window" ]]; then
        # Open in new window
        tmux new-window -n "${service}-shell" -c "$PROJECT_DIR"
        tmux send-keys "docker exec -it \$(docker-compose -f '$DOCKER_COMPOSE_FILE' -p '$PROJECT_NAME' ps -q '$service') '$shell'" C-m
    else
        # Open in split pane
        if [[ "$split_direction" == "vertical" ]]; then
            tmux split-window -h -c "$PROJECT_DIR"
        else
            tmux split-window -v -c "$PROJECT_DIR"
        fi
        tmux send-keys "docker exec -it \$(docker-compose -f '$DOCKER_COMPOSE_FILE' -p '$PROJECT_NAME' ps -q '$service') '$shell'" C-m
    fi
}

# Clean up tmux session based on configuration
cleanup_session() {
    local session_name="$1"
    local cleanup_mode
    cleanup_mode="$(config_get "session_cleanup" "store")"
    
    case "$cleanup_mode" in
        "quit")
            log "Cleaning up session: $session_name"
            tmux kill-session -t "$session_name" 2>/dev/null || true
            ;;
        "store")
            log "Storing logs and cleaning up session: $session_name"
            # TODO: Store logs to files before killing session
            tmux kill-session -t "$session_name" 2>/dev/null || true
            ;;
        "persist")
            log "Session persisting: $session_name"
            # Do nothing, leave session running
            ;;
    esac
}

# Main tmux-compose up function
tmux_compose_up() {
    check_dependencies
    
    local session_name
    session_name="$(resolve_session_name)"
    
    # Start docker-compose in background
    log "Starting docker-compose in background..."
    docker-compose -f "$DOCKER_COMPOSE_FILE" -p "$PROJECT_NAME" up -d "$@"
    
    # Wait for containers to be ready with a more robust check
    log "Waiting for containers to be ready..."
    local max_wait=30
    local wait_time=0
    while [[ $wait_time -lt $max_wait ]]; do
        local running_count
        running_count=$(docker-compose -f "$DOCKER_COMPOSE_FILE" -p "$PROJECT_NAME" ps -q 2>/dev/null | wc -l)
        local service_count
        service_count=$(get_services | wc -l)
        
        if [[ "$running_count" -ge "$service_count" ]]; then
            log "All containers are running"
            sleep 2  # Extra buffer for logs to start
            break
        fi
        
        sleep 1
        wait_time=$((wait_time + 1))
    done
    
    # Create or attach to tmux session
    create_or_attach_session "$session_name"
    
    # Setup tmux session with service windows/panes
    setup_tmux_session "$session_name"
    
    # Attach to session
    exec tmux attach-session -t "$session_name"
}

# Main tmux-compose down function
tmux_compose_down() {
    local session_name
    session_name="$(resolve_session_name)"
    
    # Stop docker-compose
    docker_compose_down "$@"
    
    # Cleanup tmux session
    cleanup_session "$session_name"
}

# Show containers in tmux-friendly format
tmux_compose_ps() {
    echo "Tmux Session: $(resolve_session_name)"
    echo "Docker Compose Status:"
    docker_compose_ps "$@"
}

# Show logs for service
tmux_compose_logs() {
    docker_compose_logs "$@"
}

# Open shell in service container
tmux_compose_shell() {
    local service="$1"
    
    if [[ -z "$service" ]]; then
        error "Service name required for shell command"
    fi
    
    if ! service_exists "$service"; then
        error "Service '$service' not found in docker-compose file"
    fi
    
    open_service_shell "$service"
}
