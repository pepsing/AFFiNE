# 单人开发工作流指南

## 推荐策略：混合模式

作为唯一开发者，推荐采用**灵活但稳健**的分支策略：

### 分支结构

```
canary (主分支) ─── 稳定代码，随时可部署
  │
  ├─ feature/big-feature ─── 大功能开发（独立分支）
  │
  └─ 小修改直接在 canary ─── 快速迭代
```

## 什么时候用什么分支？

### ✅ 直接在 canary 开发（推荐用于）

**场景**：

- 🐛 Bug 修复
- 📝 文档更新
- ⚙️ 配置调整
- 🎨 小的 UI 改进
- 🔧 小的功能增强（1-2 小时能完成的）

**优点**：

- 快速迭代，不需要分支切换
- 提交历史清晰
- 随时可以部署到生产

**示例**：

```bash
# 直接在 canary 修改
git checkout canary
# ... 修改代码 ...
git add .
git commit -m "fix: 修复某个 bug"
git push origin canary

# 立即部署到生产（如果需要）
./scripts/build-docker-image.sh
```

### 🌿 使用特性分支（推荐用于）

**场景**：

- 🚀 新的大功能（需要多天开发）
- 🧪 实验性功能（不确定是否会用）
- 💥 重构代码（可能影响稳定性）
- 🔄 需要反复测试的修改
- ⚠️ 有风险的改动

**优点**：

- canary 保持稳定，生产随时可部署
- 可以在分支上自由实验
- 不想要了可以直接删除分支
- 可以同时开发多个功能

**示例**：

```bash
# 创建特性分支
git checkout -b feature/new-export-feature

# 开发、提交
git add .
git commit -m "feat: add export feature"
git push origin feature/new-export-feature

# 完成后合并到 canary
git checkout canary
git merge feature/new-export-feature
git push origin canary

# 删除特性分支
git branch -d feature/new-export-feature
git push origin --delete feature/new-export-feature
```

## 生产部署策略

### 推荐：从 canary 构建 + Tag 标记

```
canary ────► 构建镜像 ────► 打 Tag ────► 部署到生产
  │                           │
  └─ 保持稳定              └─ 版本追踪
```

### 实施步骤

#### 1. 确保 canary 稳定

```bash
# 如果有特性分支，先合并
git checkout canary
git merge feature/your-feature

# 运行测试（如果有）
yarn test

# 确认没有问题
git status
```

#### 2. 构建镜像

```bash
# 方式 1: 使用默认标签（时间戳）
./scripts/build-docker-image.sh

# 方式 2: 使用语义化版本
IMAGE_TAG=v1.0.0 ./scripts/build-docker-image.sh

# 方式 3: 使用日期+功能描述
IMAGE_TAG=20251113-plantuml ./scripts/build-docker-image.sh
```

#### 3. 打 Git 标签（重要！）

```bash
# 创建生产版本标签
git tag -a prod-20251113 -m "生产部署: PlantUML + 环境管理 + 分离部署"

# 或使用语义化版本
git tag -a v1.0.0 -m "首次生产版本"

# 推送标签到 fork
git push origin prod-20251113
# 或
git push origin v1.0.0
```

#### 4. 部署到生产

```bash
# 同步镜像到生产服务器
PROD_SERVER=192.168.1.100 IMAGE_TAG=prod-20251113 \
  ./scripts/sync-image-to-production.sh

# 或使用一键部署
PROD_SERVER=192.168.1.100 IMAGE_TAG=prod-20251113 \
  ./scripts/deploy-to-production.sh
```

## 完整工作流示例

### 场景 1: 修复一个 Bug

```bash
# 1. 直接在 canary 修复
git checkout canary

# 2. 修改代码
vim packages/frontend/core/src/xxx.ts

# 3. 提交
git add .
git commit -m "fix: 修复导出失败的问题"
git push origin canary

# 4. 如果需要立即部署
IMAGE_TAG=hotfix-$(date +%Y%m%d-%H%M) ./scripts/build-docker-image.sh
PROD_SERVER=192.168.1.100 ./scripts/sync-image-to-production.sh

# 5. 打标签记录
git tag -a prod-hotfix-$(date +%Y%m%d) -m "紧急修复: 导出功能"
git push origin --tags
```

