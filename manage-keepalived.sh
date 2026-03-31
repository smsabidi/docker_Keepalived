#!/usr/bin/env zsh

setopt ERR_EXIT
setopt PIPE_FAIL

# Script configuration
SCRIPT_DIR="${0:A:h}"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
PROJECT_NAME="keepalived-ha"
LOG_DIR="${SCRIPT_DIR}/logs"

# Logging functions with proper ZSH color formatting
log_info() {
    print -P "%F{blue}[INFO]%f $1"
}

log_success() {
    print -P "%F{green}[SUCCESS]%f $1"
}

log_warning() {
    print -P "%F{yellow}[WARNING]%f $1"
}

log_error() {
    print -P "%F{red}[ERROR]%f $1"
}

# Check if Docker and Docker Compose are installed
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        return 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        return 1
    fi
    
    # Determine which docker compose command to use
    if docker compose version &> /dev/null 2>&1; then
        DOCKER_COMPOSE="docker compose"
    else
        DOCKER_COMPOSE="docker-compose"
    fi
    
    log_success "Prerequisites check passed"
}

# Create necessary directories
create_directories() {
    log_info "Creating necessary directories..."
    mkdir -p "${LOG_DIR}/master"
    mkdir -p "${LOG_DIR}/backup"
    mkdir -p "${SCRIPT_DIR}/configs"
    log_success "Directories created"
}

# Build Docker images
build_images() {
    log_info "Building Docker images..."
    ${=DOCKER_COMPOSE} -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" build "$@"
    log_success "Docker images built successfully"
}

# Start services
start_services() {
    log_info "Starting Keepalived services..."
    create_directories
    ${=DOCKER_COMPOSE} -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" up -d "$@"
    log_success "Keepalived services started successfully"
    print ""
    show_status
}

# Stop services
stop_services() {
    log_info "Stopping Keepalived services..."
    ${=DOCKER_COMPOSE} -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" down "$@"
    log_success "Keepalived services stopped successfully"
}

# Restart services
restart_services() {
    log_info "Restarting Keepalived services..."
    ${=DOCKER_COMPOSE} -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" restart "$@"
    log_success "Keepalived services restarted successfully"
    print ""
    show_status
}

