///|
fn flow_policy() -> @agentcanary.Policy raise {
  policy(
    "{\"id\":\"egress\",\"kind\":\"block_labels\",\"tool\":\"net.*\",\"labels\":[\"secret\",\"personal\"]}",
  )
}

///|
test "sensitivity propagates through multiple transformations" {
  let es = [
    ev("read", 1, output="raw", labels=["secret"]),
    ev("summarize", 2, tool="text.summarize", inputs=["raw"], output="summary"),
    ev("send", 3, tool="net.post", inputs=["summary"]),
  ]
  let report = @agentcanary.evaluate(flow_policy(), es)
  assert_eq(report.allowed, 2)
  assert_eq(report.denied, 1)
  assert_eq(report.decisions[2].findings[0].evidence, ["read"])
  assert_eq(report.decisions[2].taints[0].label, "secret")
}

///|
test "diamond dependencies deduplicate source evidence and keep both labels" {
  let es = [
    ev("a", 1, output="raw", labels=["secret", "personal"]),
    ev("b", 2, inputs=["raw"], output="left"),
    ev("c", 3, inputs=["raw"], output="right"),
    ev("d", 4, tool="net.post", inputs=["left", "right"]),
  ]
  let d = @agentcanary.evaluate(flow_policy(), es).decisions[3]
  assert_eq(d.findings[0].evidence, ["a"])
  assert_eq(d.taints.length(), 2)
}

///|
test "multiple origins for one label remain attributable" {
  let es = [
    ev("a", 1, output="a", labels=["secret"]),
    ev("b", 2, output="b", labels=["secret"]),
    ev("c", 3, tool="net.post", inputs=["a", "b"]),
  ]
  assert_eq(
    @agentcanary.evaluate(flow_policy(), es).decisions[2].findings[0].evidence,
    ["a", "b"],
  )
}

///|
test "public data is not tainted by unrelated prior reads" {
  let es = [
    ev("a", 1, output="private", labels=["secret"]),
    ev("b", 2, output="public"),
    ev("c", 3, tool="net.post", inputs=["public"]),
  ]
  assert_eq(verdict(flow_policy(), es, index=2), "allow")
}

///|
test "declared direct input labels are checked even without an artifact" {
  assert_eq(
    code(flow_policy(), [ev("e", 1, tool="net.post", labels=["personal"])]),
    "SENSITIVE_FLOW",
  )
}

///|
test "observed denied calls still produce actual artifacts for downstream audit" {
  let p = policy(
    "{\"id\":\"d\",\"kind\":\"deny\",\"tool\":\"fs.read\"},{\"id\":\"f\",\"kind\":\"block_labels\",\"tool\":\"net.*\",\"labels\":[\"secret\"]}",
  )
  let report = @agentcanary.evaluate(p, [
    ev("a", 1, output="a", labels=["secret"]),
    ev("b", 2, tool="net.post", inputs=["a"]),
  ])
  assert_eq(report.denied, 2)
}

///|
test "same artifact name in distinct sessions does not merge labels" {
  let es = [
    ev("a", 1, output="x", labels=["secret"]),
    ev("b", 1, session="s2", output="x"),
    ev("c", 2, session="s2", tool="net.post", inputs=["x"]),
  ]
  assert_eq(verdict(flow_policy(), es, index=2), "allow")
}

///|
test "cross session, forward and unknown artifact references fail closed" {
  assert_true(
    rejects_trace([
      ev("a", 1, output="x"),
      ev("b", 1, session="s2", inputs=["x"]),
    ]),
  )
  assert_true(rejects_trace([ev("a", 1, inputs=["x"], output="x")]))
  assert_true(rejects_trace([ev("a", 1, inputs=["unknown"])]))
}
