# AFFiNE 生产环境分离部署指南

本目录提供了 AFFiNE 的分离部署配置，允许中间件和应用独立部署和管理。

## 架构概览

```
┌─────────────────────────────────────────────────────────────────┐
│                      生产环境架构                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────────────┐              ┌────────────────────────┐ │
│  │  应用服务器        │              │  中间件服务器           │ │
│  │  (可多实例)        │              │  (独立持久化)           │ │
│  ├───────────────────┤              ├────────────────────────┤ │
│  │                   │              │                        │ │
│  │  ┌─────────────┐  │   TCP/IP    │  ┌──────────────────┐ │ │
│  │  │  AFFiNE     │  │ ◄──────────►│  │  PostgreSQL      │ │ │
│  │  │  Container  │  │              │  │  (5432)          │ │ │
│  │  │             │  │              │  │                  │ │ │
│  │  │  - Storage  │  │              │  │  ┌─────────────┐ │ │ │
│  │  │  - Config   │  │              │  │  │  Redis      │ │ │ │
│  │  └─────────────┘  │              │  │  │  (6379)     │ │ │ │
│  │        :3010      │              │  │  └─────────────┘ │ │ │
│  └───────────────────┘              │  │                  │ │ │
│           │                         │  │  ┌─────────────┐ │ │ │
│           │                         │  │  │  Mailpit    │ │ │ │
│           │                         │  │  │  (1025)     │ │ │ │
│           │                         │  │  └─────────────┘ │ │ │
│           ▼                         │  │                  │ │ │
│  ┌───────────────────┐              │  │  ┌─────────────┐ │ │ │
│  │  Nginx/Caddy      │              │  │  │ Manticore   │ │ │ │
│  │  (反向代理)        │              │  │  │ (9308)      │ │ │ │
│  └───────────────────┘              │  └──────────────────┘ │ │
│           :80/:443                  │                        │ │
│                                     └────────────────────────┘ │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  本地开发环境也可以连接到中间件服务器                        │ │
│  │  ./scripts/switch-env.sh remote                            │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 部署优势

### 分离部署的好处

1. **灵活性**
   - 应用和中间件可以部署在不同服务器
   - 支持应用多实例部署（水平扩展）
   - 中间件可以被多个环境共享

2. **维护性**
   - 应用升级不影响中间件
   - 中间件独立维护和备份
   - 故障隔离，问题定位更容易

3. **性能**
   - 可以为数据库和应用分配不同的硬件资源
   - 数据库可以使用专用的高性能存储
   - 支持读写分离和主从复制

4. **安全性**
   - 通过防火墙和 VPN 控制访问
   - 数据库不必暴露到公网
   - 可以为不同组件设置不同的安全策略

## 快速开始

> 提示：在 Linux 服务器上做自建部署时，只需要构建 **后端服务 + Web 前端静态资源**，不需要构建桌面客户端或移动端 App。具体命令见仓库根目录的
> `linux_build_deploy.md`。

### 场景一：同一台服务器部署（入门）

适合资源充足的单服务器部署。

```bash
# 1. 进入配置目录
cd .docker/selfhost-split

# 2. 配置中间件
cp .env.middleware .env.middleware.local
vi .env.middleware.local
# 设置强密码等

# 3. 配置应用
cp .env.app .env.app.local
vi .env.app.local
# 将 DB_HOST 和 REDIS_SERVER_HOST 设置为 host.docker.internal 或服务器内网IP

# 4. 启动中间件
docker compose -f compose-middleware.yml --env-file .env.middleware.local up -d

# 5. 启动应用
docker compose -f compose-app.yml --env-file .env.app.local up -d

# 6. 检查状态
docker compose -f compose-middleware.yml ps
docker compose -f compose-app.yml ps
```

### 场景二：分离服务器部署（生产推荐）

适合生产环境，提供更好的隔离和性能。

#### 步骤 1: 部署中间件服务器

```bash
# 在中间件服务器上
cd .docker/selfhost-split

# 配置环境变量
cp .env.middleware .env
vi .env
# 设置：
# - DB_PASSWORD: 强密码
# - REDIS_PASSWORD: 强密码（可选）
# - 数据存储路径

# 启动中间件
docker compose -f compose-middleware.yml up -d

# 验证服务
docker compose -f compose-middleware.yml ps
docker compose -f compose-middleware.yml logs

# 配置防火墙（重要！）
# 只允许应用服务器访问
sudo ufw allow from 192.168.1.200 to any port 5432
sudo ufw allow from 192.168.1.200 to any port 6379
```

#### 步骤 2: 部署应用服务器

```bash
# 在应用服务器上
cd .docker/selfhost-split

