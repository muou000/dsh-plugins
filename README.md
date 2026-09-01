# dsh-plugins

这是 DeepSeek Harness（DSH）的仓库外插件集合。它不是一个可直接运行的 DSH 发行版，也不是一个 npm 包。顶层仓库只做三件事：

1. 用 Git submodule 固定六个插件仓库的版本。
2. 保存共同的开发、测试和评测规则。
3. 提供一个批量运行各插件检查的 PowerShell 脚本。

每个一级目录都是独立 Git 仓库。插件的源码、依赖、测试、版本和发布记录都归各自仓库管理。

## 当前状态

当前组合包含六个插件：五个版本号为 `0.1.0`，`dsh-skill-evolution` 为 `0.2.0`。它们都有源码、测试和构建脚本，但都没有 Git 发布标签。因此应把它们视为尚未正式发布的源码版本，而不是已经稳定发布的产品。

仅克隆本仓库不会把插件启用到 DSH；实际启用状态由各 DSH profile 决定。安装和启用方法以各插件 README 为准。

| 插件 | 已实现的功能 | 主要限制 |
| --- | --- | --- |
| [`dsh-codegraph`](dsh-codegraph/) | 把外部 CodeGraph 的 `explore` 工具接入 DSH，并限制查询只能访问当前会话工作区 | 需要另行安装并初始化 CodeGraph；插件本身不建立或更新索引 |
| [`dsh-eval`](dsh-eval/) | 用同一批案例运行基线和候选命令，检查文件结果并生成 JSON/Markdown 报告 | 只适合受信任的本机进程；没有提供安全沙箱，也不会自动发布或启用候选 |
| [`dsh-memory`](dsh-memory/) | 用 SQLite 保存经过提议和审核的记忆，支持作用域、检索、注入、修订、删除、备份和 Markdown 导出 | 不会自动从所有对话中提炼记忆；真实模型带来的通用收益尚未得到充分验证 |
| [`dsh-skill-evolution`](dsh-skill-evolution/) | 保存不可变 Skill 候选，绑定 `dsh-eval` 证据，要求人工审批，并在开发工作区激活或回滚 | 仅支持 `workspace-development`；默认禁用激活，不能 production/global 发布；真实 CoEvoSkills canary 尚未运行 |
| [`dsh-model-router`](dsh-model-router/) | 按直接用户消息中的字面关键词选择模型，并在同一轮工具调用期间保持选择不变 | 不做语义分类、自动降级或成本优化；空配置不会改变当前模型 |
| [`improved-compact`](improved-compact/) | 替换 DSH 的基础上下文压缩器，并增加大工具结果裁剪、关键原文保留、请求预算告警和输出上限 | 会替换现有压缩提供者；现有本地实验中压缩更保真，但节省的 token 更少且延迟更高 |

更细的配置、数据位置和限制写在各插件自己的 README 中。项目整体的已完成事项和后续工作见 [`docs/ROADMAP.md`](docs/ROADMAP.md)。

## 环境要求

- Git，需要支持 submodule。
- Node.js `^22.19.0` 或 `>=24.0.0`。
- pnpm。四个插件声明 `pnpm@10.33.0`，`improved-compact` 当前声明 `pnpm@11.7.0`；请在插件目录中使用其 `package.json` 指定的版本。
- 与插件 `peerDependencies` 相符的 DSH 包。当前源码主要面向 DSH `0.1.1-rc.2` 和 `0.1.2-alpha.x` 的公开接口，具体范围以各插件的 `package.json` 为准。

`dsh-codegraph` 还需要外部 CodeGraph 程序。涉及真实模型的试验还需要相应模型配置和凭据，但普通单元测试不需要。

## 获取源码

```powershell
git clone --recurse-submodules https://github.com/muou000/dsh-plugins.git
cd dsh-plugins
git submodule status --recursive
```

如果顶层仓库已经存在但子仓库尚未初始化：

```powershell
git submodule update --init --recursive
```

`.gitmodules` 使用相对远程地址，默认假定顶层仓库和插件仓库位于同一个 GitHub 账号或组织。

## 开发和检查

顶层没有统一的 `package.json`，依赖需要在各插件目录中安装。例如：

```powershell
cd dsh-memory
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

这个脚本会对每个插件运行其 `pnpm run check`，也就是类型检查、单元测试和构建。它不会安装依赖，也不会自动运行真实模型试验、CodeGraph 真实运行测试、打包 smoke test 或其他 `eval:*` 脚本。

## 修改 submodule 的正确顺序

开始前分别查看顶层和目标插件的状态：

```powershell
git status --short --branch
git -C dsh-memory status --short --branch
```

功能和插件文档在插件仓库中修改。插件提交后，顶层只会看到该 submodule 指向了新的提交。正常顺序是：

1. 在插件仓库中完成修改、检查和提交。
2. 确认该提交已经存在于插件的远程仓库。
3. 在顶层仓库中提交更新后的 submodule 指针。

不要用顶层提交代替插件提交，也不要在插件有未提交修改时执行 `git submodule update --remote`。

## 文档索引

- [`AGENTS.md`](AGENTS.md)：在本工作区修改代码和文档时必须遵守的规则。
- [`docs/PLUGIN_STANDARD.md`](docs/PLUGIN_STANDARD.md)：新插件和现有插件的最低交付要求。
- [`docs/EVALUATION.md`](docs/EVALUATION.md)：涉及模型行为或策略变化时如何做可复现比较。
- [`docs/ROADMAP.md`](docs/ROADMAP.md)：当前完成情况、已知缺口和后续优先级。
- [`docs/CONTEXT_COST_OPTIMIZATION_2026-08-30.md`](docs/CONTEXT_COST_OPTIMIZATION_2026-08-30.md)：2026-08-30 的一次实验记录，不代表当前机器已经启用这些插件。
- [`docs/EVOLUTION_REUSE.md`](docs/EVOLUTION_REUSE.md)：早期“候选生成和自动改进”研究记录，不是当前已实现功能。

DSH 上游源码位于独立仓库，不是本仓库的 submodule。插件只能依赖上游公开导出的包、服务和事件；除非任务明确要求，不应为了插件修改 DSH 本体。
