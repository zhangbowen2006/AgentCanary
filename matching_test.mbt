///|
test "glob is anchored, handles empty values and wildcard backtracking" {
  for
    item in [
      ("", "", true),
      ("*", "", true),
      ("?", "", false),
      ("abc", "abc", true),
      ("abc", "xabc", false),
      ("abc", "abcd", false),
      ("fs.*", "fs.read", true),
      ("fs.*", "fsXread", false),
      ("a*b*c", "axbyc", true),
      ("a*b*c", "axbyd", false),
      ("**a**b**", "xxaybzzz", true),
      ("*ab", "abab", true),
      ("a?c", "abc", true),
      ("a?c", "ac", false),
      ("/docs/*", "/docs/a/b", true),
      ("中文*", "中文资料", true),
      ("*?*?", "ab", true),
      ("*?*?", "a", false),
    ] {
    let (pattern, value, expected) = item
    assert_eq(@agentcanary.glob_matches(pattern, value), expected)
  }
}

///|
fn reference_glob(pattern : Array[Char], value : Array[Char]) -> Bool {
  let table = Array::makei(pattern.length() + 1, _ => {
    Array::make(value.length() + 1, false)
  })
  table[0][0] = true
  for i in 1..<=pattern.length() {
    if pattern[i - 1] == '*' {
      table[i][0] = table[i - 1][0]
    }
    for j in 1..<=value.length() {
      table[i][j] = if pattern[i - 1] == '*' {
        table[i - 1][j] || table[i][j - 1]
      } else {
        (pattern[i - 1] == '?' || pattern[i - 1] == value[j - 1]) &&
        table[i - 1][j - 1]
      }
    }
  }
  table[pattern.length()][value.length()]
}

///|
test "exhaustive small glob differential test against independent dynamic programming oracle" {
  let patterns = [""]
  let values = [""]
  for _ in 0..<4 {
    let current = patterns.copy()
    for p in current {
      for c in ["a", "b", "?", "*"] {
        let n = p + c
        if !patterns.contains(n) {
          patterns.push(n)
        }
      }
    }
  }
  for _ in 0..<4 {
    let current = values.copy()
    for v in current {
      for c in ["a", "b"] {
        let n = v + c
        if !values.contains(n) {
          values.push(n)
        }
      }
    }
  }
  for p in patterns {
    for v in values {
      assert_eq(
        @agentcanary.glob_matches(p, v),
        reference_glob(p.to_array(), v.to_array()),
      )
    }
  }
}

///|
test "glob question mark is a UTF16 unit, not a grapheme" {
  assert_true(!@agentcanary.glob_matches("?", "😀"))
  assert_true(@agentcanary.glob_matches("??", "😀"))
  assert_true(@agentcanary.glob_matches("*", "😀"))
}

///|
test "deny overrides allow independent of rule order" {
  let allow = "{\"id\":\"a\",\"kind\":\"allow\"}"
  let deny = "{\"id\":\"d\",\"kind\":\"deny\",\"tool\":\"fs.*\"}"
  assert_eq(
    verdict(policy(allow + "," + deny, default="deny"), [ev("e", 1)]),
    "deny",
  )
  assert_eq(
    verdict(policy(deny + "," + allow, default="deny"), [ev("e", 1)]),
    "deny",
  )
}

///|
test "default deny requires explicit allow, matching a guard is not an allow" {
  assert_eq(code(policy("", default="deny"), [ev("e", 1)]), "DEFAULT_DENY")
  let p = policy(
    "{\"id\":\"b\",\"kind\":\"budget\",\"limit\":100}",
    default="deny",
  )
  assert_eq(code(p, [ev("e", 1)]), "DEFAULT_DENY")
}

///|
test "tool and resource matches are conjunctive and case sensitive" {
  let p = policy(
    "{\"id\":\"d\",\"kind\":\"deny\",\"tool\":\"fs.write\",\"resource\":\"/private/*\"}",
  )
  assert_eq(
    verdict(p, [ev("a", 1, tool="fs.read", resource="/private/a")]),
    "allow",
  )
  assert_eq(
    verdict(p, [ev("a", 1, tool="fs.write", resource="/Private/a")]),
    "allow",
  )
  assert_eq(
    verdict(p, [ev("a", 1, tool="fs.write", resource="/private/a")]),
    "deny",
  )
}
