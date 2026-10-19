///|
fn object_at(value : Json, path : String) -> Map[String, Json] raise InputError {
  match value {
    Object(fields) => fields
    _ => invalid(path, "expected object")
  }
}

///|
fn known_fields(
  fields : Map[String, Json],
  allowed : Array[String],
  path : String,
) -> Unit raise InputError {
  for key, _ in fields {
    if !allowed.contains(key) {
      invalid(path, "unknown field (check schema)")
    }
  }
}

///|
fn required(
  fields : Map[String, Json],
  key : String,
  path : String,
) -> Json raise InputError {
  match fields.get(key) {
    Some(value) => value
    None => invalid("\{path}.\{key}", "required field")
  }
}

///|
fn text_at(value : Json, path : String) -> String raise InputError {
  match value {
    String(s) => s
    _ => invalid(path, "expected string")
  }
}

///|
fn text_field(
  fields : Map[String, Json],
  key : String,
  path : String,
  fallback? : String,
) -> String raise InputError {
  match fields.get(key) {
    Some(value) => text_at(value, "\{path}.\{key}")
    None =>
      match fallback {
        Some(value) => value
        None => text_at(required(fields, key, path), "\{path}.\{key}")
      }
  }
}

///|
fn int_at(value : Json, path : String) -> Int32 raise InputError {
  match value {
    Number(n, ..) => {
      if n < 0.0 || n > 2147483647.0 || n != n.to_int().to_double() {
        invalid(path, "expected integer in [0, 2147483647]")
      }
      n.to_int()
    }
    _ => invalid(path, "expected nonnegative integer")
  }
}

///|
fn optional_int(
  fields : Map[String, Json],
  key : String,
  path : String,
) -> Int32? raise InputError {
  match fields.get(key) {
    Some(Null) | None => None
    Some(value) => Some(int_at(value, "\{path}.\{key}"))
  }
}

///|
fn optional_text(
  fields : Map[String, Json],
  key : String,
  path : String,
) -> String? raise InputError {
  match fields.get(key) {
    Some(Null) | None => None
    Some(value) => Some(text_at(value, "\{path}.\{key}"))
  }
}

///|
fn string_list(
  fields : Map[String, Json],
  key : String,
  path : String,
) -> Array[String] raise InputError {
  match fields.get(key) {
    None => []
    Some(Array(items)) => {
      if items.length() > 64 {
        invalid("\{path}.\{key}", "at most 64 items")
      }
      let result = []
      for i, item in items {
        result.push(text_at(item, "\{path}.\{key}[\{i}]"))
      }
      result
    }
    _ => invalid("\{path}.\{key}", "expected string array")
  }
}

///|
fn parse_json(source : String, path : String) -> Json raise InputError {
  if source.length() > 8388608 {
    invalid(path, "input exceeds 8 Mi UTF-16 units")
  }
  guard_depth(source, path)
  let value = @json.parse(source) catch {
    _ => invalid(path, "invalid JSON or nesting exceeds 32")
  }
  let cursor : Cursor = { text: source, offset: 0, }
  cursor.value(path)
  value
}

///|
fn event_from_json(value : Json, path : String) -> Event raise InputError {
  let f = object_at(value, path)
  known_fields(
    f,
    [
      "id", "session", "seq", "at_ms", "kind", "tool", "resource", "inputs", "output",
      "labels", "cost", "approval", "expires_ms", "outcome",
    ],
    path,
  )
  {
    id: text_field(f, "id", path),
    session: text_field(f, "session", path),
    seq: int_at(required(f, "seq", path), "\{path}.seq"),
    at_ms: int_at(required(f, "at_ms", path), "\{path}.at_ms"),
    kind: text_field(f, "kind", path, fallback="call"),
    tool: text_field(f, "tool", path, fallback=""),
    resource: text_field(f, "resource", path, fallback=""),
    inputs: string_list(f, "inputs", path),
    output: optional_text(f, "output", path),
    labels: string_list(f, "labels", path),
    cost: optional_int(f, "cost", path).unwrap_or(0),
    approval: optional_text(f, "approval", path),
    expires_ms: optional_int(f, "expires_ms", path),
    outcome: text_field(f, "outcome", path, fallback="ok"),
  }
}

///|
/// Accept a JSON array or JSONL. Blank JSONL lines are ignored; comments are errors.
pub fn parse_trace(source : String) -> Array[Event] raise InputError {
  if source.length() > 8388608 {
    invalid("trace", "input exceeds 8 Mi UTF-16 units")
  }
  let trimmed = source.trim().to_owned()
  let events : Array[Event] = []
  if trimmed.has_prefix("[") {
    match parse_json(trimmed, "trace") {
      Array(items) => {
        if items.length() > 10000 {
          invalid("trace", "at most 10000 events")
        }
        for i, item in items {
          events.push(event_from_json(item, "trace[\{i}]"))
        }
      }
      _ => invalid("trace", "expected array")
    }
  } else {
    for i, line in trimmed.split("\n").to_array() {
      let line = line.trim().to_owned()
      if !line.is_empty() {
        if events.length() >= 10000 {
          invalid("trace", "at most 10000 events")
        }
        events.push(
          event_from_json(parse_json(line, "line \{i + 1}"), "line \{i + 1}"),
        )
      }
    }
  }
  validate_trace(events)
  events
}

///|
fn rule_from_json(value : Json, path : String) -> Rule raise InputError {
  let f = object_at(value, path)
  known_fields(
    f,
    [
      "id", "kind", "tool", "resource", "labels", "limit", "window_ms", "prerequisite",
    ],
    path,
  )
  let kind = text_field(f, "kind", path)
  // Reject misspelled or inapplicable options instead of silently ignoring them.
  for key, _ in f {
    if key == "labels" && kind != "block_labels" {
      invalid(path, "labels is only valid for block_labels")
    }
    if key == "limit" && kind != "budget" && kind != "rate" {
      invalid(path, "limit is only valid for budget or rate")
    }
    if key == "window_ms" &&
      kind != "budget" &&
      kind != "rate" &&
      kind != "require_before" {
      invalid(path, "window_ms is not applicable to this rule")
    }
    if key == "prerequisite" && kind != "require_before" {
      invalid(path, "prerequisite is only valid for require_before")
    }
  }
  {
    id: text_field(f, "id", path),
    kind,
    tool: text_field(f, "tool", path, fallback="*"),
    resource: text_field(f, "resource", path, fallback="*"),
    labels: string_list(f, "labels", path),
    limit: optional_int(f, "limit", path),
    window_ms: optional_int(f, "window_ms", path),
    prerequisite: optional_text(f, "prerequisite", path),
  }
}

///|
pub fn parse_policy(source : String) -> Policy raise InputError {
  let f = object_at(parse_json(source, "policy"), "policy")
  known_fields(
    f,
    ["schema_version", "name", "default_decision", "rules"],
    "policy",
  )
  if int_at(required(f, "schema_version", "policy"), "policy.schema_version") !=
    1 {
    invalid("policy.schema_version", "only version 1 is supported")
  }
  let rules : Array[Rule] = []
  match required(f, "rules", "policy") {
    Array(items) => {
      if items.length() > 128 {
        invalid("policy.rules", "at most 128 rules")
      }
      for i, item in items {
        rules.push(rule_from_json(item, "policy.rules[\{i}]"))
      }
    }
    _ => invalid("policy.rules", "expected array")
  }
  let policy : Policy = {
    name: text_field(f, "name", "policy"),
    default_decision: text_field(f, "default_decision", "policy"),
    rules,
  }
  validate_policy(policy)
  policy
}
