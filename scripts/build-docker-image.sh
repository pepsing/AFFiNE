#!/bin/bash

# AFFiNE Docker Image Build Script
# 本地构建 Docker 镜像脚本 - 适用于内网部署

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_VERSION="${APP_VERSION:-$(date +%Y%m%d-%H%M%S)}"
IMAGE_NAME="${IMAGE_NAME:-affine-custom}"
IMAGE_TAG="${IMAGE_TAG:-${APP_VERSION}}"
REGISTRY="${REGISTRY:-}"  # 留空表示本地镜像，可设置为私有仓库地址
PLATFORM="${PLATFORM:-linux/amd64}"  # 目标平台
EXPORT_TAR="${EXPORT_TAR:-false}"    # 是否导出为 tar 文件

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

    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed"
        exit 1
    fi
    print_success "Node.js $(node --version)"

    # Check Yarn
    if ! command -v yarn &> /dev/null; then
        print_error "Yarn is not installed"
        exit 1
    fi
    print_success "Yarn $(yarn --version)"

    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    print_success "Docker $(docker --version)"

    # Check disk space (需要至少 10GB)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        AVAILABLE_SPACE=$(df -g . | awk 'NR==2 {print $4}')
        if [ "$AVAILABLE_SPACE" -lt 10 ]; then
            print_warning "Low disk space: ${AVAILABLE_SPACE}GB available"
        else
            print_success "Disk space: ${AVAILABLE_SPACE}GB available"
        fi
    fi
}

# Clean previous builds
clean_build() {
    print_step "Cleaning Previous Builds"

    print_info "Removing old build artifacts..."

    # Clean frontend builds
    rm -rf packages/frontend/apps/web/dist
    rm -rf packages/frontend/admin/dist
    rm -rf packages/frontend/apps/mobile/dist

    # Clean backend build
    rm -rf packages/backend/server/dist

    print_success "Cleaned previous builds"
}

# Build frontend
build_frontend() {
    print_step "Building Frontend"

    print_info "Building @affine/web..."
    yarn affine @affine/web build

    print_info "Building @affine/admin..."
    yarn affine @affine/admin build

    print_info "Building @affine/mobile..."
    yarn affine @affine/mobile build

    print_success "Frontend build completed"
}

# Build backend
build_backend() {
    print_step "Building Backend"

    print_info "Building @affine/reader..."
    yarn workspace @affine/reader build

    print_info "Building @affine/server..."
    yarn workspace @affine/server build

    print_success "Backend build completed"
}

# Prepare for Docker build
prepare_docker_context() {
    print_step "Preparing Docker Build Context"

    # Create temporary build directory
    BUILD_DIR=".docker-build"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"

    print_info "Copying backend files..."
    cp -r packages/backend/server "$BUILD_DIR/"

    print_info "Copying frontend dist..."
    cp -r packages/frontend/apps/web/dist "$BUILD_DIR/static"
    cp -r packages/frontend/admin/dist "$BUILD_DIR/static/admin"
    cp -r packages/frontend/apps/mobile/dist "$BUILD_DIR/static/mobile"

    # Install production dependencies
    print_info "Installing production dependencies..."
    cd "$BUILD_DIR/server"

    # Configure yarn for production
    yarn config set --json supportedArchitectures.cpu '["x64", "arm64"]'
    yarn config set --json supportedArchitectures.libc '["glibc"]'

    # Install dependencies (从根目录安装，然后移动)
    cd ../..
    yarn workspaces focus @affine/server --production

    print_info "Generating Prisma client..."
    yarn workspace @affine/server prisma generate

    # Move node_modules to build directory
    mv node_modules "$BUILD_DIR/server/"

    cd - > /dev/null

    print_success "Docker build context prepared"
}

