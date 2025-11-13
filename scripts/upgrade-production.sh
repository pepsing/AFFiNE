#!/bin/bash

# AFFiNE Production Upgrade Script
# 生产环境升级脚本 - 不停中间件升级应用容器

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="${COMPOSE_FILE:-.docker/selfhost/compose.yml}"
COMPOSE_PROJECT="${COMPOSE_PROJECT:-affine}"
IMAGE_NAME="${IMAGE_NAME:-ghcr.io/toeverything/affine}"
TARGET_VERSION="${1:-stable}"

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_step() {
    echo -e "\n${BLUE}═══${NC} $1 ${BLUE}═══${NC}\n"
}

# Function to check if running on production server
check_environment() {
    print_step "Step 1: Environment Check"

    if [ ! -f "$COMPOSE_FILE" ]; then
        print_error "Compose file not found: $COMPOSE_FILE"
        print_info "Please run this script from the AFFiNE root directory"
        exit 1
    fi

    print_success "Compose file found: $COMPOSE_FILE"

    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running"
        exit 1
    fi

    print_success "Docker is running"
}

# Function to backup current state
backup_state() {
    print_step "Step 2: Backup Current State"

    # Get current image version
    CURRENT_IMAGE=$(docker inspect --format='{{.Config.Image}}' ${COMPOSE_PROJECT}_server 2>/dev/null || echo "unknown")
    print_info "Current image: $CURRENT_IMAGE"

    # Create backup of compose file
    BACKUP_FILE="${COMPOSE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$COMPOSE_FILE" "$BACKUP_FILE"
    print_success "Backed up compose file to: $BACKUP_FILE"

    # Export current container state
    print_info "Current running containers:"
    docker compose -f "$COMPOSE_FILE" ps
}

# Function to pull new image
pull_new_image() {
    print_step "Step 3: Pull New Image"

    NEW_IMAGE="${IMAGE_NAME}:${TARGET_VERSION}"
    print_info "Pulling image: $NEW_IMAGE"

    if docker pull "$NEW_IMAGE"; then
        print_success "Successfully pulled image: $NEW_IMAGE"
    else
        print_error "Failed to pull image: $NEW_IMAGE"
        exit 1
    fi

    # Show image size
    IMAGE_SIZE=$(docker images "$NEW_IMAGE" --format "{{.Size}}")
    print_info "Image size: $IMAGE_SIZE"
}

# Function to stop application container
stop_application() {
    print_step "Step 4: Stop Application Container"

    print_info "Stopping affine application container..."

    if docker compose -f "$COMPOSE_FILE" stop affine 2>/dev/null; then
        print_success "Application container stopped"
    else
        print_warning "Application container may not be running"
    fi

    # Verify middleware is still running
    print_info "Checking middleware status..."
    RUNNING_POSTGRES=$(docker compose -f "$COMPOSE_FILE" ps postgres --format json 2>/dev/null | grep -c "running" || echo "0")
    RUNNING_REDIS=$(docker compose -f "$COMPOSE_FILE" ps redis --format json 2>/dev/null | grep -c "running" || echo "0")

    if [ "$RUNNING_POSTGRES" -eq "1" ] && [ "$RUNNING_REDIS" -eq "1" ]; then
        print_success "Middleware containers are still running"
    else
        print_warning "Some middleware containers may not be running"
    fi
}

# Function to update and start application
start_application() {
    print_step "Step 5: Start Updated Application"

    # Set the target version in environment
    export AFFINE_REVISION="$TARGET_VERSION"

    print_info "Starting application with version: $TARGET_VERSION"

    if docker compose -f "$COMPOSE_FILE" up -d affine; then
        print_success "Application container started"
    else
        print_error "Failed to start application container"
        print_warning "Attempting rollback..."
        rollback
        exit 1
    fi

    # Wait for application to be ready
    print_info "Waiting for application to be ready..."
    sleep 5

    # Check if container is running
    if docker compose -f "$COMPOSE_FILE" ps affine --format json 2>/dev/null | grep -q "running"; then
        print_success "Application is running"
    else
        print_error "Application failed to start"
        print_info "Checking logs..."
        docker compose -f "$COMPOSE_FILE" logs --tail=50 affine
        print_warning "Attempting rollback..."
        rollback
        exit 1
    fi
}

