# dsh-plugins

`dsh-plugins` 是 DeepSeek Harness（DSH）的仓库外插件集合。顶层仓库不提供可运行的 DSH 发行版，也不是 npm 包；它用 Git submodule 固定各插件版本，并保存共同的开发规范、评测规则和检查脚本。

每个一级插件目录都是独立 Git 仓库。插件源码、依赖、测试、版本和发布记录由各自仓库管理，顶层仓库只保存文档、组合脚本和 submodule 指针。

## 包含的插件

| 插件 | 当前功能 | 主要边界 |
| --- | --- | --- |
| [`dsh-codegraph`](dsh-codegraph/) | 把外部 CodeGraph 查询工具接入 DSH，并默认限制到当前 session workspace | 需要单独安装和初始化 CodeGraph；插件不建立或更新索引 |
| [`dsh-eval`](dsh-eval/) | 成对运行 baseline 与 candidate，检查文件结果并生成带来源信息的报告 | 本地 runner 只适合受信任代码，报告不会自动发布或启用候选 |
| [`dsh-memory`](dsh-memory/) | 用 SQLite 保存经过提议和审核的知识，提供模型检索和 Markdown 浏览 | 模型只能提议，不能自行发布；生产验收仍有未完成门禁 |
| [`dsh-model-router`](dsh-model-router/) | 按直接用户消息中的字面规则选择模型，并在一轮内保持选择不变 | 不做语义分类、自动降级或动态成本优化 |
| [`dsh-skill-evolution`](dsh-skill-evolution/) | 管理不可变 Skill 候选、评测证据、人工审批和开发工作区回滚 | 仅支持 `workspace-development`，不提供 production/global 发布 |
| [`improved-compact`](improved-compact/) | 替换基础上下文压缩 Provider，增加分层裁剪、摘要校验和请求预算保护 | 会改变基础 profile 的压缩与 spill 配置，真实项目收益需单独评测 |

六个插件通过 npm 包提供安装版本；Git 发布标签目前不作为安装依据。克隆本仓库不会自动把任何插件启用到 DSH；安装、配置和停用方法以各插件 README 为准。

六个插件的 npm 发布名统一使用 `@muou000` scope，例如 `@muou000/dsh-codegraph`；
插件内部名称、配置行 id、CLI 名称和持久化格式继续使用原有的无 scope 稳定标识。

## 环境要求

- Git，且需要支持 submodule。
- Node.js `^22.19.0` 或 `>=24.0.0`。
- Corepack 和 pnpm。五个插件声明 `pnpm@10.33.0`，`improved-compact` 声明 `pnpm@11.7.0`；进入插件目录后应使用其 `package.json` 固定的版本。
- 与目标插件 `peerDependencies` 匹配的 DSH 公开包。

`dsh-codegraph` 还需要外部 CodeGraph 运行时。真实模型评测需要相应的模型配置和凭据，普通类型检查、单元测试和构建不需要。

## 获取源码

```powershell
git clone --recurse-submodules https://github.com/muou000/dsh-plugins.git
Set-Location dsh-plugins
git submodule status --recursive
```

已有顶层 checkout 但尚未初始化子仓库时运行：

```powershell
git submodule update --init --recursive
```

`.gitmodules` 使用相对远程地址，默认假定顶层仓库和各插件仓库位于同一个 GitHub 账号或组织。

## 开发与检查

顶层没有统一的 `package.json`。依赖需要在目标插件目录中安装，例如：

```powershell
Set-Location dsh-memory
corepack pnpm install --frozen-lockfile
corepack pnpm run check
```

从顶层检查全部已初始化插件：

```powershell
.\scripts\check-all.ps1
```

只检查指定插件：

```powershell
.\scripts\check-all.ps1 -Plugin dsh-memory,dsh-eval
```

批量脚本对每个插件运行 `pnpm run check`，即类型检查、普通测试和构建。它不会安装依赖，也不会自动运行真实模型试验、真实 CodeGraph 测试、打包 smoke、外部平台测试或其他 `eval:*` 命令。

## Submodule 工作流

开始修改前分别检查顶层和目标插件：

```powershell
git status --short --branch
git -C dsh-memory status --short --branch
```

功能、测试和插件自己的文档在插件仓库中修改。插件提交后，顶层只会显示 submodule 指针变化。正常发布顺序是：

1. 在插件仓库中完成修改、检查和提交。
2. 确认插件提交已经存在于其远程仓库。
3. 在顶层仓库中提交更新后的 submodule 指针。

不要用顶层提交代替插件提交，也不要在插件有未提交修改时执行 `git submodule update --remote`。

## 文档

- [`AGENTS.md`](AGENTS.md)：工作区代码和文档修改规则。
- [`docs/PLUGIN_STANDARD.md`](docs/PLUGIN_STANDARD.md)：插件的最低交付要求。
- [`docs/EVALUATION.md`](docs/EVALUATION.md)：模型行为或策略变化的可复现评测要求。
- [`docs/ROADMAP.md`](docs/ROADMAP.md)：当前完成情况和后续工作。
- [`docs/CONTEXT_COST_OPTIMIZATION_2026-08-30.md`](docs/CONTEXT_COST_OPTIMIZATION_2026-08-30.md)：2026-08-30 的实验快照，不代表当前部署状态。
- [`docs/EVOLUTION_REUSE.md`](docs/EVOLUTION_REUSE.md)：早期候选生成研究记录，不代表当前已实现功能。

DSH 上游源码位于独立仓库，不是本仓库的 submodule。各插件只依赖 DSH 公开导出的包、服务和事件。许可证以每个插件仓库中的 `LICENSE` 为准。
