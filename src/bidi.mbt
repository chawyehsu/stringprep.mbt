///|
/// Check if any character in the string satisfies the predicate.
fn any_char(s : String, pred : (Char) -> Bool) -> Bool {
  for c in s {
    if pred(c) {
      return true
    }
  }
  false
}

///|
/// RFC 3454 Section 6: Bidirectional Characters check.
///
/// A string is prohibited if:
/// 1. It contains RandALCat characters AND LCat characters, OR
/// 2. It contains RandALCat characters but doesn't start AND end with one.
fn is_prohibited_bidirectional_text(s : String) -> Bool {
  let has_r_or_al = any_char(s, bidi_r_or_al)
  if !has_r_or_al {
    return false
  }
  // Rule: RandALCat string must not contain LCat
  let has_l = any_char(s, bidi_l)
  if has_l {
    return true
  }
  // Rule: RandALCat must be first and last
  let first_char = s.get_char(0)
  let last_char = s.get_char(s.length() - 1)
  match (first_char, last_char) {
    (Some(f), Some(l)) => !bidi_r_or_al(f) || !bidi_r_or_al(l)
    _ => true
  }
}
