#!/bin/bash

# AFFiNE Development Environment Switcher
# 环境切换脚本 - 在本地和远程环境之间快速切换

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the root directory of the project
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_DIR="$ROOT_DIR/packages/backend/server"
DOCKER_DEV_DIR="$ROOT_DIR/.docker/dev"

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

# Function to show current environment
show_current_env() {
    print_info "Current environment configuration:"

    if [ -L "$ENV_DIR/.env" ]; then
        LINK_TARGET=$(readlink "$ENV_DIR/.env")
        print_info "  .env is a symlink to: $LINK_TARGET"
    elif [ -f "$ENV_DIR/.env" ]; then
        print_info "  .env is a regular file"

        # Try to detect which env based on DATABASE_URL
        if grep -q "localhost:5432" "$ENV_DIR/.env" 2>/dev/null; then
            echo -e "  ${GREEN}Detected: LOCAL environment${NC}"
        else
            echo -e "  ${YELLOW}Detected: REMOTE environment${NC}"
        fi
    else
        print_warning "  .env file does not exist"
    fi

    echo ""
    print_info "Database URL:"
    grep "DATABASE_URL" "$ENV_DIR/.env" 2>/dev/null || echo "  (not found)"

    echo ""
    print_info "Redis Host:"
    grep "REDIS_SERVER_HOST" "$ENV_DIR/.env" 2>/dev/null || echo "  (not found)"
}

# Function to switch to local environment
switch_to_local() {
    print_info "Switching to LOCAL environment..."

    # Check if .env.local exists
    if [ ! -f "$ENV_DIR/.env.local" ]; then
        print_error ".env.local not found at $ENV_DIR/.env.local"
        exit 1
    fi

    # Backup current .env if it exists and is not a symlink
    if [ -f "$ENV_DIR/.env" ] && [ ! -L "$ENV_DIR/.env" ]; then
        BACKUP_FILE="$ENV_DIR/.env.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$ENV_DIR/.env" "$BACKUP_FILE"
        print_success "Backed up current .env to $(basename $BACKUP_FILE)"
    fi

    # Remove old .env
    rm -f "$ENV_DIR/.env"

    # Copy .env.local to .env
    cp "$ENV_DIR/.env.local" "$ENV_DIR/.env"
    print_success "Switched to LOCAL environment"

    echo ""
    print_info "Next steps:"
    echo "  1. Start local Docker middleware:"
    echo "     docker compose -f .docker/dev/compose.yml up -d"
    echo ""
    echo "  2. Start backend server:"
    echo "     yarn affine dev -p @affine/server"
}

# Function to switch to remote environment
switch_to_remote() {
    print_info "Switching to REMOTE environment..."

    # Check if .env.remote exists
    if [ ! -f "$ENV_DIR/.env.remote" ]; then
        print_error ".env.remote not found at $ENV_DIR/.env.remote"
        exit 1
    fi

    # Check if .env.remote has been configured
    if grep -q "YOUR_REMOTE_HOST" "$ENV_DIR/.env.remote"; then
        print_error ".env.remote has not been configured yet!"
        print_info "Please edit packages/backend/server/.env.remote and replace YOUR_REMOTE_HOST with actual values"
        exit 1
    fi

    # Backup current .env if it exists and is not a symlink
    if [ -f "$ENV_DIR/.env" ] && [ ! -L "$ENV_DIR/.env" ]; then
        BACKUP_FILE="$ENV_DIR/.env.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$ENV_DIR/.env" "$BACKUP_FILE"
        print_success "Backed up current .env to $(basename $BACKUP_FILE)"
    fi

    # Remove old .env
    rm -f "$ENV_DIR/.env"

    # Copy .env.remote to .env
    cp "$ENV_DIR/.env.remote" "$ENV_DIR/.env"
    print_success "Switched to REMOTE environment"

    echo ""
    print_warning "Make sure you have network access to the remote middleware (VPN, etc.)"

    echo ""
    print_info "Next steps:"
    echo "  1. (Optional) Stop local Docker middleware if running:"
    echo "     docker compose -f .docker/dev/compose.yml down"
    echo ""
    echo "  2. Start backend server (will connect to remote middleware):"
    echo "     yarn affine dev -p @affine/server"
}

# Function to show help
show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  local       Switch to local development environment"
    echo "  remote      Switch to remote test environment"
    echo "  status      Show current environment configuration"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 local    # Switch to local environment"
    echo "  $0 remote   # Switch to remote environment"
    echo "  $0 status   # Show current environment"
}

# Main script logic
case "${1:-}" in
    local)
        switch_to_local
        ;;
    remote)
        switch_to_remote
        ;;
    status)
        show_current_env
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Invalid command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
