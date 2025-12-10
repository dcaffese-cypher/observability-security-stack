#!/bin/bash
#
# Loki Safety Trim Script
# Monitors Loki data directory size and performs emergency rotation if threshold is exceeded
# This script deletes old data directly (no backup folder)
#

set -euo pipefail

# Configuration
# Replace these values with your actual environment settings
THRESHOLD_GB=80
LOKI_CONTAINER="YOUR_LOKI_CONTAINER_NAME"  # Replace with your Loki container name
LOKI_DATA_DIR="/path/to/loki-data"  # Replace with your Loki data directory path
LOKI_USER="10001"  # Replace with your Loki user UID (default: 10001)
LOKI_GROUP="10001"  # Replace with your Loki group GID (default: 10001)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [loki-safety-trim] $*"
}

# Error logging function
log_error() {
    echo -e "${RED}$(date '+%Y-%m-%d %H:%M:%S') [loki-safety-trim] ERROR: $*${NC}" >&2
}

# Success logging function
log_success() {
    echo -e "${GREEN}$(date '+%Y-%m-%d %H:%M:%S') [loki-safety-trim] $*${NC}"
}

# Warning logging function
log_warning() {
    echo -e "${YELLOW}$(date '+%Y-%m-%d %H:%M:%S') [loki-safety-trim] WARNING: $*${NC}"
}

# Check if running as root or with sudo
check_permissions() {
    if [ "$EUID" -eq 0 ]; then
        DOCKER_CMD="docker"
    elif groups | grep -q docker; then
        DOCKER_CMD="docker"
    elif command -v sudo >/dev/null 2>&1 && sudo -n docker ps >/dev/null 2>&1; then
        DOCKER_CMD="sudo docker"
    else
        log_error "Insufficient permissions. Need root, docker group membership, or sudo access."
        log_error "Add user to docker group: sudo usermod -aG docker \$USER"
        log_error "Or configure sudo for docker: echo '\$USER ALL=(ALL) NOPASSWD: /usr/bin/docker' | sudo tee /etc/sudoers.d/docker"
        exit 1
    fi
}

# Get current size of Loki data directory in GB
get_data_size() {
    if [ ! -d "$LOKI_DATA_DIR" ]; then
        echo "0"
        return
    fi
    du -sb "$LOKI_DATA_DIR" 2>/dev/null | awk '{printf "%.1f", $1/1024/1024/1024}'
}

# Check if Loki container is running
is_container_running() {
    $DOCKER_CMD ps --format "{{.Names}}" 2>/dev/null | grep -q "^${LOKI_CONTAINER}$" || return 1
}

# Stop Loki container
stop_loki() {
    log "Stopping Loki container: $LOKI_CONTAINER"
    if is_container_running; then
        if $DOCKER_CMD stop "$LOKI_CONTAINER" >/dev/null 2>&1; then
            log_success "Loki container stopped successfully"
            # Wait a bit for container to fully stop
            sleep 2
            return 0
        else
            log_error "Failed to stop Loki container"
            return 1
        fi
    else
        log_warning "Loki container $LOKI_CONTAINER is not running"
        return 0
    fi
}

# Start Loki container
start_loki() {
    log "Starting Loki container: $LOKI_CONTAINER"
    if $DOCKER_CMD start "$LOKI_CONTAINER" >/dev/null 2>&1; then
        log_success "Loki container started successfully"
        # Wait a bit for container to fully start
        sleep 3
        if is_container_running; then
            return 0
        else
            log_error "Container started but is not running"
            return 1
        fi
    else
        log_error "Failed to start Loki container"
        return 1
    fi
}

# Delete Loki data directory
delete_loki_data() {
    log "Deleting Loki data directory: $LOKI_DATA_DIR"
    if [ -d "$LOKI_DATA_DIR" ]; then
        # Remove all contents
        rm -rf "${LOKI_DATA_DIR:?}"/*
        # Remove directory itself if empty
        rmdir "$LOKI_DATA_DIR" 2>/dev/null || true
        log_success "Loki data directory deleted"
    else
        log_warning "Loki data directory does not exist"
    fi
}

# Create fresh Loki data directory
create_loki_data_dir() {
    log "Creating fresh Loki data dir: $LOKI_DATA_DIR with owner ${LOKI_USER}:${LOKI_GROUP}"
    mkdir -p "$LOKI_DATA_DIR"
    chown "${LOKI_USER}:${LOKI_GROUP}" "$LOKI_DATA_DIR"
    chmod 755 "$LOKI_DATA_DIR"
    log_success "Fresh Loki data directory created"
}

# Main execution
main() {
    log "Starting Loki safety trim. Threshold: ${THRESHOLD_GB} GB"
    log "Loki container: $LOKI_CONTAINER"
    log "Loki data dir : $LOKI_DATA_DIR"
    
    # Check permissions
    check_permissions
    
    # Get current size
    current_size=$(get_data_size)
    log "Current Loki data size: ${current_size} GB"
    
    # Check if threshold is exceeded (using awk for floating point comparison)
    if awk "BEGIN {exit !($current_size > $THRESHOLD_GB)}"; then
        log_warning "Size ${current_size} GB exceeds threshold ${THRESHOLD_GB} GB — performing emergency rotation."
        
        # Stop Loki container
        if ! stop_loki; then
            log_error "Failed to stop Loki container. Aborting rotation."
            exit 1
        fi
        
        # Delete old data (no backup)
        delete_loki_data
        
        # Create fresh directory
        create_loki_data_dir
        
        # Start Loki container
        if ! start_loki; then
            log_error "Failed to start Loki container after rotation."
            log_error "Please check Docker logs: $DOCKER_CMD logs $LOKI_CONTAINER"
            exit 1
        fi
        
        # Verify final size
        final_size=$(get_data_size)
        log "Final Loki data size: ${final_size} GB (should be near 0)."
        
        log_success "Rotation complete. Old data has been deleted."
    else
        log_success "Size ${current_size} GB is within threshold ${THRESHOLD_GB} GB. No action needed."
    fi
}

# Run main function
main "$@"
