///|
/// A collector-supplied event. Times are nonnegative, relative milliseconds.
/// Costs use integer microcredits, never floating-point currency.
pub(all) struct Event {
  id : String
  session : String
  seq : Int32
  at_ms : Int32
  kind : String
  tool : String
  resource : String
  inputs : Array[String]
  output : String?
  labels : Array[String]
  cost : Int32
  approval : String?
  expires_ms : Int32?
  outcome : String
} derive(Eq, ToJson)

///|
/// Only fields used by the selected rule kind may be supplied in JSON.
pub(all) struct Rule {
  id : String
  kind : String
  tool : String
  resource : String
  labels : Array[String]
  limit : Int32?
  window_ms : Int32?
  prerequisite : String?
} derive(Eq)

///|
pub(all) struct Policy {
  name : String
  default_decision : String
  rules : Array[Rule]
} derive(Eq)

///|
/// Source event IDs explaining one sensitivity label.
pub(all) struct Taint {
  label : String
  sources : Array[String]
} derive(Eq, ToJson)

///|
pub(all) struct Finding {
  rule_id : String
  code : String
  message : String
  evidence : Array[String]
} derive(Eq, ToJson)

///|
pub(all) struct Decision {
  event_id : String
  session : String
  seq : Int32
  at_ms : Int32
  tool : String
  decision : String
  findings : Array[Finding]
  taints : Array[Taint]
} derive(Eq, ToJson)

///|
pub(all) struct Report {
  schema_version : Int32
  policy : String
  events : Int32
  calls : Int32
  allowed : Int32
  denied : Int32
  observed_cost : Int64
  decisions : Array[Decision]
} derive(Eq, ToJson)

///|
pub(all) struct Change {
  event_id : String
  session : String
  before : String
  after : String
  before_rules : Array[String]
  after_rules : Array[String]
  before_findings : Array[Finding]
  after_findings : Array[Finding]
} derive(Eq, ToJson)

///|
pub(all) struct Comparison {
  schema_version : Int32
  baseline : String
  candidate : String
  newly_denied : Int32
  newly_allowed : Int32
  explanation_changes : Int32
  changes : Array[Change]
} derive(Eq, ToJson)

///|
/// Structured diagnostic. Messages contain field paths, never raw input values.
pub(all) suberror InputError {
  InputError(String)
} derive(Eq)

///|
fn[T] invalid(path : String, message : String) -> T raise InputError {
  raise InputError("\{path}: \{message}")
}
