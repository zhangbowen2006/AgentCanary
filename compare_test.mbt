///|
test "comparison identifies newly denied and newly allowed calls" {
  let a = policy("{\"id\":\"a\",\"kind\":\"deny\",\"tool\":\"fs.read\"}")
  let b = policy("{\"id\":\"b\",\"kind\":\"deny\",\"tool\":\"net.post\"}")
  let diff = @agentcanary.compare(a, b, [
    ev("read", 1),
    ev("send", 2, tool="net.post"),
  ])
  assert_eq(diff.newly_denied, 1)
  assert_eq(diff.newly_allowed, 1)
  assert_eq(diff.changes[0].event_id, "read")
}

///|
test "same verdict with a different rule is an explanation change" {
  let a = policy("{\"id\":\"a\",\"kind\":\"deny\"}")
  let b = policy("{\"id\":\"b\",\"kind\":\"deny\"}")
  assert_eq(@agentcanary.compare(a, b, [ev("e", 1)]).explanation_changes, 1)
}

///|
test "repeated evaluations are deterministic and do not mutate input" {
  let p = approval_policy()
  let events = [grant("g", 1, 100), ev("e", 2, tool="fs.delete", approval="g")]
  let a = @agentcanary.evaluate(p, events)
  let b = @agentcanary.evaluate(p, events)
  assert_true(a == b)
  assert_eq(@agentcanary.compare(p, p, events).changes.length(), 0)
  assert_eq(events[1].approval, Some("g"))
}

///|
test "JSON APIs produce valid deterministic reports without resources" {
  let p = "{\"schema_version\":1,\"name\":\"p\",\"default_decision\":\"allow\",\"rules\":[]}"
  let t = "{\"id\":\"e\",\"session\":\"s\",\"seq\":0,\"at_ms\":0,\"tool\":\"fs.read\",\"resource\":\"private-path\"}"
  let report = @agentcanary.evaluate_json(p, t)
  assert_true(!report.contains("private-path"))
  assert_eq(report, @agentcanary.evaluate_json(p, t))
  assert_true(
    @agentcanary.compare_json(p, p, t).contains("\"newly_denied\": 0"),
  )
}
