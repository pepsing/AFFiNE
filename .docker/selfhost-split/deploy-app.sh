#!/bin/bash

# AFFiNE Application Deployment Script
# 应用部署脚本

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-.env.app.local}"

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

# Check prerequisites
check_prerequisites() {
    print_step "Checking Prerequisites"

    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    print_success "Docker is installed"

    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed"
        exit 1
    fi
    print_success "Docker Compose is installed"
}

# Setup configuration
setup_config() {
    print_step "Setting Up Configuration"

    cd "$SCRIPT_DIR"

    if [ ! -f "$ENV_FILE" ]; then
        if [ -f ".env.app" ]; then
            print_info "Creating $ENV_FILE from template..."
            cp .env.app "$ENV_FILE"
            print_success "Created $ENV_FILE"
            print_warning "Please edit $ENV_FILE and configure middleware connection!"
            read -p "Press Enter to edit now, or Ctrl+C to exit and edit manually..."
            ${EDITOR:-vi} "$ENV_FILE"
        else
            print_error "Template file .env.app not found"
            exit 1
        fi
    else
        print_success "Using existing $ENV_FILE"
    fi

    # Check if configuration is still default
    if grep -q "192.168.1.100" "$ENV_FILE"; then
        print_warning "Middleware host is still set to 192.168.1.100"
        print_warning "Please update DB_HOST and REDIS_SERVER_HOST to actual middleware server address"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Test middleware connection
test_middleware() {
    print_step "Testing Middleware Connection"

    cd "$SCRIPT_DIR"
    source "$ENV_FILE"

    # Test PostgreSQL
    print_info "Testing PostgreSQL connection to $DB_HOST:${DB_PORT:-5432}..."
    if nc -zv -w5 "$DB_HOST" "${DB_PORT:-5432}" 2>&1 | grep -q "succeeded\|open"; then
        print_success "PostgreSQL is reachable"
    else
        print_error "Cannot connect to PostgreSQL at $DB_HOST:${DB_PORT:-5432}"
        print_info "Please check:"
        echo "  1. Middleware server is running"
        echo "  2. Firewall allows connection from this server"
        echo "  3. DB_HOST is correct in $ENV_FILE"
        exit 1
    fi

    # Test Redis
    print_info "Testing Redis connection to $REDIS_SERVER_HOST:${REDIS_SERVER_PORT:-6379}..."
    if nc -zv -w5 "$REDIS_SERVER_HOST" "${REDIS_SERVER_PORT:-6379}" 2>&1 | grep -q "succeeded\|open"; then
        print_success "Redis is reachable"
    else
        print_error "Cannot connect to Redis at $REDIS_SERVER_HOST:${REDIS_SERVER_PORT:-6379}"
        print_info "Please check:"
        echo "  1. Middleware server is running"
        echo "  2. Firewall allows connection from this server"
        echo "  3. REDIS_SERVER_HOST is correct in $ENV_FILE"
        exit 1
    fi
}

# Create data directories
create_directories() {
    print_step "Creating Data Directories"

    cd "$SCRIPT_DIR"
    source "$ENV_FILE"

    mkdir -p "${UPLOAD_LOCATION:-./data/storage}"
    print_success "Created storage directory"

    mkdir -p "${CONFIG_LOCATION:-./data/config}"
    print_success "Created config directory"
}

# Deploy application
deploy() {
    print_step "Deploying Application"

    cd "$SCRIPT_DIR"

    print_info "Pulling Docker images..."
    docker compose -f compose-app.yml --env-file "$ENV_FILE" pull

    print_info "Starting application services..."
    docker compose -f compose-app.yml --env-file "$ENV_FILE" up -d

    print_success "Application services started"
}

# Verify deployment
verify() {
    print_step "Verifying Deployment"

    cd "$SCRIPT_DIR"

    print_info "Waiting for application to start..."
    sleep 10

    print_info "Checking service status..."
    docker compose -f compose-app.yml ps

    # Check application
    if docker compose -f compose-app.yml ps affine | grep -q "Up"; then
        print_success "Application is running"
    else
        print_error "Application is not running"
        print_info "Checking logs..."
        docker compose -f compose-app.yml logs --tail=30 affine
        exit 1
    fi

    # Test health endpoint
    print_info "Testing health endpoint..."
    sleep 5
    if curl -f -s http://localhost:${PORT:-3010}/api/healthz > /dev/null; then
        print_success "Application health check passed"
    else
        print_warning "Application health check failed (may need more time to initialize)"
    fi
}

# Show next steps
show_next_steps() {
    print_step "Deployment Complete!"

    source "$ENV_FILE"

    echo ""
    print_success "Application is now running"
    echo ""
    print_info "Service Information:"
    echo "  - Application URL: http://localhost:${PORT:-3010}"
    echo "  - Health Check: http://localhost:${PORT:-3010}/api/healthz"
    echo ""
    print_info "Next Steps:"
    echo "  1. Test application:"
    echo "     curl http://localhost:${PORT:-3010}/api/healthz"
    echo ""
    echo "  2. Setup reverse proxy (Nginx/Caddy) for HTTPS"
    echo ""
    echo "  3. Configure domain and SSL certificates"
    echo ""
    print_info "Useful Commands:"
    echo "  - View logs: docker compose -f compose-app.yml logs -f affine"
    echo "  - Stop application: docker compose -f compose-app.yml down"
    echo "  - Restart application: docker compose -f compose-app.yml restart affine"
    echo "  - Upgrade: ../../scripts/upgrade-production.sh stable"
}

# Main script
main() {
    print_info "AFFiNE Application Deployment Script"
    echo ""

    check_prerequisites
    setup_config
    test_middleware
    create_directories
    deploy
    verify
    show_next_steps
}

# Run main function
main "$@"
