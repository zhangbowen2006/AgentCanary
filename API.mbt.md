# 可执行 API 示例

以下 `mbt check` 示例随 `moon test` 编译、运行。安装及导入方法见 README。

## 离线审计

```mbt check
///|
test "documented minimal audit" {
  let policy = @agentcanary.parse_policy(
    (
      #|{"schema_version":1,"name":"minimal","default_decision":"deny","rules":[{"id":"read","kind":"allow","tool":"fs.read"}]}
    ),
  )
  let trace = @agentcanary.parse_trace(
    (
      #|{"id":"one","session":"s","seq":0,"at_ms":0,"tool":"fs.read","resource":"/workspace/readme.md"}
    ),
  )
  let report = @agentcanary.evaluate(policy, trace)
  assert_eq(report.allowed, 1)
  assert_eq(report.denied, 0)
}
```

## 策略变更比较

```mbt check
///|
test "documented policy comparison" {
  let before = @agentcanary.parse_policy(
    (
      #|{"schema_version":1,"name":"before","default_decision":"allow","rules":[]}
    ),
  )
  let after = @agentcanary.parse_policy(
    (
      #|{"schema_version":1,"name":"after","default_decision":"deny","rules":[]}
    ),
  )
  let events = @agentcanary.parse_trace(
    (
      #|{"id":"one","session":"s","seq":0,"at_ms":0,"tool":"net.post","resource":"https://example.invalid/"}
    ),
  )
  let comparison = @agentcanary.compare(before, after, events)
  assert_eq(comparison.newly_denied, 1)
  assert_eq(comparison.changes[0].after_findings[0].code, "DEFAULT_DENY")
}
```

类型化接口均抛出 `InputError`，内含不回显原始字段值的诊断。JSON 桥接包 `api` 将该错误转为 `{"schema_version":1,"error":{"code":"INVALID_INPUT","message":"..."}}`；调用者必须处理错误，不能将其当成空的放行报告。

`Policy` 和 `Rule` 的 `ToJson` 输出符合输入 schema，可重新读取。`Report.observed_cost` 类型为 `Int64`，JSON 中表示为十进制**字符串**，避免 JavaScript 数字精度混淆。
