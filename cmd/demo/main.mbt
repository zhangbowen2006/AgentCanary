///|
fn main raise {
  let policy =
    #|{"schema_version":1,"name":"no-secret-egress","default_decision":"allow","rules":[{"id":"egress","kind":"block_labels","tool":"net.*","labels":["secret"]}]}
  let trace =
    #|{"id":"read","session":"demo","seq":1,"at_ms":0,"tool":"fs.read","resource":"/demo/secret.txt","output":"raw","labels":["secret"]}
    #|{"id":"summarize","session":"demo","seq":2,"at_ms":10,"tool":"text.summarize","resource":"local","inputs":["raw"],"output":"summary"}
    #|{"id":"send","session":"demo","seq":3,"at_ms":20,"tool":"net.post","resource":"https://example.invalid/upload","inputs":["summary"]}
  println(@canary.evaluate_json(policy, trace))
}