# Show service status
show_status() {
    log_info "Service Status:"
    print ""
    ${=DOCKER_COMPOSE} -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" ps
    print ""
    
    # Check if containers are running and show virtual IP
    local master_containers=(${(f)"$(docker ps --filter "name=${PROJECT_NAME}" --format "{{.Names}}" 2>/dev/null | grep master)"})
    
    if (( ${#master_containers[@]} > 0 )); then
        log_info "Checking Virtual IP assignment..."
        local master_container="${master_containers[1]}"
        
        if [[ -n "$master_container" ]]; then
            local vip_status=$(docker exec "$master_container" ip addr show 2>/dev/null | grep "192.168.1.100" || echo "Not assigned")
            if [[ "$vip_status" != "Not assigned" ]]; then
                log_success "Virtual IP is assigned to master node"
            else
                log_warning "Virtual IP is not yet assigned"
            fi
        fi
    fi
}

# Show logs
show_logs() {
    local service="$1"
    if [[ -z "$service" ]]; then
        log_info "Showing logs for all services..."
        ${=DOCKER_COMPOSE} -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" logs -f
    else
        log_info "Showing logs for ${service}..."
        ${=DOCKER_COMPOSE} -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" logs -f "$service"
    fi
}

# Execute command in container
exec_command() {
    local service="$1"
    shift
    local cmd=("$@")
    
    if [[ -z "$service" ]]; then
        log_error "Please specify a service name (keepalived-master or keepalived-backup)"
        return 1
    fi
    
    log_info "Executing command in ${service}..."
    ${=DOCKER_COMPOSE} -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" exec "$service" "${cmd[@]}"
}

# Validate configuration
validate_config() {
    log_info "Validating Keepalived configuration..."
    
    # Build if images don't exist
    if ! docker images | grep -q "custom-keepalived"; then
        log_warning "Images not found. Building first..."
        build_images
    fi
    
    # Test master config
    log_info "Testing master configuration..."
    docker run --rm \
        -e KEEPALIVED_STATE=MASTER \
        -e KEEPALIVED_PRIORITY=100 \
        custom-keepalived:latest \
        keepalived --config-test
    
    # Test backup config
    log_info "Testing backup configuration..."
    docker run --rm \
        -e KEEPALIVED_STATE=BACKUP \
        -e KEEPALIVED_PRIORITY=90 \
        custom-keepalived:latest \
        keepalived --config-test
    
    log_success "Configuration validation passed"
}

# Clean up everything
cleanup() {
    log_warning "This will remove all containers, images, and volumes. Are you sure? (yes/no)"
    read -r confirmation
    
    if [[ "$confirmation" == "yes" ]]; then
        log_info "Cleaning up..."
        ${=DOCKER_COMPOSE} -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" down -v --rmi all
        log_success "Cleanup completed"
    else
        log_info "Cleanup cancelled"
    fi
}

# Test failover
test_failover() {
    log_info "Testing failover scenario..."
    log_info "Stopping master node..."
    ${=DOCKER_COMPOSE} -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" stop keepalived-master
    
    log_info "Waiting 5 seconds for backup to take over..."
    sleep 5
    
    log_info "Checking if backup has taken over..."
    local backup_containers=(${(f)"$(docker ps --filter "name=${PROJECT_NAME}-backup" --format "{{.Names}}" 2>/dev/null)"})
    
    if (( ${#backup_containers[@]} > 0 )); then
        local backup_container="${backup_containers[1]}"
        local vip_status=$(docker exec "$backup_container" ip addr show 2>/dev/null | grep "192.168.1.100" || echo "Not assigned")
        
        if [[ "$vip_status" != "Not assigned" ]]; then
            log_success "Failover successful! Backup node now has the Virtual IP"
        else
            log_error "Failover failed! Virtual IP not assigned to backup"
        fi
    fi
    
    log_info "Restarting master node..."
    ${=DOCKER_COMPOSE} -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" start keepalived-master
    
    log_info "Waiting 5 seconds for master to reclaim VIP..."
    sleep 5
    show_status
}

# Show help
show_help() {
    print -P "%F{green}════════════════════════════════════════════════════════════%f"
    print -P "%F{green}   Keepalived Docker Compose Management Script (ZSH)%f"
    print -P "%F{green}════════════════════════════════════════════════════════════%f"
    print ""
    print -P "%F{yellow}Usage:%f"
    print "    ./manage-keepalived.sh [COMMAND] [OPTIONS]"
    print ""
    print -P "%F{yellow}Commands:%f"
    print -P "    %F{blue}build%f           Build Docker images"
    print -P "    %F{blue}up%f              Start all services (build if needed)"
    print -P "    %F{blue}down%f            Stop and remove all services"
    print -P "    %F{blue}start%f           Start services without recreating"
    print -P "    %F{blue}stop%f            Stop services without removing"
    print -P "    %F{blue}restart%f         Restart all services"
    print -P "    %F{blue}status%f          Show service status"
    print -P "    %F{blue}logs%f [service]  Show logs (optional: specify service)"
    print -P "    %F{blue}exec%f <service> <cmd>  Execute command in container"
    print -P "    %F{blue}validate%f        Validate Keepalived configuration"
    print -P "    %F{blue}test-failover%f   Test failover scenario"
    print -P "    %F{blue}cleanup%f         Remove all containers, images, and volumes"
    print -P "    %F{blue}help%f            Show this help message"
    print ""
    print -P "%F{yellow}Examples:%f"
    print "    ./manage-keepalived.sh up                           # Build and start all services"
    print "    ./manage-keepalived.sh up --build                   # Force rebuild and start"
    print "    ./manage-keepalived.sh logs keepalived-master       # Show master logs"
    print "    ./manage-keepalived.sh exec keepalived-master bash  # Open shell in master container"
    print "    ./manage-keepalived.sh test-failover                # Test failover scenario"
    print "    ./manage-keepalived.sh down -v                      # Stop and remove volumes"
    print ""
    print -P "%F{yellow}Service Names:%f"
    print "    - keepalived-master"
    print "    - keepalived-backup"
    print ""
}

# Main script logic
main() {
    check_prerequisites || return 1
    
    # Handle case when no arguments provided
    local command="${1:-help}"
    
    # Only shift if we have arguments
    if (( $# > 0 )); then
        shift
    fi
    
    case "$command" in
        build)
            build_images "$@"
            ;;
        up|start-all)
            build_images --quiet 2>/dev/null || true
            start_services "$@"
            ;;
        down|stop-all)
            stop_services "$@"
            ;;
        start)
            ${=DOCKER_COMPOSE} -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" start "$@"
            show_status
            ;;
        stop)
            ${=DOCKER_COMPOSE} -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" stop "$@"
            ;;
        restart)
            restart_services "$@"
            ;;
        status|ps)
            show_status
            ;;
        logs)
            show_logs "$@"
            ;;
        exec)
            exec_command "$@"
            ;;
        validate|test-config)
            validate_config
            ;;
        test-failover)
            test_failover
            ;;
        cleanup|clean)
            cleanup
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            print ""
            show_help
            return 1
            ;;
    esac
}

# Run main function
main "$@"