### 场景 2: 开发一个新功能

```bash
# 1. 创建特性分支
git checkout -b feature/pdf-export

# 2. 开发过程中多次提交
git add .
git commit -m "feat: add pdf export basic structure"
git push origin feature/pdf-export

# ... 继续开发 ...

git commit -m "feat: implement pdf rendering"
git push origin feature/pdf-export

# 3. 功能完成，测试通过
git commit -m "feat: complete pdf export feature"
git push origin feature/pdf-export

# 4. 合并到 canary
git checkout canary
git merge feature/pdf-export
git push origin canary

# 5. 构建并部署
IMAGE_TAG=v1.1.0-pdf-export ./scripts/build-docker-image.sh
git tag -a v1.1.0 -m "新增 PDF 导出功能"
git push origin v1.1.0

# 6. 部署到生产
PROD_SERVER=192.168.1.100 IMAGE_TAG=v1.1.0-pdf-export \
  ./scripts/deploy-to-production.sh

# 7. 删除特性分支（可选）
git branch -d feature/pdf-export
git push origin --delete feature/pdf-export
```

### 场景 3: 同步官方更新

```bash
# 1. 确保 canary 是干净的
git checkout canary
git status

# 2. 同步官方更新
./scripts/sync-upstream.sh

# 3. 测试是否正常
yarn install
yarn affine dev -p @affine/web

# 4. 如果正常，部署到生产
IMAGE_TAG=v1.1.1-update-$(date +%Y%m%d) ./scripts/build-docker-image.sh
git tag -a v1.1.1 -m "同步官方更新至 $(date +%Y-%m-%d)"
git push origin v1.1.1

# 5. 部署
PROD_SERVER=192.168.1.100 IMAGE_TAG=v1.1.1-update-$(date +%Y%m%d) \
  ./scripts/deploy-to-production.sh
```

## 版本标签规范

### 推荐的标签命名

```bash
# 生产版本（语义化）
v1.0.0          # 主版本
v1.1.0          # 新功能
v1.1.1          # Bug 修复

# 生产版本（日期 + 描述）
prod-20251113-plantuml      # 2025-11-13 部署，包含 PlantUML 功能
prod-20251120-env-mgmt      # 2025-11-20 部署，环境管理更新

# 热修复
hotfix-20251113-export-bug  # 紧急修复
hotfix-20251115-auth-issue  # 认证问题修复

# 测试版本（不要部署到生产）
test-20251113-experiment    # 测试实验性功能
```

### 查看和使用标签

```bash
# 列出所有标签
git tag

# 查看某个标签的详情
git show prod-20251113

# 检出某个标签（用于回滚）
git checkout prod-20251113

# 基于标签创建新分支
git checkout -b rollback-branch prod-20251113

# 删除标签
git tag -d prod-20251113
git push origin --delete prod-20251113
```

## 分支保护策略

### canary 分支规则（自律）

作为唯一开发者，建立以下自律规则：

✅ **可以合并到 canary 的代码**：

- 已经测试过的代码
- Bug 修复
- 完成的功能
- 文档更新

❌ **不要合并到 canary 的代码**：

- 未完成的功能（半成品）
- 实验性代码（不确定是否保留）
- 可能导致不稳定的重构
- 临时调试代码

### 保持 canary 稳定的技巧

```bash
# 技巧 1: 提交前自检
git diff                    # 查看改动
yarn affine dev -p @affine/web  # 本地测试

# 技巧 2: 使用 stash 暂存未完成的工作
git stash save "WIP: 未完成的功能"
git checkout canary
# ... 做紧急修复 ...
git stash pop              # 恢复未完成的工作

# 技巧 3: 使用 commit --amend 修正错误
git commit --amend         # 修改最后一次提交
git push origin canary --force-with-lease

# 技巧 4: 定期清理
git branch -d feature/abandoned-feature  # 删除不用的分支
```

