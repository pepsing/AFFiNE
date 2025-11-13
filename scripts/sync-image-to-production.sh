#!/bin/bash

# Sync Docker Image to Production Server
# 同步 Docker 镜像到生产服务器

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="${IMAGE_NAME:-affine-custom}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
PROD_SERVER="${PROD_SERVER:-}"
PROD_USER="${PROD_USER:-root}"
SSH_PORT="${SSH_PORT:-22}"
METHOD="${METHOD:-auto}"  # auto, tar, registry

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

    if [ -z "$PROD_SERVER" ]; then
        print_error "PROD_SERVER not set"
        print_info "Usage: PROD_SERVER=192.168.1.100 $0"
        exit 1
    fi

    print_success "Production server: $PROD_SERVER"

    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi

    # Check SSH connection
    print_info "Testing SSH connection..."
    if ssh -p "$SSH_PORT" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$PROD_USER@$PROD_SERVER" "echo ok" > /dev/null 2>&1; then
        print_success "SSH connection OK"
    else
        print_error "Cannot connect to production server via SSH"
        print_info "Please check:"
        echo "  - Server address: $PROD_SERVER"
        echo "  - SSH port: $SSH_PORT"
        echo "  - User: $PROD_USER"
        echo "  - SSH key authentication"
        exit 1
    fi

    # Check if image exists locally
    FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
    if ! docker inspect "$FULL_IMAGE_NAME" > /dev/null 2>&1; then
        print_error "Image not found locally: $FULL_IMAGE_NAME"
        print_info "Please build the image first:"
        echo "  ./scripts/build-docker-image.sh"
        exit 1
    fi
    print_success "Image found: $FULL_IMAGE_NAME"
}

# Detect best method
detect_method() {
    if [ "$METHOD" = "auto" ]; then
        print_step "Detecting Best Sync Method"

        # Check if production server has Docker
        if ssh -p "$SSH_PORT" "$PROD_USER@$PROD_SERVER" "command -v docker" > /dev/null 2>&1; then
            print_success "Production server has Docker"
            METHOD="tar"
        else
            print_error "Production server doesn't have Docker"
            exit 1
        fi

        print_info "Selected method: $METHOD"
    fi
}

# Sync via tar file (recommended for private network)
sync_via_tar() {
    print_step "Syncing via TAR File"

    FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
    TAR_FILE="affine-image-${IMAGE_TAG}.tar"
    TAR_GZ_FILE="${TAR_FILE}.gz"

    # Export image
    print_info "Exporting image to tar..."
    docker save "$FULL_IMAGE_NAME" -o "$TAR_FILE"
    print_success "Exported to $TAR_FILE"

    # Compress
    print_info "Compressing..."
    gzip -f "$TAR_FILE"
    FILE_SIZE=$(du -h "$TAR_GZ_FILE" | cut -f1)
    print_success "Compressed to $TAR_GZ_FILE ($FILE_SIZE)"

    # Transfer to production server
    print_info "Transferring to production server..."
    scp -P "$SSH_PORT" -o StrictHostKeyChecking=no "$TAR_GZ_FILE" "$PROD_USER@$PROD_SERVER:/tmp/"
    print_success "Transfer completed"

    # Load image on production server
    print_info "Loading image on production server..."
    ssh -p "$SSH_PORT" "$PROD_USER@$PROD_SERVER" << EOF
set -e
cd /tmp
echo "Decompressing..."
gunzip -f $TAR_GZ_FILE
echo "Loading Docker image..."
docker load -i $TAR_FILE
echo "Cleaning up..."
rm -f $TAR_FILE
echo "Image loaded successfully"
EOF

    print_success "Image loaded on production server"

    # Cleanup local file
    print_info "Cleaning up local files..."
    rm -f "$TAR_GZ_FILE"
    print_success "Cleanup completed"
}

