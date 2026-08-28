# dsh-plugins

`dsh-plugins` 是 DeepSeek Harness（DSH）的仓库外插件集合，用于试验、评测并交付 agent 系统增强能力。顶层仓库负责统一规范、兼容版本和组合验证；每个一级子目录都是可独立开发、发布和回滚的 Git submodule。

## 插件目录

| 仓库 | 状态 | 目标 |
| --- | --- | --- |
| [`improved-compact`](improved-compact/) | 候选 | 优化上下文压缩、信息保真和 token 使用 |
| `dsh-eval` | 规划中 | 提供可复现实验、回归评测和候选晋级机制 |
| `dsh-memory` | 规划中 | 整理带来源的长期记忆，并支持巩固、遗忘和检索 |
| `dsh-skill-evolution` | 规划中 | 生成、评审和晋级 skill 候选版本 |

路线与先后关系见 [`docs/ROADMAP.md`](docs/ROADMAP.md)。

## 获取仓库

```powershell
git clone --recurse-submodules <dsh-plugins-repository-url>
cd dsh-plugins
git submodule status --recursive
```

已有顶层仓库时初始化插件：

```powershell
git submodule update --init --recursive
```

`improved-compact` 使用相对远程地址 `../improved-compact.git`，适合总控仓库和插件仓库位于同一个 GitHub 组织或用户下。如果实际托管位置不同，应在首次推送前修改 [`.gitmodules`](.gitmodules)。

## 连接 GitHub 远程

本地初始化不会代替你创建 GitHub 仓库。创建两个空远程仓库后，先推送插件，再推送引用它的顶层仓库：

```powershell
$githubOwner = '<github-user-or-organization>'
git -C improved-compact remote add origin "https://github.com/$githubOwner/improved-compact.git"
git -C improved-compact push -u origin main

git remote add origin "https://github.com/$githubOwner/dsh-plugins.git"
git submodule sync --recursive
git push -u origin main
```

`git submodule sync --recursive` 会让当前 checkout 按新增的顶层远程重新解析相对 URL。若插件与总控仓库不在同一 GitHub 用户或组织下，应改用插件的完整 URL。

## 开发方式

进入目标插件，在插件仓库中创建分支、提交代码并运行检查：

```powershell
cd improved-compact
pnpm install
pnpm run check
```

也可以从顶层检查所有已经初始化且提供 `check` 脚本的插件：

```powershell
./scripts/check-all.ps1
```

插件提交或切换版本后，顶层仓库会显示 submodule 指针变化。先提交并推送插件仓库，再在顶层仓库提交该指针；两类提交不要混为一个仓库的历史。

## 设计与质量规范

- [`AGENTS.md`](AGENTS.md)：agent 在整个工作区内工作的强制规则。
- [`docs/PLUGIN_STANDARD.md`](docs/PLUGIN_STANDARD.md)：插件仓库、运行时和发布契约。
- [`docs/EVALUATION.md`](docs/EVALUATION.md)：实验设计、指标和候选晋级门槛。
- [`docs/ROADMAP.md`](docs/ROADMAP.md)：能力分层及实施顺序。

DSH 上游源码不属于本仓库的 submodule，也不是插件可以随意修改的内部实现。需要联调时可以另行 checkout；插件应依赖 DSH 的公开包、服务和事件扩展点。
