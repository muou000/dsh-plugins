# DSH 仓库外插件规范

本文定义 `dsh-plugins` 下独立插件仓库的最低交付要求。具体插件可以增加更严格的规则，但不得削弱生命周期、可回放性、安全和评测要求。

## 仓库职责

一个插件仓库只负责一个内聚能力或一个必须共同发布的能力接缝。仅仅共享工具函数不是合并仓库的理由；需要锁步发布、共享持久化格式或共同维护一个服务契约时，才考虑放入同一仓库。

建议目录：

```text
dsh-<capability>/
├── AGENTS.md
├── README.md
├── LICENSE
├── package.json
├── pnpm-lock.yaml
├── cordis.patch.yml
├── src/
├── tests/
├── evals/                  # 策略型插件按需提供
├── tsconfig.json
└── tsdown.config.ts
```

`lib/`、`coverage/`、临时实验产物、凭据和本机数据不进入版本控制。可复现的小型 fixture 和经过审查的实验报告可以提交。

## 包与安装清单

- npm 包名使用 `@muou000/dsh-<capability>`（历史项目 `improved-compact` 保留其 basename）；
  Cordis 插件内部名称和 patch row `id` 保持无 scope 的稳定标识。名称一旦发布保持稳定。
- 使用 ESM、TypeScript strict 模式，并生成 `lib/index.js` 与 `lib/index.d.ts`。
- `@deepseek-ai/cordis` 同时声明为 `peerDependencies` 和 `devDependencies`，版本范围与支持的 DSH 版本一致。
- `package.json` 至少提供 `build`、`typecheck`、`test`、`check`、`prepare` 和 `prepack`。
- 可安装 bundle 通过 `dsh.bundle.patch` 指向 `cordis.patch.yml`；patch row 使用稳定且唯一的 `id`。
- npm `files` 只包含运行与使用文档所需内容。发布前必须在干净 checkout 上运行 `prepack`。

README 必须列明支持的 DSH、Node.js 和 pnpm 版本，安装、配置、验证、卸载与回滚方法，以及持久化数据的位置和清理方式。

## 运行时契约

### 导出

函数型插件默认导出以下命名成员：

```ts
export const name = 'dsh-example'
export interface Config {}
export const Config: Schema<Config> = Schema.object({})
export function apply(ctx: Context, config: Config): void {}
```

Loader 依赖命名导出，不用默认导出替代 `apply`。公共导出说明行为、失败、所有权和释放责任。

### 生命周期

- 使用 `ctx.effect()`、`ctx.on()` 或返回 disposer 的 registry 注册所有副作用。
- 卸载后不保留 listener、timer、watcher、临时文件、进程或未取消任务。
- 初始化失败要回收已创建资源；dispose 应支持部分初始化和重复取消路径。
- 插件并发加载，不能依靠 `cordis.patch.yml` 中的行顺序表达依赖；使用 service injection。

### 配置

- 使用 Schemastery 校验外部配置，给安全默认值，并在最早可判断的位置拒绝错误配置。
- 可调参数说明单位、范围、默认值和相互约束。安全上限可以固定，但要解释它保护的资源。
- 路径明确相对于 profile、workspace 还是进程目录；不得隐式落入源码仓库。

### 状态与事件

- session log 是模型上下文的事实来源。模型可见状态必须由持久事件或有明确版本的持久化记录重建。
- 持久化格式带版本；写入使用原子替换或事务，读取区分“不存在”和“损坏”。
- 记录数据的来源、作用域和版本。涉及用户数据时提供删除、过期与导出途径。
- 新的 typed event 使用可扩展 map 和判别字段；消费封闭联合类型时穷尽检查。

### 权限与隐私

- 只请求完成功能所需的文件、网络、进程和模型权限。
- 日志、telemetry、fixture 和错误消息默认去除密钥、访问令牌、私有提示和完整用户内容。
- 从记忆或 skill 注入模型的内容视为不可信数据，不允许其覆盖系统级权限与安全规则。
- 自动修改文件、配置或已发布策略前必须有明确授权、影响范围和回滚方案。

## 测试与评测

每个插件至少包含：

1. 配置默认值和错误配置测试。
2. 加载、核心行为、卸载及资源释放测试。
3. 通过 Cordis Loader 和真实 `cordis.patch.yml` 的组合测试。
4. 对持久化、并发、取消、重试和损坏输入的风险匹配测试。
5. 发布产物或 Git 安装路径的 smoke test。

会改变模型输入、agent 决策或用户结果的策略型插件还必须遵循 [`EVALUATION.md`](EVALUATION.md)，保存基线与候选的比较证据。Mock 只替换模型、网络、时钟等昂贵或非确定性边缘，尽量运行真实的 DSH 组件。

## 兼容与发布

- 插件版本使用 SemVer。配置、持久化格式、事件和服务接口的破坏性变更提高主版本。
- 每次发布记录支持的 DSH 版本范围、迁移步骤、回滚步骤和已知限制。
- 顶层仓库以 gitlink 固定验证过的插件 commit；标签只在插件检查和所需评测通过后创建。
- 发布候选必须能回到上一个稳定版本；涉及持久化迁移时优先提供向前恢复工具，而不是宣称可逆却未经验证。

## 完成定义

变更只有在源码、测试、文档、配置示例和评测证据一致时才完成。检查通过但没有证明真实插件入口、卸载行为或用户可见效果，不构成交付证据。
