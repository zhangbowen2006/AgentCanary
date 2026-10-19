///|
fn suite(cases : String) -> String {
  "{\"schema_version\":1,\"policy\":{\"schema_version\":1,\"name\":\"p\",\"default_decision\":\"deny\",\"rules\":[]},\"cases\":[" +
  cases +
  "]}"
}

///|
fn sample_case(expect : String) -> String {
  "{\"name\":\"one\",\"trace\":[{\"id\":\"e\",\"session\":\"s\",\"seq\":0,\"at_ms\":0,\"tool\":\"x\",\"resource\":\"r\"}],\"expect\":[" +
  expect +
  "]}"
}

///|
test "regression suite passes exact verdict and code assertions" {
  let r = @agentcanary.run_suite(
    suite(
      sample_case(
        "{\"event_id\":\"e\",\"decision\":\"deny\",\"codes\":[\"DEFAULT_DENY\"]}",
      ),
    ),
  )
  assert_eq(r.passed, 1)
  assert_eq(r.failed, 0)
  assert_eq(r.results[0].calls, 1)
}

///|
test "regression suite reports both verdict and reason regressions" {
  assert_eq(
    @agentcanary.run_suite(
      suite(sample_case("{\"event_id\":\"e\",\"decision\":\"allow\"}")),
    ).failed,
    1,
  )
  assert_eq(
    @agentcanary.run_suite(
      suite(
        sample_case(
          "{\"event_id\":\"e\",\"decision\":\"deny\",\"codes\":[\"OTHER\"]}",
        ),
      ),
    ).failed,
    1,
  )
}

///|
test "unasserted calls and unknown expectations fail instead of silently reducing coverage" {
  let missing = @agentcanary.run_suite(suite(sample_case("")))
  assert_eq(missing.failed, 1)
  assert_eq(missing.results[0].mismatches[0].expected, "expectation_required")
  let unknown = @agentcanary.run_suite(
    suite(sample_case("{\"event_id\":\"unknown\",\"decision\":\"allow\"}")),
  )
  assert_eq(unknown.results[0].mismatches.length(), 2)
}

///|
test "duplicate expectations and empty suites are invalid input" {
  let e = "{\"event_id\":\"e\",\"decision\":\"deny\"}"
  for s in [suite(""), suite(sample_case(e + "," + e))] {
    let rejected = try {
      @agentcanary.run_suite(s) |> ignore
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "suite JSON bridge returns a structured report" {
  assert_true(
    @agentcanary.run_suite_json(suite(sample_case(""))).contains(
      "\"failed\": 1",
    ),
  )
}
