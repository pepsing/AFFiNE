#!/bin/bash
# AFFiNE ARM64 Docker 构建脚本
# 适用于 macOS Apple Silicon 环境

set -e  # 遇到错误时停止

echo "🚀 开始构建 AFFiNE ARM64 Docker 镜像..."

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${GREEN}[步骤] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[警告] $1${NC}"
}

print_error() {
    echo -e "${RED}[错误] $1${NC}"
}

# 检查必要工具
print_step "检查环境依赖..."
command -v docker >/dev/null 2>&1 || { print_error "需要安装 Docker"; exit 1; }
command -v yarn >/dev/null 2>&1 || { print_error "需要安装 Yarn"; exit 1; }
command -v node >/dev/null 2>&1 || { print_error "需要安装 Node.js"; exit 1; }

# 第一步：清理环境
print_step "清理已有环境..."
docker compose -f docker-compose.custom.yml down -v 2>/dev/null || true
docker rmi affine-backend:custom 2>/dev/null || true

print_step "清理 node_modules 和构建缓存..."
rm -rf node_modules packages/*/node_modules packages/*/*/node_modules 2>/dev/null || true
rm -rf packages/frontend/core/.next 2>/dev/null || true
rm -rf packages/backend/server/dist 2>/dev/null || true

# 第二步：安装 Rust (如果需要)
if ! command -v rustc >/dev/null 2>&1; then
    print_step "安装 Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source ~/.cargo/env
else
    print_step "Rust 已安装，版本: $(rustc --version)"
fi

# 第三步：安装项目依赖
print_step "安装项目依赖..."
yarn install

# 第四步：下载 ARM64 Linux native modules（从 npm registry）
print_step "下载 ARM64 Linux native modules..."

# 创建目录并下载 argon2 (Linux ARM64)
mkdir -p node_modules/@node-rs/argon2
cd node_modules/@node-rs/argon2
if [ ! -f argon2.linux-arm64-gnu.node ]; then
    print_step "下载 argon2.linux-arm64-gnu.node (Linux ARM64)..."
    TMP_DIR=$(mktemp -d)
    curl -sSL "https://registry.npmjs.org/@node-rs/argon2-linux-arm64-gnu/-/argon2-linux-arm64-gnu-2.0.2.tgz" | tar -xz -C "$TMP_DIR"
    cp "$TMP_DIR/package/argon2.linux-arm64-gnu.node" ./argon2.linux-arm64-gnu.node
    rm -rf "$TMP_DIR"
    echo "✅ argon2 模块下载完成"
else
    echo "✅ argon2 模块已存在"
fi

# 创建目录并下载 crc32 (Linux ARM64)
mkdir -p ../crc32
cd ../crc32
if [ ! -f crc32.linux-arm64-gnu.node ]; then
    print_step "下载 crc32.linux-arm64-gnu.node (Linux ARM64)..."
    TMP_DIR=$(mktemp -d)
    curl -sSL "https://registry.npmjs.org/@node-rs/crc32-linux-arm64-gnu/-/crc32-linux-arm64-gnu-1.10.6.tgz" | tar -xz -C "$TMP_DIR"
    cp "$TMP_DIR/package/crc32.linux-arm64-gnu.node" ./crc32.linux-arm64-gnu.node
    rm -rf "$TMP_DIR"
    echo "✅ crc32 模块下载完成"
else
    echo "✅ crc32 模块已存在"
fi

cd ../../..

# 第五步：构建前端（使用本地静态资源路径，静态文件由后端容器提供）
print_step "构建前端应用（web / admin / mobile）..."
export PUBLIC_PATH="/"
yarn build --package @affine/web
yarn build --package @affine/admin
yarn build --package @affine/mobile
echo "✅ 前端构建完成（静态资源已输出到 packages/frontend/apps/*/dist，将在后端镜像中作为 /static 提供）"

# 第六步：在 Linux 容器内编译 Rust native module
print_step "在 Linux 容器内编译 server-native..."
print_warning "这一步可能需要几分钟时间，请耐心等待..."

docker run --rm -v "$(pwd)":/workspace -w /workspace/packages/backend/native \
  node:22-bookworm-slim bash -c "
  apt-get update && apt-get install -y curl build-essential &&
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y &&
  source ~/.cargo/env &&
  rustup install 1.87.0 &&
  rustup default 1.87.0 &&
  npm run build"

# 验证生成的文件
if [ -f packages/backend/native/server-native.arm64.node ]; then
    FILE_TYPE=$(file packages/backend/native/server-native.arm64.node)
    if echo "$FILE_TYPE" | grep -q "ELF"; then
        echo "✅ server-native.arm64.node 生成成功 (ELF 格式)"
    else
        print_error "server-native.arm64.node 格式不正确: $FILE_TYPE"
        exit 1
    fi
else
    print_error "server-native.arm64.node 生成失败"
    exit 1
fi

# 第七步：构建后端
print_step "构建后端..."
yarn build --package @affine/server
print_step "构建后端 Docker 镜像..."
docker build -f Dockerfile.backend.custom -t affine-backend:custom .
echo "✅ 后端镜像构建完成"

# 第八步：验证镜像
print_step "验证构建的镜像..."
docker images | grep affine

# 第九步：启动服务
print_step "启动 Docker 服务..."
docker compose -f docker-compose.custom.yml up -d

# 等待服务启动
print_step "等待服务启动..."
sleep 10

# 第十步：验证服务
print_step "验证服务状态..."
echo ""
echo "🔍 服务状态检查:"

# 检查应用（前端 + 后端）
if curl -s -f http://localhost:3010 > /dev/null; then
    echo "✅ 应用入口: http://localhost:3010 - 正常"
else
    echo "❌ 应用入口: http://localhost:3010 - 异常"
fi

# 检查健康检查接口
if curl -s -f http://localhost:3010/api/healthz > /dev/null; then
    echo "✅ 健康检查: http://localhost:3010/api/healthz - 正常（200 或 302）"
else
    echo "❌ 健康检查: http://localhost:3010/api/healthz - 异常"
fi

echo ""
print_step "显示容器状态..."
docker compose -f docker-compose.custom.yml ps

echo ""
echo "🎉 AFFiNE ARM64 Docker 环境构建完成!"
echo ""
echo "📋 访问信息:"
echo "  - 应用入口（前端 + 后端）: http://localhost:3010"
echo "  - 管理后台: http://localhost:3010/admin"
echo "  - 健康检查: http://localhost:3010/api/healthz"
echo ""
echo "📝 管理命令:"
echo "  - 停止服务: docker compose -f docker-compose.custom.yml stop"
echo "  - 启动服务: docker compose -f docker-compose.custom.yml start"
echo "  - 查看日志: docker compose -f docker-compose.custom.yml logs -f"
echo "  - 清理环境: docker compose -f docker-compose.custom.yml down -v"
echo ""
echo "📖 详细文档: ./DOCKER_ARM64_BUILD_GUIDE.md"