## 回滚策略

### 如果生产出现问题

#### 方式 1: 回滚到之前的 Docker 镜像

```bash
# 在生产服务器上
cd /opt/affine/.docker/selfhost-split

# 查看可用的镜像
docker images affine-custom

# 切换到旧版本
vi compose-app.yml
# 修改 image: affine-custom:prod-20251113

# 重启
docker compose -f compose-app.yml up -d
```

#### 方式 2: 基于标签重新构建

```bash
# 本地检出旧版本
git checkout prod-20251113

# 重新构建
IMAGE_TAG=rollback-$(date +%Y%m%d) ./scripts/build-docker-image.sh

# 部署
PROD_SERVER=192.168.1.100 IMAGE_TAG=rollback-$(date +%Y%m%d) \
  ./scripts/sync-image-to-production.sh

# 回到 canary 修复问题
git checkout canary
```

#### 方式 3: Git 回滚（谨慎使用）

```bash
# 创建回滚分支
git checkout -b rollback-temp

# 回滚到某个提交
git revert <bad-commit-hash>

# 测试并合并
git checkout canary
git merge rollback-temp
git push origin canary
```

## 最佳实践总结

### 日常开发流程

```
┌─────────────────────────────────────────────────┐
│          你的开发工作流                           │
├─────────────────────────────────────────────────┤
│                                                 │
│  小修改、Bug 修复                                │
│  ┌──────────┐                                  │
│  │  canary  │ ──► 直接提交 ──► 推送 ──► 部署    │
│  └──────────┘                                  │
│                                                 │
│  大功能、实验性修改                              │
│  ┌──────────┐     ┌────────────┐              │
│  │  canary  │ ──► │  feature   │ ──► 开发测试  │
│  └──────────┘     └────────────┘              │
│       ▲                 │                       │
│       └──── 合并 ────────┘                       │
│       │                                         │
│       ├──► 构建镜像 ──► 打标签 ──► 部署到生产     │
│                                                 │
└─────────────────────────────────────────────────┘
```

### 核心原则

1. ✅ **canary 始终保持稳定** - 随时可以部署到生产
2. 🌿 **大功能使用特性分支** - 保持 canary 干净
3. 🏷️ **部署前打标签** - 方便追踪和回滚
4. 📝 **提交信息清晰** - 使用 feat/fix/chore 前缀
5. 🔄 **定期同步官方** - 使用 sync-upstream.sh

### 检查清单

部署到生产前的检查：

- [ ] canary 分支代码已测试
- [ ] 没有未完成的功能
- [ ] 已经同步最新的官方更新（如果需要）
- [ ] 创建了 Git 标签
- [ ] 构建的镜像经过测试
- [ ] 准备好回滚方案（知道上一个稳定版本）

## 工具和命令速查

```bash
# 查看当前状态
git status
git log --oneline -5
git tag

# 同步官方更新
./scripts/sync-upstream.sh

# 构建并部署
./scripts/build-docker-image.sh
PROD_SERVER=192.168.1.100 ./scripts/deploy-to-production.sh

# 标签管理
git tag -a v1.0.0 -m "描述"
git push origin v1.0.0
git push origin --tags

# 分支管理
git branch                              # 查看本地分支
git branch -r                           # 查看远程分支
git branch -d feature/xxx               # 删除本地分支
git push origin --delete feature/xxx    # 删除远程分支
```

## 总结

**简单记忆**：

- 🐛 小改动 → 直接在 canary
- 🚀 大功能 → 创建 feature 分支
- 🏭 部署生产 → 从 canary 构建 + 打标签
- 🔄 同步更新 → sync-upstream.sh

这个策略既保证了灵活性，又确保了生产环境的稳定性！