# Create Dockerfile
create_dockerfile() {
    print_info "Creating Dockerfile..."

    cat > "$BUILD_DIR/Dockerfile" <<'EOF'
FROM node:22-bookworm-slim

COPY ./server /app
WORKDIR /app

RUN apt-get update && \
  apt-get install -y --no-install-recommends openssl libjemalloc2 && \
  rm -rf /var/lib/apt/lists/*

# Enable jemalloc by preloading the library
ENV LD_PRELOAD=libjemalloc.so.2

CMD ["node", "./dist/main.js"]
EOF

    print_success "Dockerfile created"
}

# Build Docker image
build_docker_image() {
    print_step "Building Docker Image"

    FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
    if [ -n "$REGISTRY" ]; then
        FULL_IMAGE_NAME="${REGISTRY}/${FULL_IMAGE_NAME}"
    fi

    print_info "Building image: $FULL_IMAGE_NAME"
    print_info "Platform: $PLATFORM"

    docker build \
        --platform "$PLATFORM" \
        -t "$FULL_IMAGE_NAME" \
        -f "$BUILD_DIR/Dockerfile" \
        "$BUILD_DIR"

    print_success "Docker image built: $FULL_IMAGE_NAME"

    # Tag as latest
    LATEST_TAG="${IMAGE_NAME}:latest"
    if [ -n "$REGISTRY" ]; then
        LATEST_TAG="${REGISTRY}/${LATEST_TAG}"
    fi
    docker tag "$FULL_IMAGE_NAME" "$LATEST_TAG"
    print_success "Tagged as: $LATEST_TAG"

    # Show image size
    IMAGE_SIZE=$(docker images "$FULL_IMAGE_NAME" --format "{{.Size}}")
    print_info "Image size: $IMAGE_SIZE"
}

# Export image to tar (for offline transfer)
export_image() {
    if [ "$EXPORT_TAR" = "true" ]; then
        print_step "Exporting Image to TAR"

        FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
        if [ -n "$REGISTRY" ]; then
            FULL_IMAGE_NAME="${REGISTRY}/${FULL_IMAGE_NAME}"
        fi

        EXPORT_FILE="affine-${IMAGE_TAG}.tar"
        print_info "Exporting to: $EXPORT_FILE"

        docker save -o "$EXPORT_FILE" "$FULL_IMAGE_NAME"

        # Compress
        print_info "Compressing..."
        gzip "$EXPORT_FILE"

        FINAL_FILE="${EXPORT_FILE}.gz"
        FILE_SIZE=$(du -h "$FINAL_FILE" | cut -f1)
        print_success "Exported to: $FINAL_FILE ($FILE_SIZE)"

        print_info "To import on production server:"
        echo "  gunzip $FINAL_FILE"
        echo "  docker load -i $EXPORT_FILE"
    fi
}

# Push to registry (if configured)
push_to_registry() {
    if [ -n "$REGISTRY" ]; then
        print_step "Pushing to Registry"

        FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
        FULL_IMAGE_NAME="${REGISTRY}/${FULL_IMAGE_NAME}"

        read -p "Push image to registry? (y/N): " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Pushing $FULL_IMAGE_NAME..."
            docker push "$FULL_IMAGE_NAME"

            LATEST_TAG="${REGISTRY}/${IMAGE_NAME}:latest"
            docker push "$LATEST_TAG"

            print_success "Image pushed to registry"
        else
            print_info "Skipped pushing to registry"
        fi
    fi
}

# Cleanup
cleanup() {
    print_step "Cleaning Up"

    print_info "Removing build directory..."
    rm -rf "$BUILD_DIR"

    print_success "Cleanup completed"
}

# Show summary
show_summary() {
    print_step "Build Complete!"

    FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
    if [ -n "$REGISTRY" ]; then
        FULL_IMAGE_NAME="${REGISTRY}/${FULL_IMAGE_NAME}"
    fi

    echo ""
    print_success "Docker image built successfully"
    echo ""
    print_info "Image Details:"
    echo "  Name: $FULL_IMAGE_NAME"
    echo "  Tag: $IMAGE_TAG"
    echo "  Platform: $PLATFORM"
    echo ""

    if [ "$EXPORT_TAR" = "true" ]; then
        print_info "Exported image file:"
        ls -lh affine-*.tar.gz 2>/dev/null || echo "  (not found)"
        echo ""
    fi

    print_info "Next Steps:"
    echo ""
    echo "  方式 1: 导出镜像并传输到生产服务器（适合内网）"
    echo "    本地执行: docker save $FULL_IMAGE_NAME | gzip > affine-image.tar.gz"
    echo "    传输文件: scp affine-image.tar.gz user@prod-server:/tmp/"
    echo "    远程导入: gunzip -c affine-image.tar.gz | docker load"
    echo ""
    echo "  方式 2: 推送到私有 Docker Registry（如果有）"
    echo "    docker push $FULL_IMAGE_NAME"
    echo ""
    echo "  方式 3: 直接在生产服务器上部署"
    echo "    使用 .docker/selfhost-split/deploy-app.sh"
    echo "    修改 compose-app.yml 中的镜像为: $FULL_IMAGE_NAME"
}

# Main script
main() {
    print_info "AFFiNE Docker Image Build Script"
    print_info "Version: $APP_VERSION"
    print_info "Platform: $PLATFORM"
    echo ""

    check_prerequisites
    clean_build
    build_frontend
    build_backend
    prepare_docker_context
    create_dockerfile
    build_docker_image
    export_image
    push_to_registry
    cleanup
    show_summary
}

# Show help
if [ "${1:-}" = "help" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Usage: $0"
    echo ""
    echo "Build AFFiNE Docker image from source"
    echo ""
    echo "Environment variables:"
    echo "  APP_VERSION       Version tag (default: YYYYmmdd-HHMMSS)"
    echo "  IMAGE_NAME        Image name (default: affine-custom)"
    echo "  IMAGE_TAG         Image tag (default: APP_VERSION)"
    echo "  REGISTRY          Docker registry URL (default: empty, local only)"
    echo "  PLATFORM          Target platform (default: linux/amd64)"
    echo "  EXPORT_TAR        Export as tar.gz (default: false)"
    echo ""
    echo "Examples:"
    echo "  $0                                      # Build with defaults"
    echo "  IMAGE_TAG=v1.0.0 $0                     # Build with custom tag"
    echo "  PLATFORM=linux/arm64 $0                 # Build for ARM64"
    echo "  EXPORT_TAR=true $0                      # Build and export as tar"
    echo "  REGISTRY=registry.example.com:5000 $0   # Build and push to registry"
    exit 0
fi

# Run main function
main "$@"
