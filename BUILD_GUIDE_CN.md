# AFFiNE 本地开发环境构建指南

> 本文档基于 AFFiNE v0.25.3 版本
> 最后更新：2025-11-06

## 目录

- [系统要求](#系统要求)
- [前置条件安装](#前置条件安装)
- [项目构建](#项目构建)
- [服务配置](#服务配置)
- [启动服务](#启动服务)
- [测试账号](#测试账号)
- [常用命令](#常用命令)
- [常见问题](#常见问题)

---

## 系统要求

- **操作系统**: macOS / Linux / Windows
- **Node.js**: v20.x LTS
- **Rust**: 1.87.0（项目会自动使用此版本）
- **Docker**: 用于运行 PostgreSQL、Redis 等服务
- **磁盘空间**: 至少 10GB 可用空间

---

## 前置条件安装

### 1. 安装 Node.js

推荐使用 Node.js v20.x LTS 版本。

**方式一：直接安装**

```bash
# 访问 https://nodejs.org/ 下载 LTS 版本
```

**方式二：使用 fnm（推荐）**

```bash
# 安装 fnm
curl -fsSL https://fnm.vercel.app/install | bash

# 安装并使用 Node.js 20
fnm use 20
```

验证安装：

```bash
node --version  # 应显示 v20.x.x
```

### 2. 启用 Yarn 4.x

```bash
corepack enable
corepack prepare yarn@stable --activate
```

验证安装：

```bash
yarn --version  # 应显示 4.x.x
```

### 3. 安装 Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
```

加载环境变量：

```bash
source "$HOME/.cargo/env"
```

验证安装：

```bash
rustc --version  # 应显示 rustc 1.91.0 或更高版本
cargo --version
```

> **注意**: 项目使用 `rust-toolchain.toml` 指定了 Rust 1.87.0，构建时会自动下载。

### 4. 安装 Docker

**macOS**:

- 下载并安装 [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- 或者使用 [OrbStack](https://orbstack.dev/)（推荐，更轻量）

**Linux**:

```bash
# 参考 Docker 官方文档安装
curl -fsSL https://get.docker.com | sh
```

验证安装：

```bash
docker --version
docker compose version
```

---

## 项目构建

### 1. 克隆仓库

```bash
git clone https://github.com/toeverything/AFFiNE.git
cd AFFiNE
```

### 2. 切换到指定版本（可选）

```bash
# 查看可用的 release 版本
git tag | grep -v 'canary\|beta\|alpha' | sort -V | tail -10

# 切换到特定版本，例如 v0.25.3
git checkout v0.25.3
```

### 3. 安装项目依赖

```bash
yarn install
```

> **注意**: 首次安装会下载大量依赖，可能需要 5-10 分钟，具体取决于网络速度。
> 过程中可能会显示一些 peer dependency 警告，这是正常的。

### 4. 构建 Native 包

AFFiNE 包含前端和后端的 Rust Native 模块，需要分别构建。

**构建前端 Native 依赖**（约需 1-2 分钟）：

```bash
yarn affine @affine/native build
```

**构建后端 Native 依赖**（约需 1-2 分钟）：

```bash
yarn affine @affine/server-native build
```

**构建 Reader 包**：

```bash
yarn affine @affine/reader build
```

> **提示**: 如果构建过程中遇到 Rust 版本问题，项目会自动下载正确的版本（1.87.0）。

---

## 服务配置

### 1. 配置 Docker 服务

AFFiNE 需要以下服务：

- **PostgreSQL**: 数据库
- **Redis**: 缓存
- **Mailpit**: 邮件服务（开发环境）
- **ManticoreSearch**: 全文搜索引擎

创建配置文件：

```bash
cp ./.docker/dev/compose.yml.example ./.docker/dev/compose.yml
cp ./.docker/dev/.env.example ./.docker/dev/.env
```

启动 Docker 服务（后台运行）：

```bash
docker compose -f ./.docker/dev/compose.yml up -d
```

验证服务状态：

```bash
docker compose -f ./.docker/dev/compose.yml ps
```

应该看到 4 个容器都在运行：

- `affine_dev_services-postgres-1`
- `affine_dev_services-redis-1`
- `affine_dev_services-mailpit-1`
- `affine_dev_services-manticoresearch-1`

### 2. 配置后端环境变量

创建环境配置文件：

```bash
cp packages/backend/server/.env.example packages/backend/server/.env
```

编辑 `packages/backend/server/.env`，取消注释所有必要的环境变量：

```bash
# 使用以下命令快速配置（取消所有注释）
sed -i '' 's/^# //g' packages/backend/server/.env
```

或者手动编辑文件，确保以下配置已启用：

```env
DATABASE_URL="postgres://affine:affine@localhost:5432/affine"
REDIS_SERVER_HOST=localhost
MAILER_HOST=127.0.0.1
MAILER_PORT=1025
MAILER_SENDER="noreply@toeverything.info"
MAILER_USER="noreply@toeverything.info"
MAILER_PASSWORD="affine"
MAILER_SECURE=false
AFFINE_INDEXER_ENABLED=true
```

### 3. 初始化数据库

运行数据库迁移和初始化脚本：

```bash
yarn affine server init
```

这个过程会：

- 应用 90+ 个 Prisma 数据库迁移
- 运行 9 个数据迁移任务
- 创建必要的数据库表和索引
- 初始化功能特性配置

> **预计时间**: 约 30-60 秒

---

## 启动服务

### 启动后端服务器

在**第一个终端**中运行：

```bash
yarn affine server dev
```

后端服务会启动在默认端口（通常是 3010 或 3000），你会看到类似输出：

```
[Nest] LOG [NestApplication] Nest application successfully started
```

### 启动前端开发服务器

在**第二个终端**中运行：

**方式一：使用交互式选择**

```bash
yarn dev
# 然后选择: @affine/web
```

**方式二：直接指定包名**（推荐）

```bash
yarn affine @affine/web dev
```

前端服务会启动在 `http://localhost:8080`（或其他可用端口）。

访问 http://localhost:8080 即可看到 AFFiNE 登录页面。

---

## 测试账号

服务启动后，会自动创建以下测试账号：

### Dev 用户（免费版）

- **邮箱**: `dev@affine.pro`
- **密码**: `dev`
- **限制**: 工作空间成员最多 3 人

### Pro 用户（专业版）

- **邮箱**: `pro@affine.pro`
- **密码**: `pro`
- **限制**: 工作空间成员最多 10 人

### Team 用户（团队版）

- **邮箱**: `team@affine.pro`
- **密码**: `team`
- **特性**: 包含默认的团队工作空间，成员最多 10 人

---

## 常用命令

### 开发工具

**Prisma Studio（数据库 GUI）**：

```bash
yarn affine server prisma studio
# 访问 http://localhost:5555
```

**填充测试数据**：

```bash
yarn affine server seed -h
```

**查看可用的开发包**：

```bash
yarn dev  # 会显示所有可启动的包
```

### 各前端选项说明

- `@affine/web` - Web 前端（浏览器版本）**← 推荐**
- `@affine/electron` - Electron 桌面应用
- `@affine/mobile` - 移动端通用版本
- `@affine/ios` - iOS 应用
- `@affine/android` - Android 应用
- `@affine/admin` - 管理后台

### Docker 服务管理

**停止所有服务**：

```bash
docker compose -f ./.docker/dev/compose.yml down
```

**重启服务**：

```bash
docker compose -f ./.docker/dev/compose.yml restart
```

**查看服务日志**：

```bash
docker compose -f ./.docker/dev/compose.yml logs -f
```

**清理所有数据（谨慎操作）**：

```bash
docker compose -f ./.docker/dev/compose.yml down -v
```

---

## 常见问题

### 1. Rust 编译失败

**问题**: 构建 Native 包时提示 `cargo: command not found` 或版本不匹配。

**解决**:

```bash
# 确保 Rust 已安装
source "$HOME/.cargo/env"
rustc --version

# 如果版本不对，项目会自动安装 1.87.0
# 手动安装特定版本（如需要）：
rustup toolchain install 1.87.0
```

### 2. Docker 服务无法启动

**问题**: `Cannot connect to the Docker daemon` 错误。

**解决**:

- 确保 Docker Desktop 或 OrbStack 已启动
- macOS 用户检查 Docker 是否在系统托盘中运行
- Linux 用户检查 Docker 服务状态：
  ```bash
  sudo systemctl status docker
  sudo systemctl start docker
  ```

### 3. 数据库连接失败

**问题**: 后端启动时报 `DATABASE_URL` 相关错误。

**解决**:

1. 检查 Docker 服务是否运行：
   ```bash
   docker compose -f ./.docker/dev/compose.yml ps
   ```
2. 确认 `.env` 文件中的 `DATABASE_URL` 已正确配置
3. 重新初始化数据库：
   ```bash
   yarn affine server init
   ```

### 4. 端口被占用

**问题**: 启动服务时提示端口已被使用。

**解决**:

```bash
# 查找占用端口的进程（以 3010 为例）
lsof -i :3010

# 终止占用的进程
kill -9 <PID>
```

或者修改配置使用其他端口。

### 5. 依赖安装速度慢

**问题**: `yarn install` 非常缓慢。

**解决**:

```bash
# 使用国内镜像（中国用户）
yarn config set registry https://registry.npmmirror.com
yarn install
```

### 6. 前端无法连接后端

**问题**: 前端页面加载正常，但无法登录或操作。

**解决**:

1. 确保后端服务已启动并运行正常
2. 检查浏览器控制台的网络请求，确认 API 地址正确
3. 检查 CORS 配置（开发环境通常自动配置）

### 7. 清理并重新构建

如果遇到奇怪的问题，可以尝试完全清理后重新构建：

```bash
# 停止所有服务
docker compose -f ./.docker/dev/compose.yml down -v

# 清理构建产物和依赖
yarn clean  # 如果有这个命令
rm -rf node_modules
rm -rf .yarn/cache

# 重新安装和构建
yarn install
yarn affine @affine/native build
yarn affine @affine/server-native build
yarn affine @affine/reader build

# 重新启动 Docker 和初始化数据库
docker compose -f ./.docker/dev/compose.yml up -d
yarn affine server init
```

---

## 开发建议

### 推荐的 IDE 配置

- **VS Code** 推荐插件：
  - ESLint
  - Prettier
  - Rust Analyzer（用于编辑 Rust 代码）
  - Prisma

### Git 工作流

建议在开发前创建新分支：

```bash
git checkout -b feature/your-feature-name
```

### 性能优化

- 开发时建议关闭不需要的服务以节省资源
- 使用 `yarn affine` 命令可以只运行特定包的脚本
- 首次构建较慢，后续增量构建会快很多

---

## 参考资料

- [官方构建文档](./docs/BUILDING.md)
- [服务器开发文档](./docs/developing-server.md)
- [AFFiNE 官网](https://affine.pro)
- [GitHub 仓库](https://github.com/toeverything/AFFiNE)

---

## 更新日志

- **2025-11-06**: 基于 v0.25.3 版本创建初始文档
  - 完整的构建流程
  - Docker 配置说明
  - 常见问题排查

---

**祝你构建顺利！如有问题，请参考常见问题部分或查阅官方文档。**