# 配置环境变量
cp .env.app .env
vi .env
# 设置：
# - DB_HOST: 中间件服务器IP (如 192.168.1.100)
# - DB_PASSWORD: 与中间件服务器相同
# - REDIS_SERVER_HOST: 中间件服务器IP
# - AFFINE_REVISION: 版本 (stable/beta/canary)

# 启动应用
docker compose -f compose-app.yml up -d

# 验证服务
docker compose -f compose-app.yml ps
docker compose -f compose-app.yml logs affine

# 测试连接
curl http://localhost:3010/api/healthz
```

## 配置文件说明

### compose-middleware.yml

中间件栈配置，包含：
- **PostgreSQL**: 数据库，端口 5432
- **Redis**: 缓存，端口 6379
- **Mailpit**: 邮件测试，端口 1025/8025（可选）
- **Manticoresearch**: 搜索引擎，端口 9308（可选）

所有服务都暴露端口供外部访问。

### compose-app.yml

应用配置，包含：
- **affine_migration**: 数据库迁移任务
- **affine**: AFFiNE 应用服务器

连接外部中间件服务。

### .env.middleware

中间件环境变量：
- 端口配置
- 数据存储路径
- 密码和认证

### .env.app

应用环境变量：
- 版本选择
- 中间件连接地址
- 应用配置

## 常用操作

### 查看服务状态

```bash
# 中间件状态
docker compose -f compose-middleware.yml ps

# 应用状态
docker compose -f compose-app.yml ps
```

### 查看日志

```bash
# 中间件日志
docker compose -f compose-middleware.yml logs -f postgres
docker compose -f compose-middleware.yml logs -f redis

# 应用日志
docker compose -f compose-app.yml logs -f affine
```

### 升级应用

```bash
# 方法1: 使用升级脚本（推荐）
cd /path/to/affine
COMPOSE_FILE=.docker/selfhost-split/compose-app.yml \
  ../../scripts/upgrade-production.sh stable

# 方法2: 手动升级
cd .docker/selfhost-split
docker compose -f compose-app.yml pull affine
docker compose -f compose-app.yml up -d affine
```

### 备份数据

```bash
# 备份 PostgreSQL
docker exec affine_postgres pg_dump -U affine affine > backup_$(date +%Y%m%d).sql

# 备份 Redis
docker exec affine_redis redis-cli SAVE
docker cp affine_redis:/data/dump.rdb ./redis_backup_$(date +%Y%m%d).rdb

# 备份应用数据（上传的文件等）
tar -czf storage_backup_$(date +%Y%m%d).tar.gz ./data/storage
```

### 恢复数据

```bash
# 恢复 PostgreSQL
cat backup_20231113.sql | docker exec -i affine_postgres psql -U affine affine

# 恢复 Redis
docker cp redis_backup_20231113.rdb affine_redis:/data/dump.rdb
docker compose -f compose-middleware.yml restart redis
```

### 扩展应用实例

```bash
# 方法1: 使用 Docker Compose scale
docker compose -f compose-app.yml up -d --scale affine=3

# 方法2: 在不同服务器部署多个应用实例
# 然后使用负载均衡器（Nginx/HAProxy）分发流量
```

## 性能优化

### PostgreSQL 优化

编辑 `compose-middleware.yml`，添加性能参数：

```yaml
postgres:
  command:
    - postgres
    - -c
    - max_connections=200
    - -c
    - shared_buffers=256MB
    - -c
    - effective_cache_size=1GB
    - -c
    - maintenance_work_mem=64MB
    - -c
    - checkpoint_completion_target=0.9
    - -c
    - wal_buffers=16MB
    - -c
    - default_statistics_target=100
```

### Redis 优化

编辑 `compose-middleware.yml`，优化 Redis 配置：

```yaml
redis:
  command: >
    redis-server
    --appendonly yes
    --maxmemory 512mb
    --maxmemory-policy allkeys-lru
    --save 900 1
    --save 300 10
```

## 安全配置

### 1. 配置防火墙

**中间件服务器**：
```bash
# 只允许应用服务器访问数据库
sudo ufw allow from <APP_SERVER_IP> to any port 5432
sudo ufw allow from <APP_SERVER_IP> to any port 6379

# 允许本地开发环境访问（如果需要）
sudo ufw allow from <DEV_VPN_RANGE> to any port 5432
sudo ufw allow from <DEV_VPN_RANGE> to any port 6379
```

**应用服务器**：
```bash
# 只暴露应用端口
sudo ufw allow 3010/tcp

