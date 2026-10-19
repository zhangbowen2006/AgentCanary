///|
/// Validate the whole observation before producing any decisions.
fn validate_trace(events : Array[Event]) -> Unit raise InputError {
  if events.length() > 10000 {
    invalid("trace", "at most 10000 events")
  }
  let ids : Map[String, Bool] = Map([])
  let clocks : Map[String, (Int, Int)] = Map([])
  let artifacts : Map[(String, String), Bool] = Map([])
  let approvals : Map[(String, String), Bool] = Map([])
  let vocabulary : Map[String, Array[String]] = Map([])
  let origins : Map[(String, String), Int] = Map([])
  for i, event in events {
    let path = "trace[\{i}]"
    check_text(event.id, "\{path}.id")
    check_text(event.session, "\{path}.session")
    if ids.contains(event.id) {
      invalid(path, "duplicate global event id")
    }
    ids[event.id] = true
    if event.seq < 0 || event.at_ms < 0 || event.cost < 0 {
      invalid(path, "negative sequence, time or cost")
    }
    if clocks.get(event.session) is Some((seq, time)) {
      if event.seq <= seq {
        invalid(path, "sequence must strictly increase within session")
      }
      if event.at_ms < time {
        invalid(path, "time must not decrease within session")
      }
    }
    clocks[event.session] = (event.seq, event.at_ms)
    unique_strings(event.inputs, "\{path}.inputs")
    unique_strings(event.labels, "\{path}.labels")
    let labels = vocabulary.get_or_init(event.session, () => [])
    for label in event.labels {
      if !labels.contains(label) {
        labels.push(label)
      }
      if labels.length() > 16 {
        invalid(path, "at most 16 distinct sensitivity labels per session")
      }
      let key = (event.session, label)
      let count = origins.get_or_default(key, 0) + 1
      if count > 64 {
        invalid(path, "at most 64 declared origins per label per session")
      }
      origins[key] = count
    }
    if event.resource.length() > 1024 {
      invalid(path, "resource too long")
    }
    match event.kind {
      "call" => {
        check_text(event.tool, "\{path}.tool")
        check_text(event.resource, "\{path}.resource", max=1024)
        if event.outcome != "ok" && event.outcome != "error" {
          invalid(path, "expected ok or error outcome")
        }
        if event.expires_ms is Some(_) {
          invalid(path, "call cannot declare an approval expiry")
        }
        if event.approval is Some(id) {
          check_text(id, "\{path}.approval")
        }
        for input in event.inputs {
          if !artifacts.contains((event.session, input)) {
            invalid(path, "input artifact not produced earlier in this session")
          }
        }
        if event.output is Some(output) {
          check_text(output, "\{path}.output")
          if event.outcome != "ok" {
            invalid(path, "failed calls cannot produce artifacts")
          }
          if artifacts.contains((event.session, output)) {
            invalid(path, "artifact IDs cannot be overwritten")
          }
          artifacts[(event.session, output)] = true
        }
      }
      "approve" => {
        check_text(event.tool, "\{path}.tool")
        check_text(event.resource, "\{path}.resource", max=1024)
        guard event.expires_ms is Some(expiry) else {
          invalid(path, "approve requires expires_ms")
          return
        }
        if expiry < event.at_ms {
          invalid(path, "approval expires before it is granted")
        }
        if event.approval is Some(_) {
          invalid(path, "approval grant ID is the event ID")
        }
        approvals[(event.session, event.id)] = true
      }
      "revoke" => {
        guard event.approval is Some(id) else {
          invalid(path, "revoke requires approval")
          return
        }
        if !approvals.contains((event.session, id)) {
          invalid(path, "cannot revoke unknown approval in this session")
        }
        if event.tool != "" ||
          event.resource != "" ||
          event.expires_ms is Some(_) {
          invalid(path, "revoke cannot carry a tool, resource or expiry")
        }
      }
      _ => invalid(path, "unsupported event kind")
    }
    if event.kind != "call" &&
      (
        event.cost != 0 ||
        !event.inputs.is_empty() ||
        !event.labels.is_empty() ||
        event.output is Some(_) ||
        event.outcome != "ok"
      ) {
      invalid(path, "control events cannot carry call data")
    }
  }
}