# Sync via Docker registry (if available)
sync_via_registry() {
    print_step "Syncing via Docker Registry"

    if [ -z "$REGISTRY" ]; then
        print_error "REGISTRY not set"
        print_info "Usage: REGISTRY=registry.example.com:5000 $0"
        exit 1
    fi

    FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
    REGISTRY_IMAGE="${REGISTRY}/${FULL_IMAGE_NAME}"

    # Tag for registry
    print_info "Tagging image for registry..."
    docker tag "$FULL_IMAGE_NAME" "$REGISTRY_IMAGE"

    # Push to registry
    print_info "Pushing to registry..."
    docker push "$REGISTRY_IMAGE"
    print_success "Pushed to registry: $REGISTRY_IMAGE"

    # Pull on production server
    print_info "Pulling on production server..."
    ssh -p "$SSH_PORT" "$PROD_USER@$PROD_SERVER" << EOF
set -e
echo "Pulling image from registry..."
docker pull $REGISTRY_IMAGE
echo "Tagging as local image..."
docker tag $REGISTRY_IMAGE $FULL_IMAGE_NAME
echo "Image pulled successfully"
EOF

    print_success "Image available on production server"
}

# Verify on production
verify_on_production() {
    print_step "Verifying on Production Server"

    FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

    print_info "Checking image on production server..."

    if ssh -p "$SSH_PORT" "$PROD_USER@$PROD_SERVER" "docker inspect $FULL_IMAGE_NAME" > /dev/null 2>&1; then
        print_success "Image verified on production server"

        # Show image details
        print_info "Image details:"
        ssh -p "$SSH_PORT" "$PROD_USER@$PROD_SERVER" "docker images $FULL_IMAGE_NAME --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}'"
    else
        print_error "Image not found on production server"
        exit 1
    fi
}

# Show next steps
show_next_steps() {
    print_step "Sync Complete!"

    FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

    echo ""
    print_success "Image successfully synced to production server"
    echo ""
    print_info "Next Steps:"
    echo ""
    echo "  1. SSH 到生产服务器："
    echo "     ssh -p $SSH_PORT $PROD_USER@$PROD_SERVER"
    echo ""
    echo "  2. 更新应用配置（如果使用分离部署）："
    echo "     cd /path/to/affine/.docker/selfhost-split"
    echo "     vi compose-app.yml"
    echo "     # 修改 image: 为 $FULL_IMAGE_NAME"
    echo ""
    echo "  3. 部署/升级应用："
    echo "     # 方式1: 使用部署脚本"
    echo "     ./deploy-app.sh"
    echo ""
    echo "     # 方式2: 使用 Docker Compose"
    echo "     docker compose -f compose-app.yml up -d"
    echo ""
    echo "     # 方式3: 使用升级脚本"
    echo "     ../../scripts/upgrade-production.sh"
    echo ""
    echo "  4. 验证部署："
    echo "     curl http://localhost:3010/api/healthz"
}

# Main script
main() {
    print_info "Docker Image Sync Script"
    print_info "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
    print_info "Target: $PROD_USER@$PROD_SERVER:$SSH_PORT"
    echo ""

    check_prerequisites
    detect_method

    case "$METHOD" in
        tar)
            sync_via_tar
            ;;
        registry)
            sync_via_registry
            ;;
        *)
            print_error "Unknown method: $METHOD"
            exit 1
            ;;
    esac

    verify_on_production
    show_next_steps
}

# Show help
if [ "${1:-}" = "help" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Usage: PROD_SERVER=<server> $0"
    echo ""
    echo "Sync Docker image to production server"
    echo ""
    echo "Required environment variables:"
    echo "  PROD_SERVER       Production server IP or hostname"
    echo ""
    echo "Optional environment variables:"
    echo "  IMAGE_NAME        Image name (default: affine-custom)"
    echo "  IMAGE_TAG         Image tag (default: latest)"
    echo "  PROD_USER         SSH user (default: root)"
    echo "  SSH_PORT          SSH port (default: 22)"
    echo "  METHOD            Sync method: auto, tar, registry (default: auto)"
    echo "  REGISTRY          Docker registry URL (required for registry method)"
    echo ""
    echo "Examples:"
    echo "  # Sync via tar (recommended for private network)"
    echo "  PROD_SERVER=192.168.1.100 $0"
    echo ""
    echo "  # Sync with custom SSH port and user"
    echo "  PROD_SERVER=192.168.1.100 PROD_USER=deploy SSH_PORT=2222 $0"
    echo ""
    echo "  # Sync via Docker registry"
    echo "  PROD_SERVER=192.168.1.100 METHOD=registry REGISTRY=registry.local:5000 $0"
    echo ""
    echo "  # Sync specific image version"
    echo "  PROD_SERVER=192.168.1.100 IMAGE_TAG=v1.0.0 $0"
    exit 0
fi

# Run main function
main "$@"
