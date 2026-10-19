///|
test "empty trace, empty array and CRLF JSONL are valid" {
  assert_eq(@agentcanary.parse_trace("").length(), 0)
  assert_eq(@agentcanary.parse_trace("[]").length(), 0)
  let s = "{\"id\":\"a\",\"session\":\"s\",\"seq\":0,\"at_ms\":0,\"tool\":\"x\",\"resource\":\"r\"}\r\n\r\n"
  assert_eq(@agentcanary.parse_trace(s).length(), 1)
  assert_eq(
    @agentcanary.parse_trace("[" + s.trim().to_owned() + "]").length(),
    1,
  )
}

///|
test "invalid JSON, comments, scalar trace and missing fields are rejected" {
  for
    s in [
      "{", "null", "42", "// comment", "[{}]", "[1]", "[true]", "{\"id\":\"a\"}\n# comment",
    ] {
    assert_true(rejects_json_trace(s))
  }
}

///|
test "policy rejects unknown schema version, fields, kinds and default verdict" {
  for
    s in [
      "{}", "{\"schema_version\":2,\"name\":\"p\",\"default_decision\":\"allow\",\"rules\":[]}",
      "{\"schema_version\":1,\"name\":\"p\",\"default_decision\":\"ask\",\"rules\":[]}",
      "{\"schema_version\":1,\"name\":\"p\",\"default_decision\":\"allow\",\"rules\":[],\"typo\":true}",
      "{\"schema_version\":1,\"name\":\"p\",\"default_decision\":\"allow\",\"rules\":[{\"id\":\"r\",\"kind\":\"typo\"}]}",
    ] {
    assert_true(rejects_policy(s))
  }
}

///|
test "policy rejects missing and inapplicable rule options" {
  for
    rule in [
      "{\"id\":\"r\",\"kind\":\"budget\"}", "{\"id\":\"r\",\"kind\":\"rate\",\"limit\":1}",
      "{\"id\":\"r\",\"kind\":\"require_before\"}", "{\"id\":\"r\",\"kind\":\"block_labels\",\"labels\":[]}",
      "{\"id\":\"r\",\"kind\":\"budget\",\"limit\":1,\"window_ms\":0}", "{\"id\":\"r\",\"kind\":\"deny\",\"limit\":1}",
      "{\"id\":\"r\",\"kind\":\"allow\",\"labels\":[]}", "{\"id\":\"r\",\"kind\":\"deny\",\"prerequisite\":\"x\"}",
      "{\"id\":\"r\",\"kind\":\"deny\",\"window_ms\":10}",
    ] {
    let source = "{\"schema_version\":1,\"name\":\"p\",\"default_decision\":\"allow\",\"rules\":[" +
      rule +
      "]}"
    assert_true(rejects_policy(source))
  }
}

///|
test "duplicate rule IDs and duplicate list entries are rejected" {
  let source = "{\"schema_version\":1,\"name\":\"p\",\"default_decision\":\"allow\",\"rules\":[{\"id\":\"x\",\"kind\":\"deny\"},{\"id\":\"x\",\"kind\":\"allow\"}]}"
  assert_true(rejects_policy(source))
  assert_true(rejects_trace([ev("e", 1, labels=["secret", "secret"])]))
}

///|
test "duplicate JSON keys including escaped aliases are rejected" {
  let p = "{\"schema_version\":1,\"name\":\"a\",\"name\":\"b\",\"default_decision\":\"allow\",\"rules\":[]}"
  assert_true(rejects_policy(p))
  let e = "{\"id\":\"a\",\"\\u0069d\":\"b\",\"session\":\"s\",\"seq\":0,\"at_ms\":0,\"tool\":\"x\",\"resource\":\"r\"}"
  assert_true(rejects_json_trace(e))
}

///|
test "numeric fields reject fractions, overflow, negative, bool and null" {
  for n in ["-1", "0.5", "2147483648", "true", "null", "\"1\"", "1e999"] {
    let e = "{\"id\":\"a\",\"session\":\"s\",\"seq\":" +
      n +
      ",\"at_ms\":0,\"tool\":\"x\",\"resource\":\"r\"}"
    assert_true(rejects_json_trace(e))
  }
}

///|
test "identifiers reject empty values and controls without leaking input in diagnostics" {
  assert_true(rejects_trace([ev("", 1)]))
  assert_true(rejects_trace([ev("a\nsecret", 1)]))
  let failed = try {
    @agentcanary.evaluate(policy(""), [ev("very-secret\nvalue", 1)]) |> ignore
    false
  } catch {
    @agentcanary.InputError(message) => !message.contains("very-secret")
    _ => false
  }
  assert_true(failed)
}

///|
test "trace rejects duplicate IDs, sequence regression and time regression" {
  assert_true(rejects_trace([ev("a", 1), ev("a", 2)]))
  assert_true(rejects_trace([ev("a", 1), ev("b", 1)]))
  assert_true(rejects_trace([ev("a", 2), ev("b", 1)]))
  assert_true(rejects_trace([ev("a", 1, at_ms=10), ev("b", 2, at_ms=9)]))
}

///|
test "artifact overwrite and failed output are rejected" {
  assert_true(rejects_trace([ev("a", 1, output="x"), ev("b", 2, output="x")]))
  assert_true(rejects_trace([ev("a", 1, output="x", outcome="error")]))
}

///|
test "control event shapes and invalid revocation are rejected" {
  assert_true(rejects_trace([ev("a", 1, kind="approve")]))
  assert_true(rejects_trace([ev("a", 1, kind="approve", expires_ms=9)]))
  assert_true(
    rejects_trace([
      ev("a", 1, kind="revoke", tool="", resource="", approval="missing"),
    ]),
  )
  assert_true(rejects_trace([ev("a", 1, kind="unknown")]))
  assert_true(rejects_trace([ev("a", 1, expires_ms=100)]))
  assert_true(rejects_trace([ev("a", 1, outcome="unknown")]))
}

///|
test "nesting bound is enforced before parsing and quoted brackets are ignored" {
  assert_true(rejects_json_trace("[".repeat(33) + "]".repeat(33)))
  let s = "{\"id\":\"a\",\"session\":\"s\",\"seq\":0,\"at_ms\":0,\"tool\":\"x\",\"resource\":\"" +
    "[".repeat(40) +
    "\"}"
  assert_eq(@agentcanary.parse_trace(s).length(), 1)
}

///|
test "resource and event count limits prevent unbounded observations" {
  assert_true(rejects_trace([ev("e", 1, resource="x".repeat(1025))]))
  assert_true(rejects_trace(Array::makei(10001, i => ev("e\{i}", i))))
}

///|
test "label vocabulary and origin caps are enforced explicitly" {
  assert_true(
    rejects_trace([ev("e", 1, labels=Array::makei(17, i => "label\{i}"))]),
  )
  assert_true(
    rejects_trace(Array::makei(65, i => ev("e\{i}", i, labels=["secret"]))),
  )
}
