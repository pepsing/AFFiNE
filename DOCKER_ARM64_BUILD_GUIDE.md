# AFFiNE ARM64 Docker 构建指南

本文档记录了在 macOS ARM64 (Apple Silicon) 环境下成功构建 AFFiNE Docker 镜像的完整过程，包括解决 native module 兼容性问题的关键步骤。

## 环境要求

- **操作系统**: macOS (Apple Silicon)
- **Docker**: 27.5.1+
- **Node.js**: 20.x LTS
- **Yarn**: 4.x
- **Git**: 2.39+

## 核心问题与解决方案

### 主要挑战

在 ARM64 架构下构建 Linux 容器时，遇到 native module 兼容性问题：

- `@node-rs/argon2` 缺少 Linux ARM64 版本
- `@node-rs/crc32` 缺少 Linux ARM64 版本
- `server-native.arm64.node` 格式不兼容 (macOS Mach-O vs Linux ELF)

### 解决策略

使用 **Linux 容器内编译** 的方式，确保生成正确的 Linux ELF 格式 native modules。

## 完整构建流程

### 1. 环境准备

```bash
# 确认当前位置
cd /path/to/AFFiNE

# 检查 git 状态
git status

# 切换到指定版本 (可选)
git checkout v0.25.3
```

### 2. 清理环境

```bash
# 停止并删除已有容器
docker compose -f docker-compose.custom.yml down -v

# 删除已有镜像 (可选)
docker rmi affine-frontend:custom affine-backend:custom 2>/dev/null || true

# 清理 node_modules 和构建缓存
rm -rf node_modules packages/*/node_modules packages/*/*/node_modules
rm -rf packages/frontend/core/.next
rm -rf packages/backend/server/dist
```

### 3. 安装依赖

```bash
# 安装 Rust (如果尚未安装)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source ~/.cargo/env

# 安装项目依赖
yarn install
```

### 4. 解决 @node-rs 模块兼容性

```bash
# 手动下载 Linux ARM64 版本的 @node-rs 模块
cd node_modules/@node-rs/argon2
curl -L https://github.com/napi-rs/node-rs/releases/download/argon2@1.8.4/argon2.linux-arm64-gnu.node -o argon2.linux-arm64-gnu.node

cd ../crc32
curl -L https://github.com/napi-rs/node-rs/releases/download/crc32@1.10.2/crc32.linux-arm64-gnu.node -o crc32.linux-arm64-gnu.node
cd ../../..
```

### 5. 构建前端镜像

```bash
# 构建前端
yarn build --package @affine/web

# 构建前端 Docker 镜像
docker build -f .docker/web/Dockerfile -t affine-frontend:custom .
```

### 6. 解决后端 Native Module 问题

这是最关键的步骤，需要在 Linux 容器内编译 Rust 代码：

```bash
# 方法一：使用 Docker 容器编译 server-native
docker run --rm -v "$(pwd)":/workspace -w /workspace/packages/backend/native \
  node:22-bookworm-slim bash -c "
  apt-get update && apt-get install -y curl build-essential
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source ~/.cargo/env
  rustup install 1.87.0
  rustup default 1.87.0
  npm run build"

# 方法二：使用 Cargo 直接编译 (备选)
docker run --rm -v "$(pwd)":/workspace -w /workspace \
  node:22-bookworm-slim bash -c "
  apt-get update && apt-get install -y curl build-essential
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source ~/.cargo/env
  cd packages/backend/native
  cargo build --release"

# 验证生成的文件格式 (应该是 ELF)
file packages/backend/native/server-native.arm64.node
# 输出应该类似: ELF 64-bit LSB shared object, ARM aarch64
```

### 7. 构建后端镜像

```bash
# 构建后端代码
yarn build --package @affine/server

# 构建后端 Docker 镜像
docker build -f .docker/server/Dockerfile -t affine-backend:custom .
```

### 8. 验证镜像构建

```bash
# 检查镜像
docker images | grep affine

# 预期输出:
# affine-frontend  custom   xxx   xx hours ago   438MB
# affine-backend   custom   xxx   xx hours ago   754MB
```

## 启动和测试

### 1. 启动服务

```bash
# 启动完整环境
docker compose -f docker-compose.custom.yml up -d

# 检查服务状态
docker compose -f docker-compose.custom.yml ps
```

### 2. 验证功能

```bash
# 检查前端 (应该返回 200)
curl -I http://localhost:8080

# 检查后端 (应该返回 302 重定向到 /admin/setup)
curl -I http://localhost:3010/api/healthz

# 检查邮件服务 (应该返回 200)
curl -I http://localhost:8025
```

### 3. 访问应用

- **前端界面**: http://localhost:8080
- **后端 API**: http://localhost:3010
- **邮件管理**: http://localhost:8025
- **数据库**: 内部访问，端口 5432
- **Redis**: 内部访问，端口 6379

## 故障排查

### 常见问题

1. **"Failed to load native binding" 错误**

   ```bash
   # 检查是否正确下载了 Linux ARM64 版本
   ls -la node_modules/@node-rs/*/**.linux-arm64-gnu.node
   ```

2. **"invalid ELF header" 错误**

   ```bash
   # 确保在 Linux 容器内重新编译
   file packages/backend/native/server-native.arm64.node
   # 输出必须显示 "ELF" 而不是 "Mach-O"
   ```

3. **后端容器健康检查失败**

   ```bash
   # 检查后端日志
   docker logs affine_backend --tail 20

   # 这通常是正常的，因为首次启动会重定向到设置页面
   ```

### 调试命令

```bash
# 查看容器日志
docker logs affine_frontend --tail 50
docker logs affine_backend --tail 50

# 进入容器调试
docker exec -it affine_backend bash
docker exec -it affine_frontend sh

# 检查数据库连接
docker exec affine_postgres pg_isready -U affine

# 检查 Redis 连接
docker exec affine_redis redis-cli ping
```

## 文件结构

构建完成后，关键文件位置：

```
AFFiNE/
├── docker-compose.custom.yml          # Docker Compose 配置
├── packages/backend/native/
│   └── server-native.arm64.node       # Linux ELF 格式 native module
├── node_modules/@node-rs/argon2/
│   └── argon2.linux-arm64-gnu.node    # Linux ARM64 argon2 模块
├── node_modules/@node-rs/crc32/
│   └── crc32.linux-arm64-gnu.node     # Linux ARM64 crc32 模块
└── packages/frontend/core/.next/      # 前端构建产物
```

## 版本信息

- **AFFiNE**: v0.25.3
- **Node.js**: 22 (容器内)
- **Rust**: 1.87.0
- **PostgreSQL**: 16 (with pgvector)
- **Redis**: 7-alpine

## 技术要点

1. **跨平台编译**: 使用 Docker 容器确保生成正确的目标平台二进制文件
2. **Native Module 管理**: 手动下载对应架构的预编译模块
3. **ELF vs Mach-O**: macOS 生成 Mach-O 格式，Linux 需要 ELF 格式
4. **依赖管理**: Yarn workspace 正确处理 monorepo 依赖关系

## 性能指标

- **构建时间**: ~15-20 分钟 (取决于网络和硬件)
- **镜像大小**:
  - 前端: ~438MB
  - 后端: ~754MB
- **启动时间**: ~2-3 分钟 (包括数据库迁移)

---

**注意**: 本指南专门针对 macOS ARM64 环境。对于其他平台，native module 处理步骤可能有所不同。
