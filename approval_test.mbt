///|
fn approval_policy() -> @agentcanary.Policy raise {
  policy(
    "{\"id\":\"consent\",\"kind\":\"require_approval\",\"tool\":\"fs.delete\"}",
  )
}

///|
fn grant(
  id : String,
  seq : Int,
  expiry : Int,
  session? : String = "s1",
  resource? : String = "/workspace/a.txt",
  tool? : String = "fs.delete",
) -> @agentcanary.Event {
  ev(id, seq, kind="approve", tool~, resource~, expires_ms=expiry, session~)
}

///|
test "approval missing and unknown are distinguished" {
  let p = approval_policy()
  assert_eq(code(p, [ev("a", 1, tool="fs.delete")]), "APPROVAL_MISSING")
  assert_eq(
    code(p, [ev("a", 1, tool="fs.delete", approval="unknown")]),
    "APPROVAL_UNKNOWN",
  )
}

///|
test "approval is valid before expiry and invalid exactly at expiry" {
  let p = approval_policy()
  assert_eq(
    verdict(p, [
      grant("g", 1, 30),
      ev("a", 2, at_ms=29, tool="fs.delete", approval="g"),
    ]),
    "allow",
  )
  assert_eq(
    code(p, [
      grant("g", 1, 30),
      ev("a", 2, at_ms=30, tool="fs.delete", approval="g"),
    ]),
    "APPROVAL_EXPIRED",
  )
}

///|
test "approval is single use and a failed tool attempt consumes consent" {
  let p = approval_policy()
  let es = [
    grant("g", 1, 100),
    ev("a", 2, tool="fs.delete", approval="g", outcome="error"),
    ev("b", 3, tool="fs.delete", approval="g"),
  ]
  assert_eq(verdict(p, es), "allow")
  assert_eq(code(p, es, index=1), "APPROVAL_REUSED")
}

///|
test "approval is bound to exact resource" {
  let es = [
    grant("g", 1, 100, resource="/workspace/*"),
    ev("a", 2, tool="fs.delete", approval="g"),
  ]
  assert_eq(code(approval_policy(), es), "APPROVAL_SCOPE")
}

///|
test "approval is bound to exact tool and session" {
  let p = policy("{\"id\":\"c\",\"kind\":\"require_approval\"}")
  assert_eq(
    code(p, [grant("g", 1, 100), ev("a", 2, approval="g")]),
    "APPROVAL_SCOPE",
  )
  assert_eq(
    code(p, [
      grant("g", 1, 100),
      ev("a", 1, session="s2", tool="fs.delete", approval="g"),
    ]),
    "APPROVAL_UNKNOWN",
  )
}

///|
test "scope mismatch does not consume matching future consent" {
  let es = [
    grant("g", 1, 100),
    ev("a", 2, tool="fs.delete", resource="/other", approval="g"),
    ev("b", 3, tool="fs.delete", approval="g"),
  ]
  assert_eq(code(approval_policy(), es), "APPROVAL_SCOPE")
  assert_eq(verdict(approval_policy(), es, index=1), "allow")
}

///|
test "revoke invalidates a grant and carries causal evidence" {
  let revoke = ev("r", 2, kind="revoke", tool="", resource="", approval="g")
  let report = @agentcanary.evaluate(approval_policy(), [
    grant("g", 1, 100),
    revoke,
    ev("a", 3, tool="fs.delete", approval="g"),
  ])
  assert_eq(report.decisions[0].findings[0].code, "APPROVAL_REVOKED")
  assert_eq(report.decisions[0].findings[0].evidence, ["g"])
}

///|
test "multiple approval rules consume one grant once per attempted call" {
  let p = policy(
    "{\"id\":\"a\",\"kind\":\"require_approval\"},{\"id\":\"b\",\"kind\":\"require_approval\"}",
  )
  assert_eq(
    verdict(p, [grant("g", 1, 100), ev("x", 2, tool="fs.delete", approval="g")]),
    "allow",
  )
}

///|
test "a matching approval is consumed even if another rule denies" {
  let p = policy(
    "{\"id\":\"a\",\"kind\":\"require_approval\"},{\"id\":\"d\",\"kind\":\"deny\",\"resource\":\"*\"}",
  )
  let es = [
    grant("g", 1, 100),
    ev("a", 2, tool="fs.delete", approval="g"),
    ev("b", 3, tool="fs.delete", approval="g"),
  ]
  assert_eq(code(p, es, index=1), "APPROVAL_REUSED")
}
