# dsh-plugins

`dsh-plugins` 是 DeepSeek Harness（DSH）的仓库外插件集合，用于试验、评测并交付 agent 系统增强能力。顶层仓库负责统一规范、兼容版本和组合验证；每个一级插件目录都是可独立开发、发布和回滚的 Git submodule。

## 插件清单

清单按路线图依赖顺序排列。“已纳入组合”表示插件已有独立本地 Git 仓库，并由顶层仓库以 submodule gitlink 固定版本；它不等同于已经发布或允许自动晋级。

### 已纳入组合

| 阶段 | 仓库 | 能力 | 当前定位 |
| --- | --- | --- | --- |
| Phase 1 | [`dsh-eval`](dsh-eval/) | 配对评测、外部世界评分和发布门禁 | 开发候选；真实模型、Unix、外部沙箱和 canary 尚未完成 |
| Phase 1 | [`improved-compact`](improved-compact/) | 上下文预算、工具结果外置和压缩候选 | 开发候选，不自动晋级；保真较高，但 token 节省和延迟尚未达到原生基线 |
| Phase 1 | [`dsh-model-router`](dsh-model-router/) | 确定性、整轮稳定的模型路由 | 开发候选，不自动晋级；真实 provider 的质量、成本和缓存收益尚未验证 |
| Phase 1 | [`dsh-codegraph`](dsh-codegraph/) | 官方 CodeGraph 的工作区隔离 DSH 适配 | 当前代码导航实现；本机 `web` / `headless` profile 已启用 |
| Phase 2 | [`dsh-memory`](dsh-memory/) | 带来源、作用域、治理和回放的长期记忆 | 开发候选；keyless 基准通过，通用真实模型收益尚未验证 |

### 规划项

| 阶段 | 计划仓库 | 能力 | 建仓条件 |
| --- | --- | --- | --- |
| Phase 3 | `dsh-skill-evolution` | 从真实失败证据生成、评审、晋级和回滚 skill 候选 | 开始实现并明确最小 DSH 扩展点后再建立独立仓库和 submodule |

### 远程交付状态

以下状态于 2026-08-31 通过实际远程查询和提交比对核验。所有已纳入组合的插件仓库均已建立，远端 `main` 包含顶层 gitlink 固定的提交。

| 仓库 | 本地独立仓库 | GitHub 仓库 | 交付状态 |
| --- | --- | --- | --- |
| `improved-compact` | 已有并已纳入 submodule | 已存在 | 当前 `main` 和 gitlink 已推送 |
| `dsh-eval` | 已有并已纳入 submodule | 已存在 | 当前 `main` 和 gitlink 已推送 |
| `dsh-memory` | 已有并已纳入 submodule | 已存在 | 当前 `main` 和 gitlink 已推送 |
| `dsh-model-router` | 已有并已纳入 submodule | 已存在 | 当前 `main` 和 gitlink 已推送；原本地裸仓库远程保留为 `local` |
| `dsh-codegraph` | 已有并已纳入 submodule | 已存在 | 当前 `main` 和 gitlink 已推送；原本地裸仓库远程保留为 `local` |
| `dsh-skill-evolution` | 尚未建立 | 暂不需要 | 保持为路线图规划项，不加入 `.gitmodules` |

路线与先后关系见 [`docs/ROADMAP.md`](docs/ROADMAP.md)。
文章和现有插件的复用/禁用边界见 [`docs/EVOLUTION_REUSE.md`](docs/EVOLUTION_REUSE.md)。
本轮上下文与 token 成本改造、实测结果和未覆盖边界见 [`docs/CONTEXT_COST_OPTIMIZATION_2026-08-30.md`](docs/CONTEXT_COST_OPTIMIZATION_2026-08-30.md)。

## 获取仓库

以下命令以所有已纳入组合的插件提交均已推送到 `.gitmodules` 对应远程为前提：

```powershell
git clone --recurse-submodules <dsh-plugins-repository-url>
cd dsh-plugins
git submodule status --recursive
```

已有顶层仓库时初始化插件：

```powershell
git submodule update --init --recursive
```

各插件使用形如 `../dsh-eval.git` 的相对远程地址，适合总控仓库和插件仓库位于同一个 GitHub 组织或用户下。如果实际托管位置不同，应在首次推送前修改对应 URL。

## 连接 GitHub 远程

本地初始化不会代替你创建 GitHub 仓库。创建对应空远程仓库后，先检查插件是否已有 `origin`：没有时使用 `remote add`，已有本地或旧远程时使用 `remote set-url`，然后先推送插件，再推送引用它的顶层仓库。

```powershell
$githubOwner = '<github-user-or-organization>'
git -C improved-compact remote set-url origin "https://github.com/$githubOwner/improved-compact.git"
git -C improved-compact push -u origin main

git -C dsh-eval remote set-url origin "https://github.com/$githubOwner/dsh-eval.git"
git -C dsh-eval push -u origin main

git -C dsh-memory remote set-url origin "https://github.com/$githubOwner/dsh-memory.git"
git -C dsh-memory push -u origin main

git -C dsh-model-router remote set-url origin "https://github.com/$githubOwner/dsh-model-router.git"
git -C dsh-model-router push -u origin main

git -C dsh-codegraph remote set-url origin "https://github.com/$githubOwner/dsh-codegraph.git"
git -C dsh-codegraph push -u origin main

git remote set-url origin "https://github.com/$githubOwner/dsh-plugins.git"
git submodule sync --recursive
git push -u origin main
```

上例按当前 checkout 的实际远程状态区分了 `remote add` 与 `remote set-url`；其他环境应先以 `git -C <plugin> remote -v` 的结果为准。顶层仓库已经有 `origin` 时同样应使用 `remote set-url`，不要重复添加。`git submodule sync --recursive` 会让当前 checkout 按顶层远程重新解析相对 URL。若插件与总控仓库不在同一 GitHub 用户或组织下，应改用插件的完整 URL。

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
- [`docs/EVOLUTION_REUSE.md`](docs/EVOLUTION_REUSE.md)：自进化生成、评测、审批、sandbox 组件的版本化复用决策。

DSH 上游源码不属于本仓库的 submodule，也不是插件可以随意修改的内部实现。需要联调时可以另行 checkout；插件应依赖 DSH 的公开包、服务和事件扩展点。
