# 上下文与 Token 成本优化改造（2026-08-30）

## 范围与决策

本轮针对文章《一篇搞懂 AI Coding Agent 的 Token 成本控制》中与当前 DSH 直接相关的成本来源进行插件化改造：长历史、过大的工具结果、输出失控、记忆同步放大、昂贵模型缺少确定性分流、反复广泛搜索和缺少可比较的成本证据。文章可参考[此镜像](https://www.aixq.cc/41618.html)。DSH 上游 `cd5ef8148158c3a752a658978873241fdf8e2bbc` 未修改；所有行为通过公开 Cordis service、typed event、Loader patch 和插件配置接入。

改造不等同于自动晋级。确定性检查通过只证明实现和组合兼容；真实模型效果、供应商账单和生产缓存命中仍需要独立证据。

## 已实施改造

| 成本来源 | 插件 | 改造 | 失败与默认语义 |
| --- | --- | --- | --- |
| 请求历史逼近上下文上限 | `improved-compact` | 在 `agent/request` 与 `llm/stream` 公开事件上增加输入预算观测，支持 token 数或上下文占比的 warn/block 门槛 | 默认仅在 90% 时告警，不阻断请求；硬阻断必须显式配置 |
| 输出 token 无上限 | `improved-compact` | 可选地向模型请求施加 `maxOutputTokens` 上限 | 默认不覆盖用户或模型配置；仅在插件显式配置时生效 |
| 大型工具结果在后续轮次重复进入上下文 | `improved-compact` | 将 DSH 可逆 spill 阈值默认从 50,000 bytes 降至 8,192 bytes，正文存入 durable attachment store，模型上下文保留摘要、定位符与摘要哈希 | 外置仍可通过 locator 和 SHA-256 恢复原文；卸载时恢复原配置 |
| 压缩质量与成本不可同时比较 | `improved-compact` | 修复当前 DSH `ToolCallId` 契约兼容，固定原生/候选同案例复跑和报告 | 候选只作为可回滚实验；节省或延迟退化时不晋级 |
| 每次记忆变更重写全部 Markdown 投影 | `dsh-memory` | 内容寻址发布；有效 generation 上执行记录级增量更新，布局或 manifest 损坏时回退全量重建 | manifest 最后提交；显式 `verify` 仍会校验所有托管文件 |
| 10k 记忆记录的读取和检索放大 | `dsh-memory` | 将 record/revision 的 N+1 读取改为固定批量查询，并在启动 FTS 完整性约束下移除冗余 `DISTINCT` | 保留内容哈希、证据顺序、版本父子关系、作用域和私密字段检查 |
| token/cost 结论缺少可信门槛 | `dsh-eval` | 保留原有配对基线、token/cost/cache/output/latency 指标和失败闭合 gate，新增当前 DSH Session 事件 smoke | 自报 probe 明确不可用于自动晋级；本地报告继续为 `promotionEligible: false` |
| 所有任务默认使用同一模型，缺少可审计分流 | `dsh-model-router` | 按直接用户消息的显式规则确定 provider/model；首个直接用户消息决定整轮路由，工具续接不重新分类；调用前用公开 `resolveCallConfig` 精确校验 | 默认路由可保持现有选择；无静默 fallback、无 LLM 分类、无自动廉价重试；策略命中本身不等于成本下降 |
| 反复广泛搜索、读取造成工具往返 | `dsh-codegraph` | 复用官方 CodeGraph `1.6.0` 的持久符号图和 MCP `explore`；DSH 适配器只添加生命周期、提示、固定配置和 session 工作区 gate | 默认仅开放一个工具；缺失/越界路径在 MCP 前拒绝，未初始化或过期索引回退普通工具，权威结果仍由 `read`、编译器或测试确认 |

日志只记录预算数值、阶段和稳定标识，不记录用户正文、工具正文或记忆内容。

## 实测结果

| 证据 | 结果 |
| --- | --- |
| `improved-compact` 完整检查 | 6 个测试文件、26 个测试通过 |
| 当前 DSH 压缩复跑，5 次 x 4 case | 候选 compaction/anchor/downstream 均为 100%；原生 anchor 95%，downstream macro 87.5%、micro 90% |
| 压缩成本权衡 | 候选 token 节省 65.505%、均值 22.379 ms；原生 71.147%、15.730 ms，故不晋级压缩候选 |
| spill smoke | 39,955 bytes 工具结果在后续上下文中降为 8,192 bytes，减少 31,763 bytes（79.50%），原文可按 SHA-256 与 locator 恢复 |
| `dsh-memory` 完整检查 | 13 个测试文件、82 个测试通过；组合测试 2 个、操作测试 10/10 通过 |
| 10k 记忆基准 | 首建 51,838.563 ms；warm rebuild 10,436.633 ms；单记录增量 2,953.343 ms；检索 p50 63.076 ms、p95 77.800 ms |
| 投影写放大 | 首建写 10,004 个文件，warm rebuild 写 0 个，单记录更新写 1 个；最终 10,004 个投影文件校验通过 |
| `dsh-eval` 完整检查 | 12 个测试文件、36 个测试通过；当前 DSH 的 service、Session 事件、usage、无内容 probe 和卸载检查全部通过 |
| `dsh-eval` keyless 校准与打包 | baseline 0/5、candidate 5/5、0 个回归；干净 tarball 的 8 项检查全部通过 |
| `dsh-model-router` 检查与组合测试 | `pnpm run check`：5 个测试文件、20 个测试通过；Loader/生命周期组合：2 个文件、4 个测试通过 |
| `dsh-model-router` 干净打包 | 4 项 pack smoke 全部通过，`sourceDirty: false`；提交 `3fbd41ad7fa2315d794ff44e3262acc2ce85288c`，tarball SHA-256 `3e235e55d625ffd376f7f56ff697b3de8a98c7d11a89d4794ee5901e6958578d`，10,028 bytes |
| `dsh-code-index` 检查与组合测试 | `pnpm run check`：5 个测试文件、27 个测试通过；Loader/FS/Tools 组合：2 个文件、8 个测试通过 |
| `dsh-code-index` 干净打包 | 4 项 pack smoke 全部通过，`sourceDirty: false`；提交 `534d35f93554094eea8f7b91fa48a0cc3170f922`，tarball SHA-256 `bcdb1315449acc73a964c5546c533f100605ddbeb80168241c9bd11f9e02b204`，17,018 bytes |
| `dsh-codegraph` 检查与组合测试 | `pnpm run check`：4 个测试文件、7 个测试通过；Loader/生命周期组合：2 个文件、2 个测试通过；官方运行时建图并经 DSH 查询：1 个测试通过 |
| `dsh-codegraph` 运行时与索引 | 官方 Windows x64 `1.6.0` 归档 SHA-256 `cd76c3c3391f2d40abef12b142151950b6d77abc2d8429e648f89eaa90f5b68a`；同步后的组合仓库索引为 138 files、2,209 nodes、7,477 edges，无 pending change |
| `dsh-codegraph` 干净打包与 profile | 提交 `e6bf61e39301cf083f0b5967d45514c6603e710e`；4 项 pack smoke 通过，tarball SHA-256 `3b2f4960c487ba2196315027cf8081d8e29d53745eac36e70c28d0a5f01fcf83`，13,103 bytes；`web` 真实启动/停止及 `headless` 配置合成通过 |

## 明确保留的边界

- 未运行真实模型评测，也未对账供应商账单；当前数字不能证明生产 token 费用下降了同一比例。
- 未运行 Unix 矩阵、外部 hostile-candidate sandbox、shadow/canary 或回滚演练。
- 记忆首次 10k 全量投影仍约 51.8 秒；本轮优化的是稳态写放大和热路径，不把首建速度包装成改进。
- 已新增确定性的 `dsh-model-router` 并把代码导航切换到官方 CodeGraph，但没有实现自动级联、LLM 分类、动态裁剪工具目录或自动晋级。路由规则误命中、索引过期、上游版本变化和工具使用习惯仍可能影响质量、缓存形态与实际费用，必须用配对任务评测。
- `dsh-model-router` 当前只证明规则、整轮稳定性、精确预校验和生命周期契约；`dsh-codegraph` 当前只证明固定运行时、真实建图查询、作用域控制、Loader/profile 组合和卸载静默，不证明减少了生产工具轮次或 token。
- 未调整 DSH 核心已有的 skill、subagent、workflow 或模型适配层；固定前缀缓存的实际命中率仍由最终 prompt 结构和上游供应商决定。

## 版本与回滚

| 插件 | 当前固定版本 | 回滚版本 |
| --- | --- | --- |
| `improved-compact` | `b5dea4fb115068e5c3efcf44973b25c28801fabc` | `b19e1777f790a76bb513d3d5790c0fe5687aa2af` |
| `dsh-memory` | `9063685a3a62c4e451fd7311894f51daf38da3e0` | `7e2d03f5ecced0c35580d8d7513c37d658385bd5` |
| `dsh-eval` | `b2e5110eefa3d9e0c8d749f46deef7d88f88eb5f` | `7fe79034a81af50bc60a176173a21b1e9608bf5e` |
| `dsh-model-router` | `3fbd41ad7fa2315d794ff44e3262acc2ce85288c` | 未启用；移除 profile row 或恢复此前顶层 gitlink |
| `dsh-codegraph` | `e6bf61e39301cf083f0b5967d45514c6603e710e` + upstream `1.6.0` | 从 profile 移除 `dsh-codegraph`，保留索引；需要旧导航时再启用下一行的基线 |
| `dsh-code-index` | `534d35f93554094eea8f7b91fa48a0cc3170f922` | 当前未启用；作为无外部运行时的回滚基线 |

回滚以插件仓库提交为单位，再更新顶层 gitlink；不需要修改 DSH 本体。跨插件启用顺序为：先部署 `dsh-eval` 的观测与 gate，再启用 `improved-compact` 的预算/spill 和 `dsh-memory` 的增量投影；确认路由策略有配对证据后再启用 `dsh-model-router`。代码导航默认启用 `dsh-codegraph`，失败时先禁用其 profile bundle，再按需启用 `dsh-code-index`；两者不要同时启用。
