# ✅ Fork 配置完成指南

## 当前状态

### Remote 配置 ✅ 已完成

```bash
origin   → https://github.com/pepsing/AFFiNE.git (你的 Fork)
upstream → https://github.com/toeverything/AFFiNE (官方仓库)
```

### 待推送的提交 (4个)

```
98080d6ec feat: add separated production deployment configuration
0dce8fe0c feat: add multi-environment support and production upgrade tools
cdb84c5f1 chore: add local development files to gitignore
9775511ae feat: add PlantUML preview support for code blocks
```

## 下一步：推送到你的 Fork

### 方式 1: 使用 GitHub CLI（推荐）

```bash
# 如果还没安装 gh
brew install gh

# 登录 GitHub
gh auth login

# 推送
git push origin canary --force-with-lease
```

### 方式 2: 使用 SSH（推荐用于长期开发）

#### 2.1 切换到 SSH URL

```bash
git remote set-url origin git@github.com:pepsing/AFFiNE.git
```

#### 2.2 配置 SSH Key（如果还没有）

```bash
# 生成 SSH key（如果还没有）
ssh-keygen -t ed25519 -C "your_email@example.com"

# 复制公钥
cat ~/.ssh/id_ed25519.pub

# 在 GitHub 添加 SSH key：
# 1. 访问 https://github.com/settings/keys
# 2. 点击 "New SSH key"
# 3. 粘贴公钥
```

#### 2.3 推送

```bash
git push origin canary --force-with-lease
```

### 方式 3: 使用 Personal Access Token

#### 3.1 创建 Token

1. 访问 https://github.com/settings/tokens
2. 点击 "Generate new token (classic)"
3. 勾选 `repo` 权限
4. 生成并复制 token

#### 3.2 配置 Git 凭据

```bash
# macOS 使用 keychain
git config --global credential.helper osxkeychain

# 或者配置 token（不推荐，token 会明文存储）
git remote set-url origin https://YOUR_TOKEN@github.com/pepsing/AFFiNE.git
```

#### 3.3 推送

```bash
git push origin canary --force-with-lease
# 首次会提示输入用户名和密码（密码处输入 token）
```

### 方式 4: 手动在 GitHub 网页操作

如果以上都不行，可以通过 GitHub 网页：

1. 访问 https://github.com/pepsing/AFFiNE
2. 点击 "Compare" 或 "Pull requests"
3. 查看你的 fork 和官方的差异
4. 确认你的修改是否已经在 fork 中

## 验证推送成功

推送成功后，执行：

```bash
# 检查本地和远程的差异
git log origin/canary..HEAD

# 如果没有输出，说明已经同步成功
```

访问你的 Fork 查看：https://github.com/pepsing/AFFiNE/commits/canary

应该能看到你的 4 个提交。

## 推送后的日常工作流

### 1. 同步官方更新

```bash
# 使用脚本（推荐）
./scripts/sync-upstream.sh

# 或手动执行
git fetch upstream
git rebase upstream/canary
git push origin canary --force-with-lease
```

### 2. 开发新功能

```bash
# 创建功能分支
git checkout -b feature/my-feature

# 开发、提交
git add .
git commit -m "feat: implement my feature"

# 推送到 fork
git push origin feature/my-feature

# 合并回 canary
git checkout canary
git merge feature/my-feature
git push origin canary
```

### 3. 构建并部署到生产

```bash
# 本地构建镜像
./scripts/build-docker-image.sh

# 同步到生产服务器
PROD_SERVER=192.168.1.100 ./scripts/sync-image-to-production.sh

# 或者一键部署
PROD_SERVER=192.168.1.100 ./scripts/deploy-to-production.sh
```

## 当前已有的工具

### 脚本列表

```
scripts/
├── switch-env.sh                 # 环境切换（本地/远程）
├── sync-upstream.sh              # 同步官方更新
├── upgrade-production.sh         # 生产环境升级
├── build-docker-image.sh         # 构建 Docker 镜像
├── sync-image-to-production.sh   # 同步镜像到生产
├── deploy-to-production.sh       # 一键部署
└── setup-fork.sh                 # Fork 配置（已完成）
```

### 配置文件

```
.docker/selfhost-split/
├── compose-middleware.yml        # 中间件配置
├── compose-app.yml               # 应用配置
├── .env.middleware               # 中间件环境变量
├── .env.app                      # 应用环境变量
├── deploy-middleware.sh          # 中间件部署脚本
└── deploy-app.sh                 # 应用部署脚本

packages/backend/server/
├── .env                          # 当前环境（不提交）
├── .env.local                    # 本地环境模板
└── .env.remote                   # 远程环境模板
```

## 常见问题

### Q: 推送时要求输入密码但失败？

A: HTTPS 不支持密码认证，请使用 Personal Access Token 或 SSH。

### Q: 如何查看我 fork 和官方的差异？

```bash
git fetch upstream
git log upstream/canary..canary --oneline
```

### Q: 如何撤销推送？

```bash
# 回退到某个提交
git reset --hard <commit-hash>
git push origin canary --force-with-lease
```

### Q: 如何从 fork 删除提交？

不推荐！fork 就是用来存储你的修改的。如果确实需要：

```bash
git rebase -i upstream/canary
# 删除不想要的提交
git push origin canary --force
```

## 完成检查清单

推送成功后，确认以下事项：

- [ ] `git remote -v` 显示正确的 origin 和 upstream
- [ ] 访问 https://github.com/pepsing/AFFiNE 能看到你的 4 个提交
- [ ] `git log origin/canary..HEAD` 没有输出（说明已同步）
- [ ] 测试 `./scripts/sync-upstream.sh` 能正常工作
- [ ] 更新 `LOCAL_DEV_GUIDE.md` 中的仓库地址（如果需要）

## 总结

✅ **已完成**：

- Remote 配置完成
- 工作流脚本就绪
- 部署工具准备好

⏳ **待完成**：

- 推送 4 个提交到 fork
- 选择认证方式（推荐 SSH）

🎯 **建议**：
立即推送到 fork，这样你的代码就有了远程备份！

```bash
# 推荐使用 SSH（一次配置，永久使用）
git remote set-url origin git@github.com:pepsing/AFFiNE.git
# 配置好 SSH key 后
git push origin canary --force-with-lease
```
