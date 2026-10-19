///|
/// Anchored glob matching: '*' spans zero or more UTF-16 units, '?' one unit.
/// Backslash is an ordinary character; no regex, path or URL normalization occurs.
/// A linear-space greedy matcher avoids recursive wildcard expansion.
pub fn glob_matches(pattern : String, value : String) -> Bool {
  let mut p = 0
  let mut v = 0
  let mut star = -1
  let mut retry = 0
  while v < value.length() {
    if p < pattern.length() && (pattern[p] == 63 || pattern[p] == value[v]) {
      p += 1
      v += 1
    } else if p < pattern.length() && pattern[p] == 42 {
      star = p
      p += 1
      retry = v
    } else if star >= 0 {
      retry += 1
      v = retry
      p = star + 1
    } else {
      return false
    }
  }
  while p < pattern.length() && pattern[p] == 42 {
    p += 1
  }
  p == pattern.length()
}

///|
fn rule_matches(rule : Rule, event : Event) -> Bool {
  glob_matches(rule.tool, event.tool) &&
  glob_matches(rule.resource, event.resource)
}

///|
fn check_text(
  value : String,
  path : String,
  max~ : Int32 = 256,
) -> Unit raise InputError {
  if value.is_empty() ||
    value.length() > max ||
    value.any(c => c < ' ' || c == '\u007f') {
    invalid(path, "expected nonempty bounded text without control characters")
  }
}

///|
fn unique_strings(
  values : Array[String],
  path : String,
) -> Unit raise InputError {
  if values.length() > 64 {
    invalid(path, "at most 64 entries")
  }
  let seen : Map[String, Bool] = Map([])
  for value in values {
    check_text(value, path)
    if seen.contains(value) {
      invalid(path, "duplicate entry")
    }
    seen[value] = true
  }
}

///|
fn validate_policy(policy : Policy) -> Unit raise InputError {
  check_text(policy.name, "policy.name")
  if policy.default_decision != "allow" && policy.default_decision != "deny" {
    invalid("policy.default_decision", "expected allow or deny")
  }
  if policy.rules.length() > 128 {
    invalid("policy.rules", "at most 128 rules")
  }
  let ids : Map[String, Bool] = Map([])
  for i, rule in policy.rules {
    let path = "policy.rules[\{i}]"
    check_text(rule.id, "\{path}.id")
    if ids.contains(rule.id) {
      invalid(path, "duplicate rule id")
    }
    ids[rule.id] = true
    check_text(rule.tool, "\{path}.tool")
    check_text(rule.resource, "\{path}.resource", max=1024)
    unique_strings(rule.labels, "\{path}.labels")
    match rule.kind {
      "allow" | "deny" | "require_approval" => ()
      "block_labels" =>
        if rule.labels.is_empty() {
          invalid(path, "block_labels requires labels")
        }
      "budget" | "rate" => {
        guard rule.limit is Some(limit) && limit >= 0 else {
          invalid(path, "budget/rate requires nonnegative limit")
          return
        }
        if rule.kind == "rate" && rule.window_ms is None {
          invalid(path, "rate requires window_ms")
        }
      }
      "require_before" => {
        guard rule.prerequisite is Some(pattern) else {
          invalid(path, "require_before requires prerequisite")
          return
        }
        check_text(pattern, "\{path}.prerequisite")
      }
      _ => invalid(path, "unsupported rule kind")
    }
    if rule.window_ms is Some(window) && window <= 0 {
      invalid(path, "window_ms must be positive")
    }
    if rule.kind != "block_labels" && !rule.labels.is_empty() {
      invalid(path, "inapplicable labels")
    }
    if rule.kind != "budget" && rule.kind != "rate" && rule.limit is Some(_) {
      invalid(path, "inapplicable limit")
    }
    if rule.kind != "budget" &&
      rule.kind != "rate" &&
      rule.kind != "require_before" &&
      rule.window_ms is Some(_) {
      invalid(path, "inapplicable window_ms")
    }
    if rule.kind != "require_before" && rule.prerequisite is Some(_) {
      invalid(path, "inapplicable prerequisite")
    }
  }
}
