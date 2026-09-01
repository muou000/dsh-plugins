# 自进化组件复用决策

本文把文章中的方法和现有 DSH 插件映射到后续自进化闭环。结论不是立即引入一个“大而全”的 optimizer，而是保持生成、评测、审批、版本和部署各自可替换；`dsh-eval` 是唯一允许产生本工作区 policy decision 的评测入口。

## 成本能力的角色边界

本轮新增的路由和代码导航是运行时的确定性基础能力，不是候选生成器，也不拥有晋级权限。它们的输出必须通过 DSH 正常事件可回放，并由 `dsh-eval` 在配对任务上评估；因此可以先独立启用或禁用，不会把一次规则命中或一次索引查询直接变成“自优化成功”。

| 能力 | 运行时职责 | 自进化闭环中的使用方式 |
| --- | --- | --- |
| `dsh-model-router` | 根据显式规则选择并固定整轮 provider/model，调用前精确校验 | 作为可版本化的 policy candidate；比较质量、失败、延迟、token、成本和安全后再审批 |
| `dsh-codegraph` | 经工作区 gate 调用固定版本 CodeGraph，按需返回持久符号图和有界源码结果 | 作为工具策略 candidate；与普通 DSH 文件搜索比较，不把图结果当正确性证明 |
| `improved-compact` / `dsh-memory` | 控制上下文与记忆投影的运行时成本 | 继续通过固定 manifest、回放和外部状态验证进入候选比较 |

## 采用边界

```text
真实失败证据 -> 候选生成 -> development/validation -> held-out dsh-eval
                                                   |
                                             人工/策略审批
                                                   |
                                     版本化激活 -> canary -> 回滚
```

- 生成器不能读取 held-out case、期望答案、scorer 或其他候选结果。
- 稳定版本和候选版本分开；候选必须记录父版本、输入证据、配置、代码/内容摘要和时间。
- 只有真实加载候选 artifact、执行任务并验证外部世界状态的结果能进入晋级判断。
- LLM judge、accepted/rejected 数量、文本长度和单次 replay 启发式只能作诊断信号。
- 本地 `dsh-eval` 当前不隔离恶意候选，报告固定不可自动晋级；自动闭环要等外部 sandbox、可信 telemetry、影响上限、熔断和回滚演练完成。

## Reuse / Adapt / Avoid

| 来源 | 固定依据 | 决策 | 原因与约束 |
| --- | --- | --- | --- |
| `JayDong9130/dsh-evolution-lab` | MIT, `6bc8a776...` | ADAPT | task/arena/process/verifier-first contract 是最接近的基底；eval 内核未公开导出且锁定旧 DSH，当前 `dsh-eval` 独立实现公开契约，不直接依赖该包 |
| `lmzhen/dsh-evolution` | MIT, `9f0f7299...`, `0.1.0-rc.66` | REUSE LATER | 可评估 state-storage、approval、IO 和 curator；必须精确 pin、加 DSH 兼容测试，并把审批写入做成 single-writer/幂等、审计失败关闭 |
| `dsh-continual-evolve` | MIT, `d6826e4c...` | SCHEMA ONLY | case/cell/scoreboard/rollback 类型可参考；其 benchmark 只传 candidate label/文本，没有实际加载候选，不能作为 evaluator |
| EvoSkill | Apache-2.0, `36f6f049...` | ADAPT GENERATOR | failure -> candidate -> validation -> frontier 流程有用；缺 held-out/canary，Python runner 不进入核心 |
| Harbor | Apache-2.0, v0.16.1 audit snapshot | EXTERNAL PROVIDER | 适合未来 `dsh-eval-harbor` 容器任务/verifier provider；核心保持 Node/DSH 原生，外部 provider 必须回传可验证 artifact/session 身份 |
| SE-Agent | MIT, `c188ce1b...` | IDEAS ONLY | revision/recombination/refinement 与跨轨迹压缩可用于候选生成；单次模型裁判和启发式过滤不能晋级 |
| EvoAgentX | MIT, `d77fd6b9...` | IDEAS ONLY | train/dev/test benchmark 与 optimizer registry 可参考；并发 evaluator 丢弃失败样本，不能复用其聚合结果 |
| AutoSkill | audit snapshot 无 LICENSE | NO CODE REUSE | 可独立实现 frozen replay、promotion test、champion registry 概念；在许可证明确前不复制代码或资产 |
| CoEvoSkills | Apache-2.0, `da5a53db...` | ADAPT EXTERNAL WORKER | 当前已有 Python/Harbor 完整 runner；实验适配器只调用固定、干净 checkout 的 bundled task，生成结果仍只是候选，不能复用其 reward/PASS 作为 DSH 晋级证据 |
| `evolution-replay` 等启发式评分 | accepted/rejected/evidence/input chars 加权 | AVOID AS EVAL | 不执行真实任务，不验证候选 artifact 或外部状态；只能作为队列排序或 UI 提示 |

## 实施顺序

1. 保持 `dsh-eval` manifest/report/scorer 为唯一评测契约，并补 Unix、真实模型和外部 sandbox provider；持续把 source CLI 与 built SDK 作为独立兼容层回归。
2. `dsh-skill-evolution` 开发期首版已建立独立本地仓库：保存内容寻址候选、lineage、评测绑定、human approval、工作区激活、回滚、worker job 和审计；不内嵌第二套 evaluator。
3. 对 CoEvoSkills adapter 在 Linux/macOS、Docker、模型和 exact-clean `da5a53db...` checkout 上运行一个真实 bundled-task canary；完成前保持 experimental/NOT RUN。
4. 补 human command 权限入口、deactivate/revoke/quarantine/export/purge，再评估自动失败采集；任何自动生成仍只产生候选。
5. `dsh-eval` 外部 provider 完成 hostile-candidate 隔离与可信资源计量后，才讨论有限范围自动晋级和 production/global 作用域。

## 2026-08-31 实现快照

`dsh-skill-evolution` 已建立独立 Git 仓库，并由顶层以 submodule 固定到提交 `2f4a6f5`。0.2.0 的 Windows 工作树类型检查、43 项普通测试、真实 Cordis Loader 组合，以及从已安装 tarball 读取固定 `coevoskills`、解析 bundle patch、执行已安装入口和热卸载/重载的 smoke 已通过；完整证据在插件的 `docs/ACCEPTANCE_LEDGER.md`、`evals/reports/2026-08-31-local-verification.json` 和 `evals/reports/2026-08-31-profile-migration.json`。

该版本随包提供固定 `coevoskills` 管理 Skill，并已在本机 web/headless profile 替换旧全局 filesystem Skill；旧目录按原树摘要移到扫描范围外的可恢复归档。默认仍禁止激活，只允许显式 `workspace-development`。本地 `dsh-eval` 报告固定 `promotionEligible: false`，需要 human 精确确认所有 blocker；没有可鉴权的人类命令 UI 或 production/global 激活。CoEvoSkills adapter 已做语法检查和 mock worker 协议测试，但真实 Python/Docker/Harbor/模型 canary 未运行。

## 当前不做

- 不让运行中的插件覆盖稳定源码、skill 或 profile。
- 不把文章 demo 的单一任务、单一 judge 或平均分当作“自进化有效”。
- 不把 Python optimizer runtime 变成 DSH 核心依赖。
- 不在缺少 held-out、成本、延迟、安全、失败案例和回滚证据时自动选择 candidate。
