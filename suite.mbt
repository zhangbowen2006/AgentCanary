///|
pub(all) struct Mismatch {
  event_id : String
  expected : String
  actual : String
  expected_codes : Array[String]
  actual_codes : Array[String]
} derive(Eq, ToJson)

///|
pub(all) struct CaseResult {
  name : String
  passed : Bool
  calls : Int
  mismatches : Array[Mismatch]
} derive(Eq, ToJson)

///|
pub(all) struct SuiteReport {
  schema_version : Int
  policy : String
  cases : Int
  passed : Int
  failed : Int
  results : Array[CaseResult]
} derive(Eq, ToJson)

///|
priv struct Expectation {
  event_id : String
  decision : String
  codes : Array[String]
}

///|
fn same_codes(a : Array[String], b : Array[String]) -> Bool {
  a.length() == b.length() && a.all(item => b.contains(item))
}

///|
fn expectations(
  value : Json,
  path : String,
) -> Map[String, Expectation] raise InputError {
  let result : Map[String, Expectation] = Map([])
  match value {
    Array(items) => {
      if items.length() > 10000 {
        invalid(path, "at most 10000 expectations")
      }
      for i, item in items {
        let path = "\{path}[\{i}]"
        let f = object_at(item, path)
        known_fields(f, ["event_id", "decision", "codes"], path)
        let id = text_field(f, "event_id", path)
        check_text(id, "\{path}.event_id")
        if result.contains(id) {
          invalid(path, "duplicate expectation")
        }
        let decision = text_field(f, "decision", path)
        if decision != "allow" && decision != "deny" {
          invalid(path, "expected allow or deny")
        }
        let codes = string_list(f, "codes", path)
        unique_strings(codes, "\{path}.codes")
        if decision == "allow" && !codes.is_empty() {
          invalid(path, "allow expectation cannot contain violation codes")
        }
        result[id] = { event_id: id, decision, codes }
      }
    }
    _ => invalid(path, "expected expectation array")
  }
  result
}

///|
fn run_case(
  policy : Policy,
  value : Json,
  path : String,
) -> CaseResult raise InputError {
  let f = object_at(value, path)
  known_fields(f, ["name", "trace", "expect"], path)
  let name = text_field(f, "name", path)
  check_text(name, "\{path}.name")
  let trace_value = required(f, "trace", path)
  guard trace_value is Array(_) else {
    return invalid(path, "trace must be a JSON array")
  }
  let trace = parse_trace(trace_value.stringify())
  let expected = expectations(required(f, "expect", path), "\{path}.expect")
  let report = evaluate(policy, trace)
  let actual_ids : Map[String, Bool] = Map([])
  let mismatches : Array[Mismatch] = []
  for decision in report.decisions {
    actual_ids[decision.event_id] = true
    let actual_codes : Array[String] = []
    append_unique(actual_codes, decision.findings.map(f => f.code))
    match expected.get(decision.event_id) {
      None =>
        mismatches.push({
          event_id: decision.event_id,
          expected: "expectation_required",
          actual: decision.decision,
          expected_codes: [],
          actual_codes,
        })
      Some(expectation) =>
        if expectation.decision != decision.decision ||
          !same_codes(expectation.codes, actual_codes) {
          mismatches.push({
            event_id: decision.event_id,
            expected: expectation.decision,
            actual: decision.decision,
            expected_codes: expectation.codes,
            actual_codes,
          })
        }
    }
  }
  for id, expectation in expected {
    if !actual_ids.contains(id) {
      mismatches.push({
        event_id: expectation.event_id,
        expected: expectation.decision,
        actual: "call_not_found",
        expected_codes: expectation.codes,
        actual_codes: [],
      })
    }
  }
  { name, passed: mismatches.is_empty(), calls: report.calls, mismatches }
}

///|
/// Every observed call needs exactly one expectation. Missing assertions fail.
pub fn run_suite(source : String) -> SuiteReport raise InputError {
  let f = object_at(parse_json(source, "suite"), "suite")
  known_fields(f, ["schema_version", "policy", "cases"], "suite")
  if int_at(required(f, "schema_version", "suite"), "suite.schema_version") != 1 {
    invalid("suite.schema_version", "only version 1 is supported")
  }
  let policy = parse_policy(required(f, "policy", "suite").stringify())
  let results = []
  let mut passed = 0
  let names : Map[String, Bool] = Map([])
  match required(f, "cases", "suite") {
    Array(cases) => {
      if cases.is_empty() || cases.length() > 64 {
        invalid("suite.cases", "expected 1 to 64 cases")
      }
      for i, case in cases {
        let result = run_case(policy, case, "suite.cases[\{i}]")
        if names.contains(result.name) {
          invalid("suite.cases", "duplicate case name")
        }
        names[result.name] = true
        if result.passed {
          passed += 1
        }
        results.push(result)
      }
    }
    _ => invalid("suite.cases", "expected case array")
  }
  {
    schema_version: 1,
    policy: policy.name,
    cases: results.length(),
    passed,
    failed: results.length() - passed,
    results,
  }
}

///|
pub fn run_suite_json(source : String) -> String raise InputError {
  @json.to_json(run_suite(source)).stringify(indent=2)
}
