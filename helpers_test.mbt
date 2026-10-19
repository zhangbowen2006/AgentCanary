///|
fn policy(
  rules : String,
  default? : String = "allow",
) -> @agentcanary.Policy raise {
  @agentcanary.parse_policy(
    "{\"schema_version\":1,\"name\":\"test\",\"default_decision\":\"" +
    default +
    "\",\"rules\":[" +
    rules +
    "]}",
  )
}

///|
fn ev(
  id : String,
  seq : Int,
  at_ms? : Int,
  tool? : String = "fs.read",
  resource? : String = "/workspace/a.txt",
  session? : String = "s1",
  inputs? : Array[String] = [],
  output? : String,
  labels? : Array[String] = [],
  cost? : Int = 0,
  approval? : String,
  outcome? : String = "ok",
  kind? : String = "call",
  expires_ms? : Int,
) -> @agentcanary.Event {
  {
    id,
    session,
    seq,
    at_ms: at_ms.unwrap_or(seq * 10),
    kind,
    tool,
    resource,
    inputs,
    output,
    labels,
    cost,
    approval,
    expires_ms,
    outcome,
  }
}

///|
fn verdict(
  p : @agentcanary.Policy,
  events : Array[@agentcanary.Event],
  index? : Int = 0,
) -> String raise {
  @agentcanary.evaluate(p, events).decisions[index].decision
}

///|
fn code(
  p : @agentcanary.Policy,
  events : Array[@agentcanary.Event],
  index? : Int = 0,
) -> String raise {
  @agentcanary.evaluate(p, events).decisions[index].findings[0].code
}

///|
fn rejects_trace(events : Array[@agentcanary.Event]) -> Bool raise {
  let p = policy("")
  try {
    @agentcanary.evaluate(p, events) |> ignore
    false
  } catch {
    _ => true
  }
}

///|
fn rejects_policy(source : String) -> Bool {
  try {
    @agentcanary.parse_policy(source) |> ignore
    false
  } catch {
    _ => true
  }
}

///|
fn rejects_json_trace(source : String) -> Bool {
  try {
    @agentcanary.parse_trace(source) |> ignore
    false
  } catch {
    _ => true
  }
}
