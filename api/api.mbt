///|
fn error_json(message : String) -> String {
  let value : Json = {
    "schema_version": 1,
    "error": { "code": "INVALID_INPUT", "message": message },
  }
  value.stringify()
}

///|
pub fn test_suite(source : String) -> String {
  @canary.run_suite_json(source) catch {
    @canary.InputError(message) => error_json(message)
  }
}

///|
/// String-in/string-out ESM bridge. Domain logic is entirely in the core library.
pub fn audit(policy : String, trace : String) -> String {
  @canary.evaluate_json(policy, trace) catch {
    @canary.InputError(message) => error_json(message)
  }
}

///|
pub fn compare_policies(
  baseline : String,
  candidate : String,
  trace : String,
) -> String {
  @canary.compare_json(baseline, candidate, trace) catch {
    @canary.InputError(message) => error_json(message)
  }
}
