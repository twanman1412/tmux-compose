#!/usr/bin/env bash

# Get list of services from docker-compose file
get_services() {
    yq '.services | keys | .[]' "$DOCKER_COMPOSE_FILE" 2>/dev/null | sed 's/"//g' || {
        # Fallback to docker-compose config if yq fails
        debug "yq failed, trying docker-compose config"
        docker-compose -f "$DOCKER_COMPOSE_FILE" config --services 2>/dev/null || {
            # Last resort: basic grep parsing
            warn "Both yq and docker-compose config failed, using basic parsing"
            grep -E '^[[:space:]]*[a-zA-Z0-9_-]+:' "$DOCKER_COMPOSE_FILE" | \
                sed 's/[[:space:]]*\([^:]*\):.*/\1/' | \
                grep -v '^version$\|^services$\|^volumes$\|^networks$'
        }
    }
}

# Get running containers for the project
get_running_containers() {
    docker-compose -f "$DOCKER_COMPOSE_FILE" -p "$PROJECT_NAME" ps -q 2>/dev/null | while read -r container_id; do
        if [[ -n "$container_id" ]]; then
            # Get container info
            local service_name
            service_name="$(docker inspect "$container_id" --format '{{index .Config.Labels "com.docker.compose.service"}}' 2>/dev/null || echo "unknown")"
            local container_name
            container_name="$(docker inspect "$container_id" --format '{{.Name}}' 2>/dev/null | sed 's/^///' || echo "$container_id")"
            
            echo "$service_name:$container_name:$container_id"
        fi
    done
}

# Get container ID for a service
get_container_id() {
    local service="$1"
    local container_number="${2:-1}"
    
    docker-compose -f "$DOCKER_COMPOSE_FILE" -p "$PROJECT_NAME" ps -q "$service" 2>/dev/null | sed -n "${container_number}p"
}

# Get container name for a service
get_container_name() {
    local service="$1"
    local container_id
    container_id="$(get_container_id "$service")"
    
    if [[ -n "$container_id" ]]; then
        docker inspect "$container_id" --format '{{.Name}}' 2>/dev/null | sed 's/^///'
    fi
}

# Check if service exists in compose file
service_exists() {
    local service="$1"
    get_services | grep -q "^${service}$"
}

# Get replica count for a service
get_service_replicas() {
    local service="$1"
    
    local replicas
    replicas="$(yq ".services.${service}.deploy.replicas // 1" "$DOCKER_COMPOSE_FILE" 2>/dev/null)"
    echo "${replicas:-1}"
}

# Execute command in container
docker_exec() {
    local service="$1"
    shift
    local container_id
    
    container_id="$(get_container_id "$service")"
    if [[ -z "$container_id" ]]; then
        error "No running container found for service: $service"
    fi
    
    docker exec -it "$container_id" "$@"
}

# Find available shell in container
find_container_shell() {
    local service="$1"
    local shells
    mapfile -t shells < <(config_get_array "shell_priority")
    
    # If no shells configured, use default
    if [[ ${#shells[@]} -eq 0 ]]; then
        shells=("bash" "sh" "ash")
    fi
    
    local container_id
    container_id="$(get_container_id "$service")"
    if [[ -z "$container_id" ]]; then
        error "No running container found for service: $service"
    fi
    
    for shell in "${shells[@]}"; do
        if docker exec "$container_id" which "$shell" >/dev/null 2>&1; then
            echo "$shell"
            return 0
        fi
    done
    
    # Fallback to /bin/sh
    echo "sh"
}

# Start docker-compose with given arguments
docker_compose_up() {
    local args=("$@")
    
    log "Starting docker-compose with: ${args[*]}"
    docker-compose -f "$DOCKER_COMPOSE_FILE" -p "$PROJECT_NAME" up "${args[@]}"
}

# Stop docker-compose
docker_compose_down() {
    local args=("$@")
    
    log "Stopping docker-compose with: ${args[*]}"
    docker-compose -f "$DOCKER_COMPOSE_FILE" -p "$PROJECT_NAME" down "${args[@]}"
}

# Show docker-compose ps
docker_compose_ps() {
    docker-compose -f "$DOCKER_COMPOSE_FILE" -p "$PROJECT_NAME" ps "$@"
}

# Show docker-compose logs
docker_compose_logs() {
    docker-compose -f "$DOCKER_COMPOSE_FILE" -p "$PROJECT_NAME" logs "$@"
}

# Restart a specific service
docker_compose_restart() {
    local service="$1"
    
    if [[ -z "$service" ]]; then
        error "Service name required for restart"
    fi
    
    # Check if container is running
    local container_id
    container_id="$(get_container_id "$service")"
    
    if [[ -n "$container_id" ]]; then
        log "Restarting service: $service"
        docker-compose -f "$DOCKER_COMPOSE_FILE" -p "$PROJECT_NAME" restart "$service"
    else
        log "Service $service is not running, starting it instead"
        docker-compose -f "$DOCKER_COMPOSE_FILE" -p "$PROJECT_NAME" start "$service"
    fi
}
