# AFFiNE Fork 开发工作流

> 本文档说明如何在 Fork 仓库中开发自定义特性，同时跟随上游仓库的最新更新

## 目录

- [工作流概览](#工作流概览)
- [初始配置](#初始配置)
- [分支策略](#分支策略)
- [日常开发流程](#日常开发流程)
- [同步上游更新](#同步上游更新)
- [处理冲突](#处理冲突)
- [版本发布策略](#版本发布策略)
- [最佳实践](#最佳实践)
- [常见场景](#常见场景)

---

## 工作流概览

```
上游仓库 (toeverything/AFFiNE)
    ↓ (同步)
你的 Fork (your-username/AFFiNE)
    ↓ (clone)
本地仓库
    ├── main (跟随上游)
    ├── custom-main (你的主分支，包含所有自定义特性)
    ├── feature/xxx (独立功能分支)
    └── upstream-sync (临时同步分支)
```

---

## 初始配置

### 1. 添加上游仓库为 remote

```bash
# 查看当前 remote
git remote -v

# 添加上游仓库
git remote add upstream https://github.com/toeverything/AFFiNE.git

# 验证
git remote -v
# 应该看到：
# origin    https://github.com/YOUR_USERNAME/AFFiNE.git (fetch)
# origin    https://github.com/YOUR_USERNAME/AFFiNE.git (push)
# upstream  https://github.com/toeverything/AFFiNE.git (fetch)
# upstream  https://github.com/toeverything/AFFiNE.git (push)
```

### 2. 获取上游仓库的所有分支

```bash
git fetch upstream
```

### 3. 创建你的自定义主分支

```bash
# 基于当前的 main/canary 创建你的主分支
git checkout -b custom-main

# 推送到你的 Fork
git push -u origin custom-main
```

---

## 分支策略

### 分支类型说明

| 分支名称          | 用途                           | 来源                  | 是否推送到 Fork |
| ----------------- | ------------------------------ | --------------------- | --------------- |
| `main` / `canary` | 跟随上游的主分支               | upstream              | 是              |
| `custom-main`     | 你的主分支，包含所有自定义特性 | 基于 main 创建        | 是              |
| `feature/xxx`     | 单个功能开发分支               | 基于 custom-main 创建 | 是              |
| `upstream-sync`   | 临时同步分支                   | 基于 upstream/canary  | 是（可选）      |
| `hotfix/xxx`      | 紧急修复分支                   | 基于 custom-main      | 是              |

### 分支命名规范

```bash
# 功能开发
feature/user-authentication
feature/custom-theme
feature/ai-integration

# Bug 修复
bugfix/login-error
bugfix/search-crash

# 紧急修复
hotfix/security-patch
hotfix/data-loss

# 实验性功能
experimental/new-ui
experimental/performance-boost
```

---

## 日常开发流程

### 开发新功能

```bash
# 1. 确保 custom-main 是最新的
git checkout custom-main
git pull origin custom-main

# 2. 创建功能分支
git checkout -b feature/your-feature-name

# 3. 开发和提交
git add .
git commit -m "feat: add your feature description"

# 4. 推送到你的 Fork
git push -u origin feature/your-feature-name

# 5. 功能完成后，合并到 custom-main
git checkout custom-main
git merge feature/your-feature-name

# 6. 推送更新
git push origin custom-main

# 7. 删除功能分支（可选）
git branch -d feature/your-feature-name
git push origin --delete feature/your-feature-name
```

### 提交信息规范

使用 [Conventional Commits](https://www.conventionalcommits.org/) 规范：

```bash
# 新功能
git commit -m "feat: add custom login page"
git commit -m "feat(ui): implement dark mode toggle"

# Bug 修复
git commit -m "fix: resolve search indexing issue"
git commit -m "fix(auth): prevent duplicate login attempts"

# 文档
git commit -m "docs: update build guide"

# 样式调整
git commit -m "style: format code with prettier"

# 重构
git commit -m "refactor: simplify user service logic"

# 性能优化
git commit -m "perf: optimize database queries"

# 测试
git commit -m "test: add unit tests for auth module"

# 构建/配置
git commit -m "build: update dependencies"
git commit -m "chore: update docker configuration"
```

---

## 同步上游更新

### 方式一：定期同步（推荐）

**建议频率**: 每周或每两周同步一次

```bash
# 1. 切换到 main 分支
git checkout main

# 2. 获取上游最新代码
git fetch upstream

# 3. 合并上游更新（使用 rebase 保持历史清晰）
git rebase upstream/canary
# 或者使用 merge（保留合并历史）
# git merge upstream/canary

# 4. 推送到你的 Fork
git push origin main --force-with-lease

# 5. 将上游更新合并到你的 custom-main
git checkout custom-main
git merge main

# 6. 解决可能的冲突（见下文）
# ... 解决冲突 ...

# 7. 推送更新后的 custom-main
git push origin custom-main
```

### 方式二：基于特定版本同步

```bash
# 1. 查看上游的 release 版本
git fetch upstream --tags
git tag | grep -v 'canary\|beta' | sort -V | tail -10

# 2. 切换到你想要的版本
git checkout main
git merge v0.26.0  # 例如合并 v0.26.0

# 3. 推送到 Fork
git push origin main

# 4. 合并到 custom-main
git checkout custom-main
git merge main
git push origin custom-main
```

### 方式三：使用临时分支同步（谨慎操作）

```bash
# 1. 创建临时同步分支
git checkout -b upstream-sync upstream/canary

# 2. 将你的自定义特性应用到新分支
git cherry-pick <commit-hash-1>
git cherry-pick <commit-hash-2>
# 或批量 cherry-pick
git cherry-pick main..custom-main

# 3. 测试新分支
yarn install
yarn affine @affine/native build
# ... 运行测试 ...

# 4. 如果一切正常，替换 custom-main
git checkout custom-main
git reset --hard upstream-sync
git push origin custom-main --force-with-lease

# 5. 清理临时分支
git branch -D upstream-sync
```

---

## 处理冲突

### 冲突场景

当上游代码与你的自定义代码发生冲突时：

```bash
# 合并时出现冲突
git checkout custom-main
git merge main

# 会看到类似输出：
# Auto-merging packages/frontend/core/src/components/login.tsx
# CONFLICT (content): Merge conflict in packages/frontend/core/src/components/login.tsx
# Automatic merge failed; fix conflicts and then commit the result.
```

### 解决冲突步骤

```bash
# 1. 查看冲突文件
git status

# 2. 编辑冲突文件
# 在编辑器中找到冲突标记：
# <<<<<<< HEAD (你的代码)
# =======
# >>>>>>> main (上游代码)

# 3. 手动解决冲突，保留需要的代码

# 4. 标记冲突已解决
git add <冲突文件>

# 5. 完成合并
git commit

# 6. 推送
git push origin custom-main
```

### 冲突解决策略

**策略一：保留自定义特性优先**

- 当你的特性与上游冲突时，优先保留自定义逻辑
- 适用于核心业务逻辑

**策略二：采纳上游更新优先**

- 对于框架层面、性能优化、安全修复等
- 然后在此基础上重新实现你的特性

**策略三：两者结合**

- 分析冲突原因，找到最佳平衡点
- 可能需要重构部分代码

### 使用工具辅助

```bash
# 使用可视化工具
git mergetool

# 推荐工具：
# - VS Code 内置的 Git 冲突解决器
# - Sourcetree
# - GitKraken
# - Meld（Linux）
```

---

## 版本发布策略

### 自定义版本号管理

为你的 Fork 创建独立的版本标识：

```bash
# 基于上游版本创建你的版本
# 格式：v{上游版本}-custom.{自定义版本号}

# 示例：基于 v0.25.3 的第一个自定义版本
git tag v0.25.3-custom.1
git push origin v0.25.3-custom.1

# 更新后
git tag v0.25.3-custom.2
git push origin v0.25.3-custom.2

# 同步到上游 v0.26.0 后
git tag v0.26.0-custom.1
git push origin v0.26.0-custom.1
```

### 发布流程

```bash
# 1. 确保所有测试通过
yarn test
yarn build

# 2. 更新 CHANGELOG（如果有）
# 编辑 CHANGELOG.md

# 3. 创建版本标签
git tag -a v0.25.3-custom.1 -m "Custom release based on v0.25.3
- feat: add custom feature A
- feat: add custom feature B
- fix: fix issue C"

# 4. 推送标签
git push origin v0.25.3-custom.1

# 5. 在 GitHub 上创建 Release（可选）
# 访问你的 Fork，在 Releases 页面创建新版本
```

---

## 最佳实践

### 1. 保持自定义代码模块化

```bash
# 推荐的目录结构
packages/
  frontend/
    custom/              # 你的自定义功能
      auth/
      theme/
      features/
  backend/
    custom/              # 你的后端自定义
      services/
      controllers/
```

**好处**：

- 减少与上游代码的冲突
- 易于维护和升级
- 方便回馈上游（如果合适）

### 2. 使用配置文件管理自定义

```typescript
// packages/frontend/custom/config.ts
export const CUSTOM_CONFIG = {
  enableCustomAuth: true,
  enableCustomTheme: true,
  customFeatures: ['feature-a', 'feature-b'],
};
```

### 3. 文档化你的修改

在项目根目录创建 `CUSTOM_CHANGES.md`：

```markdown
# 自定义修改清单

## v0.25.3-custom.1

### 新增功能

- [x] 自定义登录页面 (packages/frontend/custom/auth)
- [x] 深色主题切换 (packages/frontend/custom/theme)

### 修改的上游文件

- packages/frontend/core/src/app.tsx (第 45 行)

  - 原因：集成自定义主题
  - 风险：中等，可能与上游更新冲突

- packages/backend/server/src/config/config.ts (第 12 行)
  - 原因：添加自定义配置项
  - 风险：低

### 已知问题

- [ ] 自定义主题在移动端显示异常
- [ ] 待优化：登录性能
```

### 4. 定期测试上游更新

建立测试分支：

```bash
# 每次同步前先在测试分支验证
git checkout -b test-upstream-merge
git merge upstream/canary

# 运行完整测试
yarn install
yarn build
yarn test

# 如果通过，再合并到 custom-main
git checkout custom-main
git merge test-upstream-merge
git branch -D test-upstream-merge
```

### 5. 自动化同步检查

使用 GitHub Actions 定期检查上游更新：

创建 `.github/workflows/sync-upstream.yml`：

```yaml
name: Check Upstream Updates

on:
  schedule:
    # 每周一早上 9 点检查
    - cron: '0 9 * * 1'
  workflow_dispatch:

jobs:
  check-updates:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Add upstream
        run: |
          git remote add upstream https://github.com/toeverything/AFFiNE.git
          git fetch upstream

      - name: Check for updates
        run: |
          BEHIND=$(git rev-list --count HEAD..upstream/canary)
          echo "Behind upstream by $BEHIND commits"

          if [ $BEHIND -gt 0 ]; then
            echo "::warning::Upstream has $BEHIND new commits"
          fi

      - name: Create issue if behind
        if: steps.check.outputs.behind > 10
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: '上游仓库有重要更新',
              body: '上游仓库已有超过 10 个新提交，建议尽快同步。'
            })
```

---

## 常见场景

### 场景 1：只想要上游的某个特定功能

```bash
# 1. 找到上游实现该功能的 commit
git log upstream/canary --oneline | grep "feature name"

# 2. Cherry-pick 该 commit
git checkout custom-main
git cherry-pick <commit-hash>

# 3. 推送
git push origin custom-main
```

### 场景 2：想贡献代码回上游

```bash
# 1. 基于上游最新代码创建分支
git checkout -b contribute/feature-name upstream/canary

# 2. 实现功能
# ... 编码 ...

# 3. 推送到你的 Fork
git push origin contribute/feature-name

# 4. 在 GitHub 上创建 Pull Request
# 目标：toeverything/AFFiNE:canary
# 来源：your-username/AFFiNE:contribute/feature-name
```

### 场景 3：上游发布了重大版本更新

```bash
# 1. 创建备份分支
git checkout custom-main
git checkout -b custom-main-backup

# 2. 在新分支测试
git checkout -b test-v0.26.0 upstream/v0.26.0

# 3. 逐个应用你的自定义功能
git cherry-pick <commit-1>
git cherry-pick <commit-2>

# 4. 完整测试
yarn install
yarn build
yarn test

# 5. 如果成功，更新 custom-main
git checkout custom-main
git reset --hard test-v0.26.0
git push origin custom-main --force-with-lease
```

### 场景 4：需要回退到某个稳定版本

```bash
# 1. 查看历史版本
git tag --list | grep custom

# 2. 创建新分支基于旧版本
git checkout -b rollback v0.25.3-custom.1

# 3. 如果确认回退，更新 custom-main
git checkout custom-main
git reset --hard v0.25.3-custom.1
git push origin custom-main --force-with-lease

# 4. 打上回退标签
git tag v0.25.3-custom.1-rollback
git push origin v0.25.3-custom.1-rollback
```

### 场景 5：管理多个自定义版本

```bash
# 为不同用途维护不同分支
git checkout -b custom-stable   # 稳定版本
git checkout -b custom-dev      # 开发版本
git checkout -b custom-experimental  # 实验性功能

# 功能分级合并
experimental → dev → stable → main
```

---

## Git 配置优化

### 推荐的 Git 配置

```bash
# 设置默认的 pull 策略为 rebase
git config pull.rebase true

# 自动清理已合并的本地分支
git config fetch.prune true

# 设置更友好的冲突标记
git config merge.conflictStyle diff3

# 启用自动修正
git config help.autocorrect 1

# 彩色输出
git config color.ui auto
```

### 有用的 Git 别名

在 `~/.gitconfig` 中添加：

```ini
[alias]
    # 查看分支图
    lg = log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit

    # 快速同步上游
    sync = !git fetch upstream && git merge upstream/canary

    # 查看自定义提交
    custom = log --oneline --no-merges main..custom-main

    # 查看上游新提交
    upstream-new = log --oneline --no-merges custom-main..upstream/canary

    # 清理已合并分支
    cleanup = !git branch --merged | grep -v '\\*\\|main\\|custom-main' | xargs -n 1 git branch -d
```

---

## 总结

### 快速参考命令

```bash
# 日常开发
git checkout -b feature/xxx       # 创建功能分支
git commit -m "feat: xxx"         # 提交
git checkout custom-main && git merge feature/xxx  # 合并

# 同步上游
git fetch upstream                # 获取上游更新
git checkout main && git merge upstream/canary  # 更新 main
git checkout custom-main && git merge main      # 合并到 custom-main

# 版本管理
git tag v0.25.3-custom.1          # 创建版本标签
git push origin --tags            # 推送标签

# 查看状态
git log main..custom-main         # 查看自定义提交
git log custom-main..upstream/canary  # 查看上游新提交
```

### 关键原则

1. **main 分支永远跟随上游** - 不要在 main 上直接开发
2. **custom-main 是你的主分支** - 所有自定义功能都在这里
3. **定期同步** - 不要让你的 Fork 落后太多
4. **模块化开发** - 减少与上游的耦合
5. **充分测试** - 每次同步后都要测试
6. **做好文档** - 记录所有自定义修改

---

**祝开发顺利！记得定期备份重要分支。**
