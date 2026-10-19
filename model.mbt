///|
/// A collector-supplied event. Times are nonnegative, relative milliseconds.
/// Costs use integer microcredits, never floating-point currency.
pub(all) struct Event {
  id : String
  session : String
  seq : Int
  at_ms : Int
  kind : String
  tool : String
  resource : String
  inputs : Array[String]
  output : String?
  labels : Array[String]
  cost : Int
  approval : String?
  expires_ms : Int?
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
  limit : Int?
  window_ms : Int?
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
  seq : Int
  at_ms : Int
  tool : String
  decision : String
  findings : Array[Finding]
  taints : Array[Taint]
} derive(Eq, ToJson)

///|
pub(all) struct Report {
  schema_version : Int
  policy : String
  events : Int
  calls : Int
  allowed : Int
  denied : Int
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
  schema_version : Int
  baseline : String
  candidate : String
  newly_denied : Int
  newly_allowed : Int
  explanation_changes : Int
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
