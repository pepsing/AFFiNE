# Fork 工作流配置指南

## 当前状态

你的本地仓库直接克隆自官方仓库：

```
origin → https://github.com/toeverything/AFFiNE (官方)
```

## 推荐配置

配置为标准的 Fork 工作流：

```
upstream → https://github.com/toeverything/AFFiNE (官方)
origin   → https://github.com/pepsing/AFFiNE (你的 Fork)
```

## 配置步骤

### 1. 在 GitHub 上创建 Fork

1. 访问 https://github.com/toeverything/AFFiNE
2. 点击右上角 "Fork" 按钮
3. 选择你的账号 (pepsing)
4. 等待 Fork 完成

### 2. 重新配置本地仓库

```bash
# 1. 将 origin 重命名为 upstream
git remote rename origin upstream

# 2. 添加你的 fork 作为 origin
git remote add origin https://github.com/pepsing/AFFiNE.git

# 3. 验证配置
git remote -v
```

应该显示：

```
origin     https://github.com/pepsing/AFFiNE.git (fetch)
origin     https://github.com/pepsing/AFFiNE.git (push)
upstream   https://github.com/toeverything/AFFiNE (fetch)
upstream   https://github.com/toeverything/AFFiNE (push)
```

### 3. 推送你的定制内容到 Fork

```bash
# 推送当前分支（包含你的 4 个定制提交）
git push origin canary

# 如果提示 force，说明 fork 和本地有差异
git push origin canary --force-with-lease
```

## 日常开发工作流

### 开发新功能

```bash
# 1. 确保 canary 是最新的
git checkout canary
git fetch upstream
git rebase upstream/canary

# 2. 创建功能分支（可选但推荐）
git checkout -b feature/my-feature

# 3. 开发、提交
git add .
git commit -m "feat: implement my feature"

# 4. 推送到你的 fork
git push origin feature/my-feature

# 5. 合并回 canary（本地）
git checkout canary
git merge feature/my-feature

# 6. 推送 canary
git push origin canary
```

### 同步官方更新

```bash
# 使用现有的同步脚本
./scripts/sync-upstream.sh

# 或手动执行
git fetch upstream
git rebase upstream/canary
git push origin canary --force-with-lease
```

### 部署到生产

```bash
# 方式 1: 使用一键部署脚本
PROD_SERVER=192.168.1.100 ./scripts/deploy-to-production.sh

# 方式 2: 分步执行
./scripts/build-docker-image.sh
PROD_SERVER=192.168.1.100 ./scripts/sync-image-to-production.sh
```

## 版本管理策略

### 推荐的分支结构

```
canary (主分支)
  ├── feature/plantuml         (已合并)
  ├── feature/env-management   (已合并)
  ├── feature/split-deployment (已合并)
  └── feature/your-next-feature (开发中)

生产环境标签:
  ├── v0.25.3-custom-20251113   (当前生产)
  └── v0.25.4-custom-20251120   (下一个版本)
```

### 创建生产版本标签

```bash
# 当准备部署到生产时
git tag -a v0.25.3-custom-$(date +%Y%m%d) -m "Production release with custom features"
git push origin v0.25.3-custom-$(date +%Y%m%d)
```

## 对比：Fork vs 直接开发

### Fork 开发（推荐）✅

**优点**:

- ✅ 有远程备份，代码安全
- ✅ 多设备同步方便
- ✅ 清晰的定制版本管理
- ✅ 可以与团队成员协作
- ✅ 保留贡献官方的可能性
- ✅ 灵活控制更新节奏

**缺点**:

- ⚠️ 需要维护 fork 同步（但有脚本）
- ⚠️ Git 工作流稍复杂（但更规范）

**适合场景**:

- ✅ 有定制需求
- ✅ 需要生产部署
- ✅ 需要版本管理
- ✅ 可能有团队协作

### 直接开发 ❌

**优点**:

- ✅ 简单直接
- ✅ 不需要管理 fork

**缺点**:

- ❌ 没有远程备份
- ❌ 无法推送到远程
- ❌ 多设备同步困难
- ❌ 代码丢失风险
- ❌ 无法与他人协作
- ❌ 官方更新可能冲突

**适合场景**:

- ⚠️ 只是学习研究
- ⚠️ 不需要定制
- ⚠️ 单设备开发

## 你的场景 → Fork 开发

基于以下理由，强烈建议使用 Fork：

1. **已有 4 个定制提交**

   - PlantUML 功能
   - 环境管理工具
   - 生产部署配置
   - 本地开发指南

2. **需要生产部署**

   - 需要稳定的版本管理
   - 需要构建和部署流程
   - 需要回滚能力

3. **内网环境**

   - Fork 可以作为内网代码源
   - 生产服务器可以从你的 Fork 拉取
   - 不受官方仓库影响

4. **持续迭代**
   - 后续还会有更多定制
   - 需要跟踪自己的修改历史
   - 可能需要维护多个版本

## 迁移检查清单

- [ ] 在 GitHub 上创建 Fork
- [ ] 重新配置本地 remote
- [ ] 推送现有修改到 Fork
- [ ] 测试 sync-upstream.sh 脚本
- [ ] 更新部署脚本（如果需要从 Fork 构建）
- [ ] 创建第一个生产版本标签
- [ ] 更新文档中的仓库地址

## 常见问题

### Q: Fork 会不会太重？

A: 不会，GitHub Fork 是轻量级的引用，不占用额外空间。

### Q: 如何贡献代码给官方？

A: 从你的 Fork 创建 PR 到官方仓库即可。你的定制功能不影响贡献其他改进。

### Q: 官方更新太快怎么办？

A: 使用 sync-upstream.sh 脚本定期同步，或者选择性合并重要更新。

### Q: 生产环境如何使用 Fork？

A: 方式不变，只是推送到你的 Fork 后再部署。或者直接从本地构建镜像。

### Q: 要不要把所有定制都提交到 Fork？

A: 环境相关的配置文件（.env.local 等）不要推送，其他定制功能可以推送。

## 总结

**你应该使用 Fork，因为你：**

1. ✅ 已经有定制功能
2. ✅ 需要生产部署
3. ✅ 需要版本管理
4. ✅ 需要代码备份

**立即行动：**

```bash
# 1. 去 GitHub Fork 仓库
# 2. 重新配置 remote
git remote rename origin upstream
git remote add origin https://github.com/pepsing/AFFiNE.git

# 3. 推送你的修改
git push origin canary --force-with-lease

# 4. 验证
git remote -v
```
