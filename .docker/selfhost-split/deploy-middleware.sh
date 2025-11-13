#!/bin/bash

# AFFiNE Middleware Deployment Script
# 中间件部署脚本

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-.env.middleware.local}"

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

    # Check if running as root (for port binding)
    if [ "$EUID" -eq 0 ]; then
        print_warning "Running as root. This is not recommended for security."
    fi
}

# Setup configuration
setup_config() {
    print_step "Setting Up Configuration"

    cd "$SCRIPT_DIR"

    if [ ! -f "$ENV_FILE" ]; then
        if [ -f ".env.middleware" ]; then
            print_info "Creating $ENV_FILE from template..."
            cp .env.middleware "$ENV_FILE"
            print_success "Created $ENV_FILE"
            print_warning "Please edit $ENV_FILE and set secure passwords!"
            read -p "Press Enter to edit now, or Ctrl+C to exit and edit manually..."
            ${EDITOR:-vi} "$ENV_FILE"
        else
            print_error "Template file .env.middleware not found"
            exit 1
        fi
    else
        print_success "Using existing $ENV_FILE"
    fi

    # Check if password is still default
    if grep -q "your_secure_password_here" "$ENV_FILE"; then
        print_error "Please change the default password in $ENV_FILE"
        exit 1
    fi
}

# Create data directories
create_directories() {
    print_step "Creating Data Directories"

    cd "$SCRIPT_DIR"

    # Read data locations from env file
    source "$ENV_FILE"

    mkdir -p "${DB_DATA_LOCATION:-./data/postgres}"
    print_success "Created PostgreSQL data directory"

    mkdir -p "${REDIS_DATA_LOCATION:-./data/redis}"
    print_success "Created Redis data directory"

    mkdir -p "${MAILPIT_DATA_LOCATION:-./data/mailpit}"
    print_success "Created Mailpit data directory"

    mkdir -p "${MANTICORE_DATA_LOCATION:-./data/manticore}"
    print_success "Created Manticoresearch data directory"
}

# Deploy middleware
deploy() {
    print_step "Deploying Middleware"

    cd "$SCRIPT_DIR"

    print_info "Pulling Docker images..."
    docker compose -f compose-middleware.yml --env-file "$ENV_FILE" pull

    print_info "Starting middleware services..."
    docker compose -f compose-middleware.yml --env-file "$ENV_FILE" up -d

    print_success "Middleware services started"
}

# Verify deployment
verify() {
    print_step "Verifying Deployment"

    cd "$SCRIPT_DIR"

    sleep 5

    print_info "Checking service status..."
    docker compose -f compose-middleware.yml ps

    # Check PostgreSQL
    if docker compose -f compose-middleware.yml ps postgres | grep -q "Up"; then
        print_success "PostgreSQL is running"
    else
        print_error "PostgreSQL is not running"
    fi

    # Check Redis
    if docker compose -f compose-middleware.yml ps redis | grep -q "Up"; then
        print_success "Redis is running"
    else
        print_error "Redis is not running"
    fi
}

# Show next steps
show_next_steps() {
    print_step "Deployment Complete!"

    source "$ENV_FILE"

    echo ""
    print_success "Middleware services are now running"
    echo ""
    print_info "Service Endpoints:"
    echo "  - PostgreSQL: localhost:${DB_PORT:-5432}"
    echo "  - Redis: localhost:${REDIS_PORT:-6379}"
    echo "  - Mailpit Web UI: http://localhost:${MAILPIT_WEB_PORT:-8025}"
    echo "  - Manticoresearch: localhost:${MANTICORE_PORT:-9308}"
    echo ""
    print_info "Next Steps:"
    echo "  1. Test database connection:"
    echo "     docker exec affine_postgres psql -U ${DB_USERNAME:-affine} -d ${DB_DATABASE:-affine}"
    echo ""
    echo "  2. Configure firewall to allow application server access:"
    echo "     sudo ufw allow from <APP_SERVER_IP> to any port ${DB_PORT:-5432}"
    echo "     sudo ufw allow from <APP_SERVER_IP> to any port ${REDIS_PORT:-6379}"
    echo ""
    echo "  3. Deploy application on application server"
    echo ""
    print_info "Useful Commands:"
    echo "  - View logs: docker compose -f compose-middleware.yml logs -f"
    echo "  - Stop services: docker compose -f compose-middleware.yml down"
    echo "  - Restart services: docker compose -f compose-middleware.yml restart"
}

# Main script
main() {
    print_info "AFFiNE Middleware Deployment Script"
    echo ""

    check_prerequisites
    setup_config
    create_directories
    deploy
    verify
    show_next_steps
}

# Run main function
main "$@"
