# AFFiNE 脚本工具

本目录包含用于 AFFiNE 开发和部署的辅助脚本。

## 脚本列表

### 1. switch-env.sh - 环境切换脚本

快速在本地和远程开发环境之间切换。

**用法**：

```bash
# 查看当前环境
./scripts/switch-env.sh status

# 切换到本地环境
./scripts/switch-env.sh local

# 切换到远程环境
./scripts/switch-env.sh remote

# 查看帮助
./scripts/switch-env.sh help
```

**功能**：

- 自动备份当前配置
- 切换后端环境配置（.env 文件）
- 显示下一步操作提示
- 检测远程配置是否已完成

**环境说明**：

- **本地环境**：使用本地 Docker 中间件（PostgreSQL, Redis 等）
- **远程环境**：连接内网测试环境的中间件

**首次使用**：

1. 配置远程环境：

   ```bash
   vi packages/backend/server/.env.remote
   # 将 YOUR_REMOTE_HOST 替换为实际的远程地址
   ```

2. 切换到本地环境（默认）：
   ```bash
   ./scripts/switch-env.sh local
   ```

### 2. upgrade-production.sh - 生产环境升级脚本

在生产环境升级 AFFiNE 应用，不停止中间件服务。

**用法**：

```bash
# 升级到 stable 版本
./scripts/upgrade-production.sh

# 升级到 beta 版本
./scripts/upgrade-production.sh beta

# 升级到特定版本
./scripts/upgrade-production.sh v0.25.3

# 查看帮助
./scripts/upgrade-production.sh help
```

**升级流程**：

1. ✅ 环境检查（Docker、Compose 文件）
2. 💾 备份当前状态（配置文件、镜像版本）
3. 📥 拉取新 Docker 镜像
4. 🛑 停止应用容器（中间件继续运行）
5. 🚀 启动更新后的应用
6. ✔️ 验证升级成功
7. 🗑️ 清理旧镜像（可选）

**特点**：

- 短暂停机（仅应用容器，通常 3-5 秒）
- 中间件持续运行，数据不丢失
- 自动备份，失败自动回滚
- 交互式确认，防止误操作

**环境变量**：

```bash
# 自定义 Compose 文件路径
COMPOSE_FILE=./my-compose.yml ./scripts/upgrade-production.sh

# 自定义项目名称
COMPOSE_PROJECT=my-affine ./scripts/upgrade-production.sh

# 自定义镜像名称
IMAGE_NAME=my-registry/affine ./scripts/upgrade-production.sh stable
```

**使用场景**：

- 内网生产环境定期更新
- 安全补丁快速部署
- 新功能测试和验证

**注意事项**：

- 确保在生产服务器上运行
- 升级前建议备份数据库
- 首次使用建议在测试环境验证

## 架构说明

### 环境架构

```
┌─────────────────────────────────────────────────────────────┐
│                     开发环境（本地）                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───────────────┐         ┌─────────────────────────┐    │
│  │ 源码运行       │         │  Docker 中间件           │    │
│  ├───────────────┤         ├─────────────────────────┤    │
│  │ Backend       │◄────────┤ PostgreSQL              │    │
│  │ (Node.js)     │         │ Redis                   │    │
│  │               │         │ Mailpit                 │    │
│  │ Frontend      │         │ Manticoresearch         │    │
│  │ (Webpack)     │         └─────────────────────────┘    │
│  └───────────────┘                                         │
│         │                                                  │
│         │ switch-env.sh                                    │
│         ▼                                                  │
│  ┌───────────────────────────────────────────┐            │
│  │  可切换连接远程测试环境中间件                │            │
│  └───────────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   生产环境（内网）                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───────────────────────────────────────────────────┐     │
│  │                Docker Compose                     │     │
│  ├───────────────────────────────────────────────────┤     │
│  │  ┌─────────────┐  ┌─────────────────────────┐    │     │
│  │  │ Application │  │  Middleware (持久运行)   │    │     │
│  │  ├─────────────┤  ├─────────────────────────┤    │     │
│  │  │ AFFiNE      │◄─┤ PostgreSQL              │    │     │
│  │  │ Server      │  │ (数据持久化)             │    │     │
│  │  │             │  │                         │    │     │
│  │  │ (容器)      │  │ Redis                   │    │     │
│  │  │             │  │ (缓存)                  │    │     │
│  │  └─────────────┘  └─────────────────────────┘    │     │
│  │         ▲                                         │     │
│  │         │ upgrade-production.sh                   │     │
│  │         │ (只重启应用容器)                          │     │
│  └───────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

### 数据流

**本地开发 - 本地中间件**：

```
Frontend ──► Backend ──► Local Docker (PostgreSQL/Redis)
(8080)      (3010)       (5432/6379)
```

**本地开发 - 远程中间件**：

```
Frontend ──► Backend ──► Remote Test Env (PostgreSQL/Redis)
(8080)      (3010)       (内网地址:5432/6379)
```

**生产环境**：

```
用户 ──► Nginx/Caddy ──► AFFiNE Container ──► PostgreSQL/Redis Containers
              (可选)          (3010)                  (内部网络)
