#!/usr/bin/env bash

# Advanced health check script for Keepalived
# Performs multiple checks to determine service health

set -e

# Configuration
HEALTH_CHECK_URL="${HEALTH_CHECK_URL:-http://localhost:8080/health}"
HEALTH_CHECK_PORT="${HEALTH_CHECK_PORT:-8080}"
HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-3}"
LOG_FILE="/var/log/keepalived/health-check.log"
MAX_LOG_SIZE=10485760  # 10MB

# Logging function
log_message() {
    local level="$1"
    shift
    local message="$@"
    
    # Rotate log if too large
    if [[ -f "$LOG_FILE" ]] && [[ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null) -gt $MAX_LOG_SIZE ]]; then
        mv "$LOG_FILE" "${LOG_FILE}.old"
    fi
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$LOG_FILE"
}

# Check 1: HTTP/HTTPS endpoint health check
check_http_endpoint() {
    log_message "INFO" "Checking HTTP endpoint: $HEALTH_CHECK_URL"
    
    if curl -sf --max-time "$HEALTH_CHECK_TIMEOUT" "$HEALTH_CHECK_URL" > /dev/null 2>&1; then
        log_message "INFO" "HTTP endpoint check PASSED"
        return 0
    else
        log_message "ERROR" "HTTP endpoint check FAILED"
        return 1
    fi
}

# Check 2: TCP port connectivity
check_tcp_port() {
    log_message "INFO" "Checking TCP port: $HEALTH_CHECK_PORT"
    
    if timeout "$HEALTH_CHECK_TIMEOUT" bash -c "echo > /dev/tcp/localhost/$HEALTH_CHECK_PORT" 2>/dev/null; then
        log_message "INFO" "TCP port check PASSED"
        return 0
    else
        log_message "ERROR" "TCP port check FAILED"
        return 1
    fi
}

# Check 3: Process check (example for nginx)
check_process() {
    local process_name="${HEALTH_CHECK_PROCESS:-nginx}"
    log_message "INFO" "Checking process: $process_name"
    
    if pgrep -x "$process_name" > /dev/null 2>&1; then
        log_message "INFO" "Process check PASSED"
        return 0
    else
        log_message "ERROR" "Process check FAILED - $process_name not running"
        return 1
    fi
}

# Check 4: Docker container health (if running in Docker)
check_docker_container() {
    local container_name="${HEALTH_CHECK_CONTAINER:-app}"
    log_message "INFO" "Checking Docker container: $container_name"
    
    if command -v docker &> /dev/null; then
        local container_status=$(docker inspect -f '{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "unknown")
        
        if [[ "$container_status" == "healthy" ]]; then
            log_message "INFO" "Docker container check PASSED"
            return 0
        else
            log_message "ERROR" "Docker container check FAILED - Status: $container_status"
            return 1
        fi
    else
        log_message "WARN" "Docker not available, skipping container check"
        return 0
    fi
}

# Check 5: Database connectivity (example for PostgreSQL)
check_database() {
    local db_host="${DB_HOST:-localhost}"
    local db_port="${DB_PORT:-5432}"
    local db_name="${DB_NAME:-postgres}"
    local db_user="${DB_USER:-postgres}"
    
    log_message "INFO" "Checking database connectivity: $db_host:$db_port"
    
    if command -v pg_isready &> /dev/null; then
        if pg_isready -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -t "$HEALTH_CHECK_TIMEOUT" > /dev/null 2>&1; then
            log_message "INFO" "Database check PASSED"
            return 0
        else
            log_message "ERROR" "Database check FAILED"
            return 1
        fi
    else
        log_message "WARN" "pg_isready not available, skipping database check"
        return 0
    fi
}

# Check 6: Disk space
check_disk_space() {
    local threshold="${DISK_THRESHOLD:-90}"
    log_message "INFO" "Checking disk space (threshold: ${threshold}%)"
    
    local usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [[ $usage -lt $threshold ]]; then
        log_message "INFO" "Disk space check PASSED (${usage}% used)"
        return 0
    else
        log_message "ERROR" "Disk space check FAILED (${usage}% used, threshold: ${threshold}%)"
        return 1
    fi
}

# Check 7: Memory usage
check_memory() {
    local threshold="${MEM_THRESHOLD:-90}"
    log_message "INFO" "Checking memory usage (threshold: ${threshold}%)"
    
    local usage=$(free | awk 'NR==2 {printf "%.0f", $3/$2 * 100}')
    
    if [[ $usage -lt $threshold ]]; then
        log_message "INFO" "Memory check PASSED (${usage}% used)"
        return 0
    else
        log_message "ERROR" "Memory check FAILED (${usage}% used, threshold: ${threshold}%)"
        return 1
    fi
}

# Main health check logic
main() {
    log_message "INFO" "Starting health check"
    
    local failed_checks=0
    local check_mode="${HEALTH_CHECK_MODE:-http}"  # http, tcp, process, docker, all
    
    case "$check_mode" in
        http)
            check_http_endpoint || ((failed_checks++))
            ;;
        tcp)
            check_tcp_port || ((failed_checks++))
            ;;
        process)
            check_process || ((failed_checks++))
            ;;
        docker)
            check_docker_container || ((failed_checks++))
            ;;
        database)
            check_database || ((failed_checks++))
            ;;
        all)
            # Run all applicable checks
            check_http_endpoint || ((failed_checks++))
            check_tcp_port || ((failed_checks++))
            check_disk_space || ((failed_checks++))
            check_memory || ((failed_checks++))
            ;;
        *)
            log_message "ERROR" "Unknown check mode: $check_mode"
            exit 1
            ;;
    esac
    
    if [[ $failed_checks -eq 0 ]]; then
        log_message "INFO" "All health checks PASSED"
        exit 0
    else
        log_message "ERROR" "$failed_checks health check(s) FAILED"
        exit 1
    fi
}

# Run main function
main "$@"