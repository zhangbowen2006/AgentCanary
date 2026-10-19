# v1 输入与输出契约

## Policy

必需字段：`schema_version: 1`、`name: string`、`default_decision: "allow"|"deny"`、`rules: array`。

每条规则必需 `id` 和 `kind`；`tool`、`resource` 缺省为 `*`。

| kind | 额外字段 |
| --- | --- |
| allow / deny / require_approval | 无 |
| block_labels | labels：非空字符串数组 |
| budget | limit：非负整数；window_ms：可选正整数 |
| rate | limit：非负整数；window_ms：必需正整数 |
| require_before | prerequisite：工具 glob；window_ms：可选正整数 |

不适用于该规则的额外字段会被拒绝，即使值为空。完整例子见 `examples/policy.json`。

## Trace

可以是 JSON 数组或 JSONL。JSONL 忽略空行、支持 CRLF，不接受注释。空轨迹合法。

所有事件必需 `id`、`session`、`seq`、`at_ms`。seq 与 at_ms 是 0..2147483647 的整数；时间为会话内相对毫秒。kind 缺省 call。

| kind | 必需 / 可选字段 |
| --- | --- |
| call | tool、resource 非空；inputs 缺省 []，output 可选，labels 缺省 []，cost 缺省 0，approval 可选，outcome 缺省 ok（也可 error） |
| approve | tool、resource、expires_ms；grant ID 等于事件 id |
| revoke | approval；tool/resource 必须为空或省略 |

控制事件不得携带非空 inputs/labels、output、非零 cost 或 error outcome。call 不允许 expires_ms，approve 不允许 approval。revoke 只能撤销当前会话中已经存在的 grant。

```json
{"id":"read","session":"s","seq":0,"at_ms":0,"tool":"fs.read","resource":"/data/private.csv","output":"raw","labels":["personal"]}
```

## Report / Comparison

Report 含 schema_version、policy、events、calls、allowed、denied、observed_cost、decisions。observed_cost 在 JSON 中是十进制字符串；其余计数为 JSON 整数。

Decision 含 event_id、session、seq、at_ms、tool、decision、findings、taints；resource 不进入报告。Finding 含 rule_id、code、message、evidence；Taint 含 label、sources。findings 为空则 allow，否则 deny。

Comparison 含 baseline、candidate、newly_denied、newly_allowed、explanation_changes、changes。每项 change 包含前后判定、命中规则 ID、完整 findings。相同判定下 message、code 或 evidence 改变也算解释变化。输出顺序遵循调用及规则输入顺序，可做字节级重复验证。

违规码：`TOOL_DENIED`、`DEFAULT_DENY`、`SENSITIVE_FLOW`、`APPROVAL_MISSING`、`APPROVAL_UNKNOWN`、`APPROVAL_REVOKED`、`APPROVAL_REUSED`、`APPROVAL_EXPIRED`、`APPROVAL_SCOPE`、`BUDGET_EXCEEDED`、`RATE_EXCEEDED`、`PREREQUISITE_MISSING`。

## 回归用例集

必需 schema_version:1、policy（内嵌完整 Policy）、cases。每个 case 必需唯一 name、trace（JSON 数组）、expect。expect 每项为 event_id、decision、codes（缺省 []）。code 顺序无关，集合必须完全一致；同一码被多个规则命中只比较一次。控制事件不用断言。

缺少调用断言、断言不存在的调用、判定/违规码不匹配均导致用例失败；重复断言、格式错误属于输入错误。参考 `examples/regressions.json`。
