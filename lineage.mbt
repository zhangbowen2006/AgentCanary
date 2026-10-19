///|
fn append_unique(target : Array[String], source : Array[String]) -> Unit {
  for value in source {
    if !target.contains(value) {
      target.push(value)
    }
  }
}

///|
fn merge_taint(
  target : Array[Taint],
  label : String,
  sources : Array[String],
) -> Unit {
  for item in target {
    if item.label == label {
      append_unique(item.sources, sources)
      return
    }
  }
  target.push({ label, sources: sources.copy(), })
}

///|
fn call_taints(
  event : Event,
  artifacts : Map[(String, String), Array[Taint]],
) -> Array[Taint] {
  let taints : Array[Taint] = []
  for input in event.inputs {
    if artifacts.get((event.session, input)) is Some(items) {
      for item in items {
        merge_taint(taints, item.label, item.sources)
      }
    }
  }
  for label in event.labels {
    merge_taint(taints, label, [event.id])
  }
  taints
}

///|
fn label_evidence(
  taints : Array[Taint],
  labels : Array[String],
) -> Array[String] {
  let result = []
  for taint in taints {
    if labels.contains(taint.label) {
      append_unique(result, taint.sources)
    }
  }
  result
}
