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
docker rmi affine-frontend:custom affine-backend:custom 2>/dev/null || true

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

# 第四步：下载 ARM64 Linux native modules
print_step "下载 ARM64 Linux native modules..."

# 创建目录并下载 argon2
mkdir -p node_modules/@node-rs/argon2
cd node_modules/@node-rs/argon2
if [ ! -f argon2.linux-arm64-gnu.node ]; then
    print_step "下载 argon2.linux-arm64-gnu.node..."
    curl -L https://github.com/napi-rs/node-rs/releases/download/argon2@1.8.4/argon2.linux-arm64-gnu.node -o argon2.linux-arm64-gnu.node
    echo "✅ argon2 模块下载完成"
else
    echo "✅ argon2 模块已存在"
fi

# 创建目录并下载 crc32
cd ../crc32
if [ ! -f crc32.linux-arm64-gnu.node ]; then
    print_step "下载 crc32.linux-arm64-gnu.node..."
    curl -L https://github.com/napi-rs/node-rs/releases/download/crc32@1.10.2/crc32.linux-arm64-gnu.node -o crc32.linux-arm64-gnu.node
    echo "✅ crc32 模块下载完成"
else
    echo "✅ crc32 模块已存在"
fi

cd ../../..

# 第五步：构建前端
print_step "构建前端..."
yarn build --package @affine/web
print_step "构建前端 Docker 镜像..."
docker build -f .docker/web/Dockerfile -t affine-frontend:custom .
echo "✅ 前端镜像构建完成"

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
docker build -f .docker/server/Dockerfile -t affine-backend:custom .
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

# 检查前端
if curl -s -f http://localhost:8080 > /dev/null; then
    echo "✅ 前端服务: http://localhost:8080 - 正常"
else
    echo "❌ 前端服务: http://localhost:8080 - 异常"
fi

# 检查后端
if curl -s -f http://localhost:3010/admin/setup > /dev/null; then
    echo "✅ 后端服务: http://localhost:3010 - 正常"
else
    echo "❌ 后端服务: http://localhost:3010 - 异常"
fi

# 检查邮件服务
if curl -s -f http://localhost:8025 > /dev/null; then
    echo "✅ 邮件服务: http://localhost:8025 - 正常"
else
    echo "❌ 邮件服务: http://localhost:8025 - 异常"
fi

echo ""
print_step "显示容器状态..."
docker compose -f docker-compose.custom.yml ps

echo ""
echo "🎉 AFFiNE ARM64 Docker 环境构建完成!"
echo ""
echo "📋 访问信息:"
echo "  - 前端应用: http://localhost:8080"
echo "  - 后端 API: http://localhost:3010"
echo "  - 邮件管理: http://localhost:8025"
echo ""
echo "📝 管理命令:"
echo "  - 停止服务: docker compose -f docker-compose.custom.yml stop"
echo "  - 启动服务: docker compose -f docker-compose.custom.yml start"
echo "  - 查看日志: docker compose -f docker-compose.custom.yml logs -f"
echo "  - 清理环境: docker compose -f docker-compose.custom.yml down -v"
echo ""
echo "📖 详细文档: ./DOCKER_ARM64_BUILD_GUIDE.md"