///|
/// Integration tests for stringprep profiles.

///|
test "saslprep basic" {
  // Latin letters
  inspect(saslprep("user"), content="user")
  // Preserve case
  inspect(saslprep("USER"), content="USER")
  // Remove mapped to nothing (soft hyphen)
  inspect(saslprep("I\u{00AD}X"), content="IX")
  // Replace non-ASCII space
  inspect(saslprep("a\u{00A0}b"), content="a b")
  // Normalize NFKC
  inspect(saslprep("\u{00AA}"), content="a")
  inspect(saslprep("\u{2168}"), content="IX")
}

///|
test "saslprep prohibited characters" {
  // C.2.1 ASCII control characters
  let r1 = try? saslprep("a\u{007F}b")
  assert_true(r1 is Err(_))
  // C.2.2 Non-ASCII control characters
  let r2 = try? saslprep("a\u{06DD}b")
  assert_true(r2 is Err(_))
  // C.3 Private use
  let r3 = try? saslprep("a\u{E000}b")
  assert_true(r3 is Err(_))
}

///|
test "saslprep bidi" {
  // RandALCat must be first and last
  let r1 = try? saslprep("\u{0627}\u{0031}")
  assert_true(r1 is Err(_))
  // Valid RandALCat
  let r2 = saslprep("\u{0627}\u{0031}\u{0628}")
  assert_true(r2 == "\u{0627}\u{0031}\u{0628}")
}

///|
test "saslprep unassigned" {
  let r = try? saslprep("a\u{0487}b")
  assert_true(r is Err(_))
}

///|
test "nameprep basic" {
  // Case folding
  inspect(nameprep("CAFE"), content="cafe")
  // German sharp s
  inspect(nameprep("\u{00DF}"), content="ss")
  // Multi-language
  inspect(
    nameprep("安室奈美恵-with-SUPER-MONKEYS"),
    content="安室奈美恵-with-super-monkeys",
  )
}

///|
test "nameprep map to nothing" {
  inspect(
    nameprep(
      "foo\u{00AD}\u{034F}\u{1806}\u{180B}bar\u{200B}\u{2060}baz\u{FE00}\u{FE08}\u{FE0F}\u{FEFF}",
    ),
    content="foobarbaz",
  )
}

///|
test "nameprep prohibited" {
  // Non-ASCII multibyte space
  let r1 = try? nameprep("\u{1680}")
  assert_true(r1 is Err(_))
  // Non-ASCII control
  let r2 = try? nameprep("\u{0085}")
  assert_true(r2 is Err(_))
}

///|
test "nameprep bidi" {
  // RandALCat + LCat
  let r1 = try? nameprep("foo\u{05BE}bar")
  assert_true(r1 is Err(_))
  // Valid RandALCat
  let r2 = nameprep("\u{0627}\u{0031}\u{0628}")
  assert_true(r2 == "\u{0627}\u{0031}\u{0628}")
}

///|
test "nodeprep basic" {
  // Case folding
  inspect(
    nodeprep("räksmörgås.josefßon.org"),
    content="räksmörgås.josefsson.org",
  )
}

///|
test "nodeprep prohibited" {
  // Space prohibited
  let r1 = try? nodeprep(" ")
  assert_true(r1 is Err(_))
  // Non-ASCII space
  let r2 = try? nodeprep("\u{00A0}")
  assert_true(r2 is Err(_))
  // @ prohibited in node
  let r3 = try? nodeprep("foo@bar")
  assert_true(r3 is Err(_))
}

///|
test "resourceprep basic" {
  inspect(resourceprep("foo@bar"), content="foo@bar")
}

///|
test "x520prep basic" {
  inspect(x520prep("foo@bar", case_fold=true), content="foo@bar")
  inspect(x520prep("UPPERCASED", case_fold=true), content="uppercased")
}
