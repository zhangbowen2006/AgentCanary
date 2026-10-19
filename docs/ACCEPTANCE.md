# AgentCanary 交付自检

检查日期：2026-10-19；发布版本：0.1.1；维护者 / 仓库拥有者：zhangbowen2006。

这是本地及远程工程自检，不能替代赛事组正式审核、验收或奖项评选。

## 已检查的证据

| 项目 | 结果与证据 |
| --- | --- |
| 有效 MoonBit 工程 | 根目录 moon.mod / moon.pkg；核心逻辑为 MoonBit，适配器仅处理 I/O 和呈现 |
| 严格检查 | `moon check --target all --deny-warn` 通过 |
| 测试 | 63 项 MoonBit 用例，含独立 glob / 窗口求和 oracle、错误输入、审批、数据流、序列化、文档示例与回归用例集 |
| 多平台 | GitHub Actions 在 Linux、macOS、Windows 执行 Wasm、Wasm GC、JS、Native 检查、构建与测试 |
| CI 证据 | [已通过的核心验证](https://github.com/zhangbowen2006/AgentCanary/actions/runs/39254378916)；[0.1.1 发布检查](https://github.com/zhangbowen2006/AgentCanary/actions/runs/39254900325) |
| 格式与接口 | `moon fmt --check`、`moon info` 及生成接口差异检查通过；接口文件纳入版本管理 |
| CLI | 10 项 Node 集成测试通过；stdin / 文件一致，JSON 报告可解析，门禁失败返回 1，输入错误返回 2 |
| 浏览器 | 桌面 / 手机 390px 布局、策略开关、预算、比较、筛选、导出、输入错误、HTML 字符串呈现均实测；无未捕获页面错误 |
| 可运行示例 | `moon run cmd/demo`；CLI incident / regressions；本地及公开浏览器演示 |
| Mooncakes | `zhangbowen2006/agentcanary@0.1.1` 发布返回 HTTP 200；全新消费项目从 registry 下载、导入并运行成功 |
| 公开默认分支 | GitHub 仓库公开；`git remote show origin` 核实默认分支 main，主要代码与提交均已推送 |
| 独立新项目 | 与本账号旧项目方向和核心实现不同；从建仓、核心、CLI、演示、兼容修复、文档到发布均有实际开发提交，无补造日期 |
| 提案覆盖 | artifact 来源、审批、预算、频率、前置条件、策略比较、回归用例、CLI、文档、演示与发布均有实现和证据 |
| 开源许可 | 根 LICENSE 为 MIT；MoonBit 标准库编译分发的 Apache / 上游 NOTICE 随生成引擎保留，见 THIRD_PARTY_NOTICES.md |
| 仓库整洁 | 编译产物、依赖缓存、临时工具和凭据未提交；source/demo 快照另行提供 |

## 对真实能力的判断

核心可以作为有明确边界的离线分析库复用：存在状态验证、数据依赖合并、整数窗口账本和确定性回归结果，不是只包装一个外部接口。示例具有正常放行和多步骤风险的对照；同时披露了受信采集器、审批认证与输入规模限制。

性能脚本检查 100 到 10000 条事件的合成 artifact 长链；结果和条件见 BENCHMARK.md。它不能证明真实攻击检出率或所有工作负载的性能。

有效源代码规模应以仓库实际统计为准。当前约两千余行非空非注释 MoonBit 源码（含测试/示例），没有通过扩写空壳或复制代码追求行数。既有技能的 4–10k 行属于其他章程的参考量，不能当作十月官网已明确的硬门槛；项目规模与生态价值仍由评委综合判断。

## 仍需本人 / 赛事方确认

1. 本人姓名、常用邮箱、队伍成员与参赛声明；正式报名回执目前未由本项目代填或提交。
2. 已加入赛事交流群，并按要求将昵称改为 zhangbowen2006。
3. 正式规则、十月验收提交方式及审核通过状态，以赛事方通知为准。
4. 参赛者理解 AI 辅助内容，能讲解和维护；不要将 AI 辅助开发描述为完全手写。
5. 是否获季度奖没有保证。进一步竞争力应来自真实宿主集成、授权的实际使用案例与持续维护，而不是虚构采用率。

报名链接与可直接复制的信息在 SUBMISSION.md；一页申报书在 PROPOSAL.md；展示及答辩在 DEMO.md。
