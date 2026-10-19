///|
/// Serialize only fields applicable to this rule kind, allowing strict roundtrips.
pub impl ToJson for Rule with fn to_json(self) {
  let fields : Map[String, Json] = {
    "id": Json::string(self.id),
    "kind": Json::string(self.kind),
    "tool": Json::string(self.tool),
    "resource": Json::string(self.resource),
  }
  if self.kind == "block_labels" {
    fields["labels"] = @json.to_json(self.labels)
  }
  if self.limit is Some(limit) {
    fields["limit"] = @json.to_json(limit)
  }
  if self.window_ms is Some(window) {
    fields["window_ms"] = @json.to_json(window)
  }
  if self.prerequisite is Some(pattern) {
    fields["prerequisite"] = Json::string(pattern)
  }
  Json::object(fields)
}

///|
pub impl ToJson for Policy with fn to_json(self) {
  {
    "schema_version": 1,
    "name": self.name,
    "default_decision": self.default_decision,
    "rules": @json.to_json(self.rules),
  }
}
