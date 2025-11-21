# Application Configuration
# 应用配置文件 - 用于独立部署应用

# AFFiNE Version / Image
AFFINE_IMAGE=localhost/affine-backend:custom
AFFINE_REVISION=stable

# Application Port
PORT=3010

# External Middleware Connection
# 修改为你的中间件服务器地址
DB_HOST=192.168.1.100
DB_PORT=5432
DB_USERNAME=affine
DB_PASSWORD=your_secure_password_here
DB_DATABASE=affine

# Redis Configuration
REDIS_SERVER_HOST=192.168.1.100
REDIS_SERVER_PORT=6379

# Data Storage
UPLOAD_LOCATION=./data/storage
CONFIG_LOCATION=./data/config

# Search Engine (Optional)
AFFINE_INDEXER_ENABLED=false
# 如果启用搜索，配置 Manticoresearch 地址
# MANTICORE_HOST=192.168.1.100
# MANTICORE_PORT=9308

# Mail Configuration (Optional)
MAILER_HOST=192.168.1.100
MAILER_PORT=1025
MAILER_SENDER=noreply@yourdomain.com
MAILER_USER=
MAILER_PASSWORD=
MAILER_SECURE=false

# Server Configuration
# 如果使用域名和 HTTPS
# AFFINE_SERVER_HOST=affine.yourdomain.com
# AFFINE_SERVER_HTTPS=true

# AI/Copilot (Optional)
# COPILOT_FAL_API_KEY=
# COPILOT_OPENAI_API_KEY=
# COPILOT_PERPLEXITY_API_KEY=

# Notes:
# 1. 将所有 192.168.1.100 替换为实际的中间件服务器地址
# 2. 确保应用服务器能访问中间件服务器的端口
# 3. 如果中间件和应用在同一台机器，可以使用 host.docker.internal (macOS/Windows) 或主机 IP
# 4. 生产环境建议配置防火墙和 VPN