```

## 最佳实践

### 本地开发

1. **日常开发**：使用本地环境

   ```bash
   ./scripts/switch-env.sh local
   docker compose -f .docker/dev/compose.yml up -d
   yarn affine dev -p @affine/server
   ```

2. **调试生产问题**：切换到远程环境

   ```bash
   ./scripts/switch-env.sh remote
   # 停止内网生产应用
   yarn affine dev -p @affine/server  # 连接生产数据库
   ```

3. **切回本地**：恢复本地开发
   ```bash
   ./scripts/switch-env.sh local
   docker compose -f .docker/dev/compose.yml up -d
   ```

### 生产部署

1. **首次部署**：

   ```bash
   cd /path/to/affine
   # 配置 .docker/selfhost/.env
   docker compose -f .docker/selfhost/compose.yml up -d
   ```

2. **定期更新**：

   ```bash
   ./scripts/upgrade-production.sh stable
   ```

3. **快速回滚**（如果需要）：
   ```bash
   # 恢复最近的备份文件
   cp .docker/selfhost/compose.yml.backup.XXXXXX .docker/selfhost/compose.yml
   docker compose -f .docker/selfhost/compose.yml up -d affine
   ```

## 故障排查

### switch-env.sh 问题

**问题：切换到远程环境后无法连接**

```bash
# 检查网络连接
ping YOUR_REMOTE_HOST

# 检查端口连通性
nc -zv YOUR_REMOTE_HOST 5432
nc -zv YOUR_REMOTE_HOST 6379

# 检查 VPN 连接状态
```

**问题：配置未生效**

```bash
# 查看当前使用的配置
cat packages/backend/server/.env

# 重新切换
./scripts/switch-env.sh local
```

### upgrade-production.sh 问题

**问题：升级失败**

```bash
# 查看应用日志
docker compose -f .docker/selfhost/compose.yml logs affine

# 查看中间件状态
docker compose -f .docker/selfhost/compose.yml ps

# 手动回滚
LATEST_BACKUP=$(ls -t .docker/selfhost/compose.yml.backup.* | head -1)
cp $LATEST_BACKUP .docker/selfhost/compose.yml
docker compose -f .docker/selfhost/compose.yml up -d affine
```

**问题：镜像拉取失败**

```bash
# 检查 Docker Hub 连接
docker pull ghcr.io/toeverything/affine:stable

# 使用代理（如果需要）
export HTTP_PROXY=http://proxy.example.com:8080
export HTTPS_PROXY=http://proxy.example.com:8080
```

## 贡献

欢迎提交改进建议！

如果你有新的脚本想法或发现问题，请：

1. 在 `LOCAL_DEV_GUIDE.md` 中记录
2. 提交 Issue 或 Pull Request
3. 更新本 README

## 许可

这些脚本是 AFFiNE 项目的一部分，遵循相同的开源许可。
