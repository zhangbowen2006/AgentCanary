///|
test "normalized policies roundtrip through strict JSON including every rule kind" {
  let p = policy(
    "{\"id\":\"a\",\"kind\":\"allow\"}," +
    "{\"id\":\"d\",\"kind\":\"deny\"}," +
    "{\"id\":\"f\",\"kind\":\"block_labels\",\"labels\":[\"secret\"]}," +
    "{\"id\":\"c\",\"kind\":\"require_approval\"}," +
    "{\"id\":\"b\",\"kind\":\"budget\",\"limit\":10}," +
    "{\"id\":\"r\",\"kind\":\"rate\",\"limit\":1,\"window_ms\":10}," +
    "{\"id\":\"p\",\"kind\":\"require_before\",\"prerequisite\":\"test.*\",\"window_ms\":20}",
  )
  assert_true(@agentcanary.parse_policy(@json.to_json(p).stringify()) == p)
}

///|
test "events roundtrip without losing approvals, costs or artifacts" {
  let es = [
    grant("g", 1, 100),
    ev("a", 2, output="x", cost=123),
    ev("b", 3, tool="fs.delete", approval="g", inputs=["x"]),
  ]
  assert_true(@agentcanary.parse_trace(@json.to_json(es).stringify()) == es)
}
