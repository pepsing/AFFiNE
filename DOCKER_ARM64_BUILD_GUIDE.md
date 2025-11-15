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

> 建议优先使用一键脚本：`./build-arm64-docker.sh`。  
> 下述步骤等价于脚本内部执行的过程，可用于排查问题或手动执行。

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
# 在项目根目录下执行，手动下载 Linux ARM64 版本的 @node-rs 模块

# argon2 (Linux ARM64)
TMP_DIR=$(mktemp -d)
curl -sSL https://registry.npmjs.org/@node-rs/argon2-linux-arm64-gnu/-/argon2-linux-arm64-gnu-2.0.2.tgz | tar -xz -C "$TMP_DIR"
cp "$TMP_DIR/package/argon2.linux-arm64-gnu.node" node_modules/@node-rs/argon2/argon2.linux-arm64-gnu.node
rm -rf "$TMP_DIR"

# crc32 (Linux ARM64)
TMP_DIR=$(mktemp -d)
curl -sSL https://registry.npmjs.org/@node-rs/crc32-linux-arm64-gnu/-/crc32-linux-arm64-gnu-1.10.6.tgz | tar -xz -C "$TMP_DIR"
cp "$TMP_DIR/package/crc32.linux-arm64-gnu.node" node_modules/@node-rs/crc32/crc32.linux-arm64-gnu.node
rm -rf "$TMP_DIR"
```

### 5. 构建前端静态资源

```bash
# 构建前端（使用本地静态资源路径，而非 CDN）
PUBLIC_PATH=/ yarn build --package @affine/web
PUBLIC_PATH=/ yarn build --package @affine/admin
PUBLIC_PATH=/ yarn build --package @affine/mobile

# 前端静态资源会被复制到后端镜像中的 /static，由应用容器直接提供，无需单独的前端镜像
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
docker build -f Dockerfile.backend.custom -t affine-backend:custom .
```

### 8. 验证镜像构建

```bash
# 检查镜像
docker images | grep affine

# 预期输出:
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
# 检查应用入口 (应该返回 200 或 302)
curl -I http://localhost:3010

# 检查健康检查接口 (应该返回 200 或 302 重定向到 /admin/setup)
curl -I http://localhost:3010/api/healthz

```

### 3. 访问应用

- **应用入口（前端 + 后端）**: http://localhost:3010
- **管理后台**: http://localhost:3010/admin
- **健康检查**: http://localhost:3010/api/healthz
- **数据库**: 内部访问，端口 5432
- **Redis**: 内部访问，端口 6379

## 可选：中间件与应用分离部署

如果你希望将中间件（Postgres / Redis / Manticore / Mailpit）与应用分离部署，方便调试和升级，可以使用以下方式：

1. **启动中间件栈（含端口暴露，便于本地直连调试）**：

   ```bash
   # 在 .docker/selfhost-split 目录下
   docker compose -f .docker/selfhost-split/compose-middleware.yml up -d
   # 本机可直接访问：
   # Postgres: localhost:5432
   # Redis:    localhost:6379
   # Manticore:localhost:9308
   # Mailpit SMTP: localhost:1025
   # Mailpit Web:  http://localhost:8025
   ```

2. **使用自定义镜像启动应用栈（仅应用）**：

   ```bash
   cp .docker/custom/.env.app.example .docker/custom/.env.app
   # 如需连本机中间件，保持 host.docker.internal/对应端口即可
   # 如需连生产中间件，将 DB_HOST / REDIS_SERVER_HOST / MANTICORE_HOST 改为生产地址
   # 如需模拟真实邮件发送（投递到 Mailpit，而不是外部邮箱），可参考 .docker/custom/.env.app.mailpit-example 中的 MAILER_HOST/MAILER_PORT 设置

   docker compose -f .docker/custom/compose-app.yml up -d
   # 应用入口仍为 http://localhost:3010
   ```

这样一来，你可以：

- 通过中间件 compose 暴露的端口，用 `psql` / `redis-cli` / Manticore 工具直接连库调试；
- 应用容器则通过环境变量自由切换使用本地中间件或生产中间件。

### 首次部署流程（本地 / 生产，分离模式）

1. **构建应用镜像（在构建机上）**：

   ```bash
   # macOS ARM 本地构建
   ./build-arm64-docker.sh

   # 如需在生产机使用自建 Registry，可在构建完成后:
   # docker tag affine-backend:custom your-registry/affine-backend:TAG
   # docker push your-registry/affine-backend:TAG
   ```

2. **在目标环境启动中间件栈**：

   ```bash
   # 确保为中间件准备好宿主机数据目录，如 ./data/postgres ./data/redis ./data/manticore ./data/mailpit
   docker compose -f .docker/selfhost-split/compose-middleware.yml up -d
   ```

3. **配置应用连接信息并启动应用栈**：

   ```bash
   cp .docker/custom/.env.app.example .docker/custom/.env.app
   # 或者使用 .env.app.mailpit-example 模拟真实邮件发送
   # 根据实际中间件地址修改：
   #   DB_HOST / DB_PORT / DB_USERNAME / DB_PASSWORD / DB_DATABASE
   #   REDIS_SERVER_HOST / REDIS_SERVER_PORT
   #   MANTICORE_HOST / MANTICORE_PORT
   #   MAILER_HOST / MAILER_PORT

   docker compose -f .docker/custom/compose-app.yml up -d
   ```

4. **通过浏览器访问并完成自建初始化**：

   - `http://<服务器IP或域名>:3010/admin/setup`：创建第一个管理员账号。
   - 之后通过 `http://<服务器IP或域名>:3010/admin` 管理团队账号。

### 应用升级流程（不丢数据）

只要不中断或删除中间件的数据目录（Postgres / Redis / Manticore / Mailpit）和应用的存储卷，升级应用镜像不会丢失任何业务数据。

1. **保持中间件栈运行**：  
   不要对 `.docker/selfhost-split/compose-middleware.yml` 使用 `down -v`，宿主机上的：

   - `DB_DATA_LOCATION`（Postgres 数据）
   - `REDIS_DATA_LOCATION`（Redis 数据）
   - `MANTICORE_DATA_LOCATION`（全文索引）
   - `MAILPIT_DATA_LOCATION`（邮件缓存，可选）

   都会被保留。

2. **停止应用栈（不删除卷）**：

   ```bash
   docker compose -f .docker/custom/compose-app.yml down
   # 注意：不要加 -v，避免删除 /root/.affine/storage /config 等卷
   ```

3. **构建 / 拉取新版本镜像**：

   - 构建机重新运行：

     ```bash
     ./build-arm64-docker.sh
     ```

   - 若使用 Registry，在构建后重新 `tag` + `push`，然后在应用服务器上 `docker pull` 新 tag，并更新 `.docker/custom/compose-app.yml` 中的 `image`。

4. **重新启动应用栈**：

   ```bash
   docker compose -f .docker/custom/compose-app.yml up -d
   ```

   - `affine_migration_custom` 会再次执行 `self-host-predeploy.js`：
     - 确保 Prisma schema 和数据迁移都已经应用；
     - 不会清空已有数据。
   - 新版本应用容器 `affine_server_custom` 启动后，会继续使用原有的数据库、Redis、搜索和文件存储。

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

   # 如果只是 /api/healthz 返回 302 重定向到 /admin/setup，这是正常的
   # 若容器仍然处于 unhealthy 状态，则需要根据日志排查实际错误
   ```

### 调试命令

```bash
# 查看容器日志
docker logs affine_backend --tail 50

# 进入容器调试
docker exec -it affine_backend bash

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
└── packages/frontend/apps/web/dist/   # 前端构建产物
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
