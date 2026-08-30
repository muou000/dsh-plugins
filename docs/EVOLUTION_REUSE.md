# 自进化组件复用决策

本文把文章中的方法和现有 DSH 插件映射到后续自进化闭环。结论不是立即引入一个“大而全”的 optimizer，而是保持生成、评测、审批、版本和部署各自可替换；`dsh-eval` 是唯一允许产生本工作区 policy decision 的评测入口。

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
| CoEvoSkills | Apache-2.0 audit snapshot | METHOD ONLY | generator + surrogate verifier + real-agent oracle 有启发，但仓库没有可直接导入的完整实现 |
| `evolution-replay` 等启发式评分 | accepted/rejected/evidence/input chars 加权 | AVOID AS EVAL | 不执行真实任务，不验证候选 artifact 或外部状态；只能作为队列排序或 UI 提示 |

## 实施顺序

1. 固定 `dsh-eval` manifest/report/scorer 契约，并补 Unix、真实模型和外部 sandbox provider；持续把 source CLI 与 built SDK 作为独立兼容层回归。
2. 新建独立 `dsh-evolution` orchestration 插件，只保存 candidate lineage、实验引用、审批、激活和回滚；不内嵌第二套 evaluator。
3. 先接一个确定性候选生成器和人工审批，证明审计写入、幂等恢复、停止条件和回滚。
4. 再以适配器方式试用 EvoSkill 生成与 `lmzhen` 状态/审批组件；每个依赖独立做 license、版本和故障注入验收。
5. Harbor provider 完成 hostile-candidate 隔离与可信资源计量后，才讨论有限范围自动晋级。

## 当前不做

- 不让运行中的插件覆盖稳定源码、skill 或 profile。
- 不把文章 demo 的单一任务、单一 judge 或平均分当作“自进化有效”。
- 不把 Python optimizer runtime 变成 DSH 核心依赖。
- 不在缺少 held-out、成本、延迟、安全、失败案例和回滚证据时自动选择 candidate。