# 如果使用 Nginx
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### 2. 使用强密码

```bash
# 生成强密码
openssl rand -base64 32

# 更新 .env 文件
DB_PASSWORD=<生成的强密码>
REDIS_PASSWORD=<生成的强密码>
```

### 3. 启用 SSL/TLS

对于生产环境，建议使用 Nginx/Caddy 作为反向代理，启用 HTTPS。

**Nginx 配置示例**：
```nginx
server {
    listen 80;
    server_name affine.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name affine.yourdomain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:3010;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 4. 数据库连接加密

PostgreSQL SSL 配置（高级）：
```yaml
postgres:
  command:
    - postgres
    - -c
    - ssl=on
    - -c
    - ssl_cert_file=/etc/ssl/certs/server.crt
    - -c
    - ssl_key_file=/etc/ssl/private/server.key
  volumes:
    - /path/to/certs:/etc/ssl/certs
    - /path/to/keys:/etc/ssl/private
```

## 监控和维护

### 健康检查

```bash
# 检查所有服务健康状态
docker compose -f compose-middleware.yml ps
docker compose -f compose-app.yml ps

# 检查应用健康端点
curl http://localhost:3010/api/healthz

# 检查数据库连接
docker exec affine_postgres pg_isready -U affine

# 检查 Redis
docker exec affine_redis redis-cli ping
```

### 日志管理

```bash
# 限制日志大小（在 compose 文件中添加）
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

### 定期备份脚本

创建 `backup.sh`：
```bash
#!/bin/bash
BACKUP_DIR="/backup/affine"
DATE=$(date +%Y%m%d_%H%M%S)

# 备份数据库
docker exec affine_postgres pg_dump -U affine affine | gzip > "$BACKUP_DIR/db_$DATE.sql.gz"

# 备份应用数据
tar -czf "$BACKUP_DIR/storage_$DATE.tar.gz" ./data/storage

# 清理旧备份（保留30天）
find "$BACKUP_DIR" -name "*.gz" -mtime +30 -delete

echo "Backup completed: $DATE"
```

添加到 crontab：
```bash
# 每天凌晨2点备份
0 2 * * * /path/to/backup.sh
```

## 故障排查

### 应用无法连接数据库

```bash
# 1. 检查中间件是否运行
docker compose -f compose-middleware.yml ps

# 2. 测试网络连通性
ping <MIDDLEWARE_SERVER_IP>
nc -zv <MIDDLEWARE_SERVER_IP> 5432

# 3. 检查防火墙
sudo ufw status

# 4. 查看应用日志
docker compose -f compose-app.yml logs affine

# 5. 测试数据库连接
docker run --rm -it postgres:16 psql -h <MIDDLEWARE_IP> -U affine -d affine
```

### 数据库性能问题

```bash
# 查看活动连接
docker exec affine_postgres psql -U affine -c "SELECT * FROM pg_stat_activity;"

# 查看慢查询
docker exec affine_postgres psql -U affine -c "SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"

# 查看数据库大小
docker exec affine_postgres psql -U affine -c "SELECT pg_size_pretty(pg_database_size('affine'));"
```

### Redis 内存问题

```bash
# 查看内存使用
docker exec affine_redis redis-cli INFO memory

# 清理过期键
docker exec affine_redis redis-cli --scan --pattern "*" | xargs docker exec affine_redis redis-cli del
```

## 与本地开发环境集成

本地开发可以直接连接到生产中间件进行调试：

```bash
# 1. 确保有 VPN 连接到内网
# 2. 切换到远程环境
./scripts/switch-env.sh remote

# 3. 配置远程连接
vi packages/backend/server/.env.remote
# 设置中间件服务器地址

# 4. 启动本地应用（连接远程中间件）
yarn affine dev -p @affine/server
yarn affine dev -p @affine/web
```

## 最佳实践

1. **分离部署**：生产环境使用独立的中间件服务器
2. **版本管理**：使用具体版本标签而不是 `latest`
3. **定期备份**：每天自动备份数据库和文件
4. **监控告警**：使用 Prometheus/Grafana 监控服务状态
5. **安全加固**：配置防火墙、使用强密码、启用 SSL
6. **文档记录**：记录所有配置变更和运维操作
7. **灾难恢复**：定期测试备份恢复流程

## 参考资源

- [AFFiNE 官方文档](https://docs.affine.pro)
- [Docker Compose 文档](https://docs.docker.com/compose/)
- [PostgreSQL 调优](https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server)
- [Redis 最佳实践](https://redis.io/topics/admin)
