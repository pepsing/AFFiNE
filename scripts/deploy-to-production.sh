#!/bin/bash

# One-Click Deploy to Production
# 一键构建并部署到生产环境

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROD_SERVER="${PROD_SERVER:-}"
PROD_USER="${PROD_USER:-root}"
SSH_PORT="${SSH_PORT:-22}"
IMAGE_TAG="${IMAGE_TAG:-$(date +%Y%m%d-%H%M%S)}"
SKIP_BUILD="${SKIP_BUILD:-false}"
SKIP_SYNC="${SKIP_SYNC:-false}"

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

# Show banner
show_banner() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║      AFFiNE One-Click Production Deployment               ║"
    echo "║      从本地构建到生产部署的完整流程                         ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    print_step "Checking Prerequisites"

    if [ -z "$PROD_SERVER" ]; then
        print_error "PROD_SERVER not set"
        print_info "Usage: PROD_SERVER=192.168.1.100 $0"
        exit 1
    fi

    print_info "Configuration:"
    echo "  Production Server: $PROD_SERVER"
    echo "  SSH User: $PROD_USER"
    echo "  SSH Port: $SSH_PORT"
    echo "  Image Tag: $IMAGE_TAG"
    echo "  Skip Build: $SKIP_BUILD"
    echo "  Skip Sync: $SKIP_SYNC"
    echo ""

    read -p "Continue with deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Deployment cancelled"
        exit 0
    fi
}

# Build Docker image
build_image() {
    if [ "$SKIP_BUILD" = "true" ]; then
        print_step "Skipping Build (SKIP_BUILD=true)"
        return
    fi

    print_step "Building Docker Image"

    print_info "Starting build process..."

    IMAGE_TAG="$IMAGE_TAG" \
    PLATFORM="linux/amd64" \
    "$SCRIPT_DIR/build-docker-image.sh"

    print_success "Build completed"
}

# Sync image to production
sync_image() {
    if [ "$SKIP_SYNC" = "true" ]; then
        print_step "Skipping Sync (SKIP_SYNC=true)"
        return
    fi

    print_step "Syncing Image to Production"

    print_info "Starting sync process..."

    PROD_SERVER="$PROD_SERVER" \
    PROD_USER="$PROD_USER" \
    SSH_PORT="$SSH_PORT" \
    IMAGE_TAG="$IMAGE_TAG" \
    "$SCRIPT_DIR/sync-image-to-production.sh"

    print_success "Sync completed"
}

# Deploy on production server
deploy_on_production() {
    print_step "Deploying on Production Server"

    print_info "Connecting to production server..."

    # Check if deployment directory exists
    DEPLOY_DIR="/opt/affine"
    print_info "Checking deployment directory..."

    ssh -p "$SSH_PORT" "$PROD_USER@$PROD_SERVER" << EOF
set -e

if [ ! -d "$DEPLOY_DIR" ]; then
    echo "Creating deployment directory: $DEPLOY_DIR"
    mkdir -p $DEPLOY_DIR
    cd $DEPLOY_DIR

    # TODO: Copy deployment files from repo
    echo "Please manually copy .docker/selfhost-split files to $DEPLOY_DIR"
else
    echo "Deployment directory exists: $DEPLOY_DIR"
fi

cd $DEPLOY_DIR

# Check if using split deployment
if [ -f ".docker/selfhost-split/compose-app.yml" ]; then
    cd .docker/selfhost-split

    echo "Updating image in compose file..."
    sed -i.bak "s|image:.*affine.*|image: affine-custom:$IMAGE_TAG|g" compose-app.yml

    echo "Deploying application..."
    docker compose -f compose-app.yml up -d

    echo "Waiting for application to start..."
    sleep 10

    echo "Checking application health..."
    docker compose -f compose-app.yml ps

    if curl -f -s http://localhost:3010/api/healthz > /dev/null; then
        echo "✓ Application is healthy"
    else
        echo "⚠ Application health check failed (may need more time)"
    fi
else
    echo "⚠ Split deployment files not found"
    echo "Please setup deployment configuration first"
    exit 1
fi
EOF

    print_success "Deployment completed"
}

# Verify deployment
verify_deployment() {
    print_step "Verifying Deployment"

    print_info "Running health checks..."

    # Check if application is responding
    if ssh -p "$SSH_PORT" "$PROD_USER@$PROD_SERVER" "curl -f -s http://localhost:3010/api/healthz" > /dev/null 2>&1; then
        print_success "Application health check passed"
    else
        print_warning "Application health check failed"
        print_info "Please check logs:"
        echo "  ssh $PROD_USER@$PROD_SERVER 'cd /opt/affine/.docker/selfhost-split && docker compose -f compose-app.yml logs affine'"
    fi

    # Show running containers
    print_info "Running containers:"
    ssh -p "$SSH_PORT" "$PROD_USER@$PROD_SERVER" "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep affine"
}

# Show summary
show_summary() {
    print_step "Deployment Summary"

    echo ""
    print_success "Deployment completed successfully!"
    echo ""
    print_info "Deployment Details:"
    echo "  Server: $PROD_SERVER"
    echo "  Image: affine-custom:$IMAGE_TAG"
    echo "  Application URL: http://$PROD_SERVER:3010"
    echo ""
    print_info "Useful Commands:"
    echo "  # View logs"
    echo "  ssh $PROD_USER@$PROD_SERVER 'docker logs affine_server'"
    echo ""
    echo "  # Restart application"
    echo "  ssh $PROD_USER@$PROD_SERVER 'docker restart affine_server'"
    echo ""
    echo "  # Access shell"
    echo "  ssh -p $SSH_PORT $PROD_USER@$PROD_SERVER"
    echo ""
    echo "  # Rollback (if needed)"
    echo "  ssh $PROD_USER@$PROD_SERVER 'cd /opt/affine/.docker/selfhost-split && docker compose -f compose-app.yml down && docker compose -f compose-app.yml up -d'"
}

# Main script
main() {
    show_banner
    check_prerequisites
    build_image
    sync_image
    deploy_on_production
    verify_deployment
    show_summary
}

# Show help
if [ "${1:-}" = "help" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Usage: PROD_SERVER=<server> $0"
    echo ""
    echo "One-click build and deploy to production"
    echo ""
    echo "Required environment variables:"
    echo "  PROD_SERVER       Production server IP or hostname"
    echo ""
    echo "Optional environment variables:"
    echo "  PROD_USER         SSH user (default: root)"
    echo "  SSH_PORT          SSH port (default: 22)"
    echo "  IMAGE_TAG         Image tag (default: YYYYmmdd-HHMMSS)"
    echo "  SKIP_BUILD        Skip build step (default: false)"
    echo "  SKIP_SYNC         Skip sync step (default: false)"
    echo ""
    echo "Examples:"
    echo "  # Full deployment"
    echo "  PROD_SERVER=192.168.1.100 $0"
    echo ""
    echo "  # Only sync and deploy (skip build)"
    echo "  PROD_SERVER=192.168.1.100 SKIP_BUILD=true $0"
    echo ""
    echo "  # Build and sync only (skip deploy)"
    echo "  PROD_SERVER=192.168.1.100 SKIP_DEPLOY=true $0"
    echo ""
    echo "  # Custom SSH settings"
    echo "  PROD_SERVER=192.168.1.100 PROD_USER=deploy SSH_PORT=2222 $0"
    exit 0
fi

# Run main function
main "$@"
