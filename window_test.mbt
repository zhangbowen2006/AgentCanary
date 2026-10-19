///|
test "cumulative budget includes the current call and accepts exact limit" {
  let p = policy("{\"id\":\"b\",\"kind\":\"budget\",\"limit\":10}")
  let es = [ev("a", 1, cost=6), ev("b", 2, cost=4), ev("c", 3, cost=1)]
  let r = @agentcanary.evaluate(p, es)
  assert_eq(r.allowed, 2)
  assert_eq(r.denied, 1)
  assert_eq(r.observed_cost, 11L)
}

///|
test "budget counts recorded denied and failed calls" {
  let p = policy("{\"id\":\"b\",\"kind\":\"budget\",\"limit\":5}")
  let es = [ev("a", 1, cost=8, outcome="error"), ev("b", 2, cost=0)]
  assert_eq(code(p, es, index=1), "BUDGET_EXCEEDED")
}

///|
test "sliding window excludes exact lower boundary" {
  let p = policy(
    "{\"id\":\"b\",\"kind\":\"budget\",\"limit\":5,\"window_ms\":100}",
  )
  assert_eq(
    code(
      p,
      [ev("a", 1, at_ms=0, cost=5), ev("b", 2, at_ms=99, cost=1)],
      index=1,
    ),
    "BUDGET_EXCEEDED",
  )
  assert_eq(
    verdict(
      p,
      [ev("a", 1, at_ms=0, cost=5), ev("b", 2, at_ms=100, cost=5)],
      index=1,
    ),
    "allow",
  )
}

///|
test "same timestamp calls share the window" {
  let p = policy("{\"id\":\"r\",\"kind\":\"rate\",\"limit\":1,\"window_ms\":1}")
  assert_eq(
    code(p, [ev("a", 1, at_ms=0), ev("b", 2, at_ms=0)], index=1),
    "RATE_EXCEEDED",
  )
}

///|
test "budgets are per session and only count matching calls" {
  let p = policy(
    "{\"id\":\"b\",\"kind\":\"budget\",\"tool\":\"llm.*\",\"limit\":5}",
  )
  let r = @agentcanary.evaluate(p, [
    ev("a", 1, cost=100),
    ev("b", 2, tool="llm.chat", cost=5),
    ev("c", 1, session="s2", tool="llm.chat", cost=5),
  ])
  assert_eq(r.denied, 0)
}

///|
test "zero budget and zero rate are valid and enforceable" {
  assert_eq(
    verdict(policy("{\"id\":\"b\",\"kind\":\"budget\",\"limit\":0}"), [
      ev("a", 1),
    ]),
    "allow",
  )
  assert_eq(
    code(
      policy("{\"id\":\"r\",\"kind\":\"rate\",\"limit\":0,\"window_ms\":10}"),
      [ev("a", 1)],
    ),
    "RATE_EXCEEDED",
  )
}

///|
test "int64 accounting cannot wrap int32 near maximum input cost" {
  let r = @agentcanary.evaluate(
    policy("{\"id\":\"b\",\"kind\":\"budget\",\"limit\":2147483647}"),
    [ev("a", 1, cost=2147483647), ev("b", 2, cost=2147483647)],
  )
  assert_eq(r.observed_cost, 4294967294L)
  assert_eq(r.denied, 1)
}

///|
test "sliding budget agrees with independent summation oracle" {
  let p = policy(
    "{\"id\":\"b\",\"kind\":\"budget\",\"limit\":12,\"window_ms\":27}",
  )
  let es = Array::makei(200, i => ev("e\{i}", i, at_ms=i * 7, cost=i % 9))
  let r = @agentcanary.evaluate(p, es)
  for i, d in r.decisions {
    let mut total = 0
    for j in 0..<=i {
      if es[i].at_ms - es[j].at_ms < 27 {
        total += es[j].cost
      }
    }
    assert_eq(d.decision, if total > 12 { "deny" } else { "allow" })
  }
}

///|
test "require_before uses only earlier successful calls in the same session" {
  let p = policy(
    "{\"id\":\"p\",\"kind\":\"require_before\",\"tool\":\"deploy\",\"prerequisite\":\"test.*\"}",
  )
  assert_eq(code(p, [ev("a", 1, tool="deploy")]), "PREREQUISITE_MISSING")
  assert_eq(
    verdict(
      p,
      [ev("a", 1, tool="test.run"), ev("b", 2, tool="deploy")],
      index=1,
    ),
    "allow",
  )
  assert_eq(
    code(
      p,
      [ev("a", 1, tool="test.run", outcome="error"), ev("b", 2, tool="deploy")],
      index=1,
    ),
    "PREREQUISITE_MISSING",
  )
  assert_eq(
    code(
      p,
      [ev("a", 1, tool="test.run"), ev("b", 1, session="s2", tool="deploy")],
      index=1,
    ),
    "PREREQUISITE_MISSING",
  )
}

///|
test "prerequisite window uses latest matching success and excludes lower endpoint" {
  let p = policy(
    "{\"id\":\"p\",\"kind\":\"require_before\",\"tool\":\"deploy\",\"prerequisite\":\"test.*\",\"window_ms\":20}",
  )
  assert_eq(
    code(
      p,
      [ev("a", 1, tool="test.run"), ev("b", 2), ev("c", 3, tool="deploy")],
      index=2,
    ),
    "PREREQUISITE_MISSING",
  )
  assert_eq(
    verdict(
      p,
      [
        ev("a", 1, tool="test.run"),
        ev("b", 2, tool="test.run"),
        ev("c", 3, tool="deploy"),
      ],
      index=2,
    ),
    "allow",
  )
}

///|
test "a call cannot satisfy its own prerequisite" {
  let p = policy(
    "{\"id\":\"p\",\"kind\":\"require_before\",\"prerequisite\":\"*\"}",
  )
  assert_eq(code(p, [ev("a", 1)]), "PREREQUISITE_MISSING")
}
