///|
priv struct Grant {
  event : Event
  mut consumed : Bool
  mut revoked : Bool
}

///|
priv struct Charge {
  at_ms : Int
  value : Int64
  event_id : String
}

///|
priv struct Ledger {
  items : Array[Charge]
  mut start : Int
  mut total : Int64
}

///|
fn add_charge(
  ledger : Ledger,
  event : Event,
  value : Int64,
  window : Int?,
) -> Int64 {
  if window is Some(width) {
    // The window is (now - width, now]. The exact lower endpoint is excluded.
    while ledger.start < ledger.items.length() &&
          event.at_ms - ledger.items[ledger.start].at_ms >= width {
      ledger.total -= ledger.items[ledger.start].value
      ledger.start += 1
    }
  }
  ledger.items.push({ at_ms: event.at_ms, value, event_id: event.id })
  ledger.total += value
  ledger.total
}

///|
fn approval_status(
  event : Event,
  grants : Map[(String, String), Grant],
) -> (Bool, String, Array[String]) {
  guard event.approval is Some(id) else {
    return (false, "APPROVAL_MISSING", [])
  }
  guard grants.get((event.session, id)) is Some(grant) else {
    return (false, "APPROVAL_UNKNOWN", [])
  }
  let evidence = [id]
  if grant.revoked {
    return (false, "APPROVAL_REVOKED", evidence)
  }
  if grant.consumed {
    return (false, "APPROVAL_REUSED", evidence)
  }
  if grant.event.expires_ms is Some(expiry) && event.at_ms >= expiry {
    return (false, "APPROVAL_EXPIRED", evidence)
  }
  if grant.event.tool != event.tool || grant.event.resource != event.resource {
    return (false, "APPROVAL_SCOPE", evidence)
  }
  (true, "APPROVAL_OK", evidence)
}

///|
fn finding(
  rule : Rule,
  code : String,
  message : String,
  evidence : Array[String],
) -> Finding {
  { rule_id: rule.id, code, message, evidence }
}

///|
/// Replay observed calls, including calls a tested policy would deny.
/// This preserves actual artifact lineage and costs; it is not an alternate-world simulator.
pub fn evaluate(
  policy : Policy,
  events : Array[Event],
) -> Report raise InputError {
  validate_policy(policy)
  validate_trace(events)
  let grants : Map[(String, String), Grant] = Map([])
  let artifacts : Map[(String, String), Array[Taint]] = Map([])
  let ledgers : Map[(String, String), Ledger] = Map([])
  let prerequisites : Map[(String, String), Event] = Map([])
  let decisions : Array[Decision] = []
  let mut allowed = 0
  let mut denied = 0
  let mut observed_cost : Int64 = 0
  for event in events {
    match event.kind {
      "approve" =>
        grants[(event.session, event.id)] = {
          event,
          consumed: false,
          revoked: false,
        }
      "revoke" =>
        if event.approval is Some(id) &&
          grants.get((event.session, id)) is Some(grant) {
          grant.revoked = true
        }
      "call" => {
        observed_cost += event.cost.to_int64()
        let taints = call_taints(event, artifacts)
        let findings : Array[Finding] = []
        let mut explicitly_allowed = false
        let (approval_ok, approval_code, approval_evidence) = approval_status(
          event, grants,
        )
        for rule in policy.rules {
          if !rule_matches(rule, event) {
            continue
          }
          match rule.kind {
            "allow" => explicitly_allowed = true
            "deny" =>
              findings.push(
                finding(
                  rule,
                  "TOOL_DENIED",
                  "Tool and resource match a deny rule.",
                  [],
                ),
              )
            "require_approval" =>
              if !approval_ok {
                findings.push(
                  finding(
                    rule, approval_code, "A valid, unused, scoped approval is required.",
                    approval_evidence,
                  ),
                )
              }
            "block_labels" => {
              let evidence = label_evidence(taints, rule.labels)
              if !evidence.is_empty() {
                findings.push(
                  finding(
                    rule, "SENSITIVE_FLOW", "Declared or inherited sensitivity reaches this tool.",
                    evidence,
                  ),
                )
              }
            }
            "budget" | "rate" => {
              let key = (event.session, rule.id)
              let ledger = ledgers.get_or_init(key, () => {
                items: [],
                start: 0,
                total: 0L,
              })
              let value = if rule.kind == "budget" {
                event.cost.to_int64()
              } else {
                1L
              }
              let total = add_charge(ledger, event, value, rule.window_ms)
              if rule.limit is Some(limit) && total > limit.to_int64() {
                let code = if rule.kind == "budget" {
                  "BUDGET_EXCEEDED"
                } else {
                  "RATE_EXCEEDED"
                }
                // A bounded witness is sufficient for locating the active window.
                let evidence = [ledger.items[ledger.start].event_id, event.id]
                findings.push(
                  finding(
                    rule,
                    code,
                    "Observed window total \{total} exceeds limit \{limit}.",
                    evidence,
                  ),
                )
              }
            }
            "require_before" => {
              let witness = prerequisites.get((event.session, rule.id))
              let valid = match witness {
                Some(previous) =>
                  match rule.window_ms {
                    Some(width) => event.at_ms - previous.at_ms < width
                    None => true
                  }
                None => false
              }
              if !valid {
                findings.push(
                  finding(
                    rule,
                    "PREREQUISITE_MISSING",
                    "No prior successful prerequisite call in this session/window.",
                    [],
                  ),
                )
              }
            }
            _ => () // validate_policy rejects unknown kinds before replay.
          }
        }
        if policy.default_decision == "deny" && !explicitly_allowed {
          findings.push({
            rule_id: "$default",
            code: "DEFAULT_DENY",
            message: "No explicit allow rule matched.",
            evidence: [],
          })
        }
        let decision = if findings.is_empty() {
          allowed += 1
          "allow"
        } else {
          denied += 1
          "deny"
        }
        decisions.push({
          event_id: event.id,
          session: event.session,
          seq: event.seq,
          at_ms: event.at_ms,
          tool: event.tool,
          decision,
          findings,
          taints,
        })
        // The trace records what actually happened, irrespective of hypothetical decisions.
        if approval_ok &&
          event.approval is Some(id) &&
          grants.get((event.session, id)) is Some(grant) {
          grant.consumed = true
        }
        if event.output is Some(output) {
          artifacts[(event.session, output)] = taints
        }
        if event.outcome == "ok" {
          for rule in policy.rules {
            if rule.kind == "require_before" &&
              rule.prerequisite is Some(pattern) &&
              glob_matches(pattern, event.tool) {
              prerequisites[(event.session, rule.id)] = event
            }
          }
        }
      }
      _ => ()
    }
  }
  {
    schema_version: 1,
    policy: policy.name,
    events: events.length(),
    calls: decisions.length(),
    allowed,
    denied,
    observed_cost,
    decisions,
  }
}

///|
/// Parse, validate and evaluate, with deterministic JSON output.
pub fn evaluate_json(
  policy : String,
  trace : String,
) -> String raise InputError {
  @json.to_json(evaluate(parse_policy(policy), parse_trace(trace))).stringify(
    indent=2,
  )
}