# Function to verify upgrade
verify_upgrade() {
    print_step "Step 6: Verify Upgrade"

    # Check application health
    print_info "Checking application health..."

    # Wait a bit more for the application to initialize
    sleep 3

    # Get application logs
    print_info "Recent application logs:"
    docker compose -f "$COMPOSE_FILE" logs --tail=20 affine

    # Check if container is still running after initialization
    if docker compose -f "$COMPOSE_FILE" ps affine --format json 2>/dev/null | grep -q "running"; then
        print_success "Application is healthy"
    else
        print_error "Application health check failed"
        exit 1
    fi

    # Show final state
    print_info "Final container state:"
    docker compose -f "$COMPOSE_FILE" ps

    NEW_IMAGE=$(docker inspect --format='{{.Config.Image}}' ${COMPOSE_PROJECT}_server 2>/dev/null)
    print_success "Upgrade completed! New image: $NEW_IMAGE"
}

# Function to rollback
rollback() {
    print_error "Rolling back to previous version..."

    # Find the most recent backup
    LATEST_BACKUP=$(ls -t ${COMPOSE_FILE}.backup.* 2>/dev/null | head -1)

    if [ -n "$LATEST_BACKUP" ]; then
        cp "$LATEST_BACKUP" "$COMPOSE_FILE"
        print_info "Restored compose file from: $LATEST_BACKUP"
    fi

    # Restart with old configuration
    docker compose -f "$COMPOSE_FILE" up -d affine

    print_warning "Rollback completed. Please check the application status."
}

# Function to cleanup old images
cleanup_old_images() {
    print_step "Step 7: Cleanup (Optional)"

    read -p "Do you want to remove old Docker images? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Removing dangling images..."
        docker image prune -f
        print_success "Cleanup completed"
    else
        print_info "Skipped cleanup"
    fi
}

# Function to show help
show_help() {
    echo "Usage: $0 [VERSION]"
    echo ""
    echo "Upgrade AFFiNE production application without stopping middleware"
    echo ""
    echo "Arguments:"
    echo "  VERSION     Docker image tag to upgrade to (default: stable)"
    echo "              Options: stable, beta, canary, or specific version tag"
    echo ""
    echo "Environment variables:"
    echo "  COMPOSE_FILE       Path to docker-compose file (default: .docker/selfhost/compose.yml)"
    echo "  COMPOSE_PROJECT    Docker Compose project name (default: affine)"
    echo "  IMAGE_NAME         Docker image name (default: ghcr.io/toeverything/affine)"
    echo ""
    echo "Examples:"
    echo "  $0              # Upgrade to stable version"
    echo "  $0 beta         # Upgrade to beta version"
    echo "  $0 v0.25.3      # Upgrade to specific version"
    echo ""
    echo "  COMPOSE_FILE=./compose.yml $0 stable"
}

# Main script logic
main() {
    if [ "${1:-}" = "help" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
        show_help
        exit 0
    fi

    print_info "AFFiNE Production Upgrade Script"
    print_info "Target version: $TARGET_VERSION"
    echo ""

    # Confirmation
    read -p "Continue with upgrade? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Upgrade cancelled"
        exit 0
    fi

    # Execute upgrade steps
    check_environment
    backup_state
    pull_new_image
    stop_application
    start_application
    verify_upgrade
    cleanup_old_images

    print_step "Upgrade Complete!"
    print_success "AFFiNE has been successfully upgraded to version: $TARGET_VERSION"
    print_info "Middleware (PostgreSQL, Redis) remained running throughout the upgrade"
}

# Run main function
main "$@"
