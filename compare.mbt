///|
fn rules_of(decision : Decision) -> Array[String] {
  decision.findings.map(f => f.rule_id)
}

///|
/// Compare both policies against exactly the same observed history.
/// Explanation changes include changed error codes/evidence, even with the same verdict.
pub fn compare(
  baseline : Policy,
  candidate : Policy,
  events : Array[Event],
) -> Comparison raise InputError {
  let before = evaluate(baseline, events)
  let after = evaluate(candidate, events)
  let changes : Array[Change] = []
  let mut newly_denied = 0
  let mut newly_allowed = 0
  let mut explanation_changes = 0
  for i, a in before.decisions {
    let b = after.decisions[i]
    if a.decision != b.decision || a.findings != b.findings {
      if a.decision == "allow" && b.decision == "deny" {
        newly_denied += 1
      } else if a.decision == "deny" && b.decision == "allow" {
        newly_allowed += 1
      } else {
        explanation_changes += 1
      }
      changes.push({
        event_id: a.event_id,
        session: a.session,
        before: a.decision,
        after: b.decision,
        before_rules: rules_of(a),
        after_rules: rules_of(b),
      })
    }
  }
  {
    schema_version: 1,
    baseline: baseline.name,
    candidate: candidate.name,
    newly_denied,
    newly_allowed,
    explanation_changes,
    changes,
  }
}

///|
pub fn compare_json(
  baseline : String,
  candidate : String,
  trace : String,
) -> String raise InputError {
  @json.to_json(
    compare(parse_policy(baseline), parse_policy(candidate), parse_trace(trace)),
  ).stringify(indent=2)
}
