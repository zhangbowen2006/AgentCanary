///|
// Validate the original numeric token with decimal digits, so IEEE-754
// rounding/underflow cannot turn a fraction into
// an apparently valid integer cost, timestamp or limit.
fn exact_integer(source : String, path : String) -> Int32 raise InputError {
  if source.length() > 64 {
    invalid(path, "numeric spelling exceeds 64 units")
  }
  let digits : Array[Int32] = []
  let mut fraction = 0
  let mut after_dot = false
  let mut exponent = 0
  let mut exp_negative = false
  let mut in_exponent = false
  let mut negative = false
  for i in 0..<source.length() {
    let c = source[i]
    if i == 0 && c == 45 {
      negative = true
    } else if c == 101 || c == 69 {
      in_exponent = true
    } else if in_exponent && (c == 43 || c == 45) {
      exp_negative = c == 45
    } else if c == 46 {
      after_dot = true
    } else if c >= 48 && c <= 57 {
      let digit = c.to_int() - 48
      if in_exponent {
        exponent = (exponent * 10 + digit).min(1001)
      } else {
        digits.push(digit)
        if after_dot {
          fraction += 1
        }
      }
    } else {
      invalid(path, "invalid numeric spelling")
    }
  }
  if digits.all(d => d == 0) {
    return 0
  }
  if negative {
    invalid(path, "expected nonnegative integer")
  }
  let shift = (if exp_negative { -exponent } else { exponent }) - fraction
  let mut keep = digits.length()
  if shift < 0 {
    if -shift >= digits.length() {
      invalid(path, "expected exact integer")
    }
    keep += shift
    for i in keep..<digits.length() {
      if digits[i] != 0 {
        invalid(path, "expected exact integer")
      }
    }
  }
  let mut value = 0
  for i in 0..<keep {
    let digit = digits[i]
    if value > (2147483647 - digit) / 10 {
      invalid(path, "integer exceeds 2147483647")
    }
    value = value * 10 + digit
  }
  if shift > 0 {
    if shift > 10 {
      invalid(path, "integer exceeds 2147483647")
    }
    for _ in 0..<shift {
      if value > 2147483647 / 10 {
        invalid(path, "integer exceeds 2147483647")
      }
      value *= 10
    }
  }
  value
}
