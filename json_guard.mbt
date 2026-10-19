///|
priv struct Cursor {
  text : String
  mut offset : Int
}

///|
// Run before the standard parser so malformed, deeply nested input cannot
// consume its default 1024-frame nesting allowance.
fn guard_depth(text : String, path : String) -> Unit raise InputError {
  let mut quoted = false
  let mut escaped = false
  let mut depth = 0
  for ch in text {
    if quoted {
      if escaped {
        escaped = false
      } else if ch == '\\' {
        escaped = true
      } else if ch == '"' {
        quoted = false
      }
    } else if ch == '"' {
      quoted = true
    } else if ch == '{' || ch == '[' {
      depth += 1
      if depth > 32 {
        invalid(path, "nesting exceeds 32")
      }
    } else if ch == '}' || ch == ']' {
      depth -= 1
    }
  }
}

///|
fn Cursor::space(self : Cursor) -> Unit {
  while self.offset < self.text.length() {
    let c = self.text[self.offset]
    if c == 32 || c == 9 || c == 10 || c == 13 {
      self.offset += 1
    } else {
      break
    }
  }
}

///|
// All cursor operations run only after the standard parser has accepted
// the complete document, so token and delimiter positions are valid.
fn Cursor::quoted(self : Cursor) -> String {
  let start = self.offset
  self.offset += 1
  while self.offset < self.text.length() {
    let c = self.text[self.offset]
    self.offset += 1
    if c == 92 {
      self.offset += 1
    } else if c == 34 {
      break
    }
  }
  self.text[start:self.offset].to_owned()
}

///|
fn Cursor::value(self : Cursor, path : String) -> Unit raise InputError {
  self.space()
  let c = self.text[self.offset]
  if c == 123 {
    self.offset += 1
    self.space()
    let keys : Map[String, Bool] = Map([])
    while self.text[self.offset] != 125 {
      let encoded = self.quoted()
      let decoded = @json.parse(encoded) catch {
        _ => invalid(path, "invalid object key")
      }
      let key = text_at(decoded, path)
      if keys.contains(key) {
        invalid(path, "duplicate object key")
      }
      keys[key] = true
      self.space()
      self.offset += 1 // colon
      self.value(path)
      self.space()
      if self.text[self.offset] == 125 {
        break
      }
      self.offset += 1 // comma
      self.space()
    }
    self.offset += 1
  } else if c == 91 {
    self.offset += 1
    self.space()
    while self.text[self.offset] != 93 {
      self.value(path)
      self.space()
      if self.text[self.offset] == 93 {
        break
      }
      self.offset += 1
      self.space()
    }
    self.offset += 1
  } else if c == 34 {
    self.quoted() |> ignore
  } else {
    while self.offset < self.text.length() {
      let c = self.text[self.offset]
      if c == 44 ||
        c == 93 ||
        c == 125 ||
        c == 32 ||
        c == 9 ||
        c == 10 ||
        c == 13 {
        break
      }
      self.offset += 1
    }
  }
}
