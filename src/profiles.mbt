///|
/// Implements stringprep profiles as defined in RFC 3454 and related RFCs.

///|
/// SASLprep profile (RFC 4013).
pub fn saslprep(s : String) -> String raise StringprepError {
  if is_ascii_safe(s) {
    return s
  }
  let sb = StringBuilder::new()
  for c in s {
    if non_ascii_space_character(c) {
      sb.write_char(' ')
    } else if !commonly_mapped_to_nothing(c) {
      sb.write_char(c)
    }
  }
  let normalized = nfkc(sb.to_string())
  for c in normalized {
    if is_saslprep_prohibited(c) {
      raise StringprepError::ProhibitedCharacter(c)
    }
  }
  if is_prohibited_bidirectional_text(normalized) {
    raise StringprepError::ProhibitedBidirectionalText
  }
  for c in normalized {
    if unassigned_code_point(c) {
      raise StringprepError::ProhibitedCharacter(c)
    }
  }
  normalized
}

///|
fn is_saslprep_prohibited(c : Char) -> Bool {
  non_ascii_space_character(c) ||
  ascii_control_character(c) ||
  non_ascii_control_character(c) ||
  private_use(c) ||
  non_character_code_point(c) ||
  surrogate_code(c) ||
  inappropriate_for_plain_text(c) ||
  inappropriate_for_canonical_representation(c) ||
  change_display_properties_or_deprecated(c) ||
  tagging_character(c)
}

///|
/// Nameprep profile (RFC 3491).
pub fn nameprep(s : String) -> String raise StringprepError {
  if is_nameprep_ascii_fast(s) {
    return s
  }
  let sb = StringBuilder::new()
  for c in s {
    if !commonly_mapped_to_nothing(c) {
      let folded = case_fold_for_nfkc(c)
      for fc in folded {
        sb.write_char(fc)
      }
    }
  }
  let normalized = nfkc(sb.to_string())
  for c in normalized {
    if is_nameprep_prohibited(c) {
      raise StringprepError::ProhibitedCharacter(c)
    }
  }
  if is_prohibited_bidirectional_text(normalized) {
    raise StringprepError::ProhibitedBidirectionalText
  }
  for c in normalized {
    if unassigned_code_point(c) {
      raise StringprepError::ProhibitedCharacter(c)
    }
  }
  normalized
}

///|
fn is_nameprep_prohibited(c : Char) -> Bool {
  non_ascii_space_character(c) ||
  non_ascii_control_character(c) ||
  private_use(c) ||
  non_character_code_point(c) ||
  surrogate_code(c) ||
  inappropriate_for_plain_text(c) ||
  inappropriate_for_canonical_representation(c) ||
  change_display_properties_or_deprecated(c) ||
  tagging_character(c)
}

///|
/// Nodeprep profile (RFC 3920 Appendix A).
pub fn nodeprep(s : String) -> String raise StringprepError {
  if is_nodeprep_ascii_fast(s) {
    return s
  }
  let sb = StringBuilder::new()
  for c in s {
    if !commonly_mapped_to_nothing(c) {
      let folded = case_fold_for_nfkc(c)
      for fc in folded {
        sb.write_char(fc)
      }
    }
  }
  let normalized = nfkc(sb.to_string())
  for c in normalized {
    if is_nodeprep_prohibited(c) {
      raise StringprepError::ProhibitedCharacter(c)
    }
  }
  if is_prohibited_bidirectional_text(normalized) {
    raise StringprepError::ProhibitedBidirectionalText
  }
  for c in normalized {
    if unassigned_code_point(c) {
      raise StringprepError::ProhibitedCharacter(c)
    }
  }
  normalized
}

///|
fn is_nodeprep_prohibited(c : Char) -> Bool {
  ascii_space_character(c) ||
  non_ascii_space_character(c) ||
  ascii_control_character(c) ||
  non_ascii_control_character(c) ||
  private_use(c) ||
  non_character_code_point(c) ||
  surrogate_code(c) ||
  inappropriate_for_plain_text(c) ||
  inappropriate_for_canonical_representation(c) ||
  change_display_properties_or_deprecated(c) ||
  tagging_character(c) ||
  prohibited_node_character(c)
}

///|
/// Resourceprep profile (RFC 3920 Appendix B).
pub fn resourceprep(s : String) -> String raise StringprepError {
  if is_resourceprep_ascii_fast(s) {
    return s
  }
  let sb = StringBuilder::new()
  for c in s {
    if !commonly_mapped_to_nothing(c) {
      sb.write_char(c)
    }
  }
  let normalized = nfkc(sb.to_string())
  for c in normalized {
    if is_resourceprep_prohibited(c) {
      raise StringprepError::ProhibitedCharacter(c)
    }
  }
  if is_prohibited_bidirectional_text(normalized) {
    raise StringprepError::ProhibitedBidirectionalText
  }
  for c in normalized {
    if unassigned_code_point(c) {
      raise StringprepError::ProhibitedCharacter(c)
    }
  }
  normalized
}

///|
fn is_resourceprep_prohibited(c : Char) -> Bool {
  non_ascii_space_character(c) ||
  ascii_control_character(c) ||
  non_ascii_control_character(c) ||
  private_use(c) ||
  non_character_code_point(c) ||
  surrogate_code(c) ||
  inappropriate_for_plain_text(c) ||
  inappropriate_for_canonical_representation(c) ||
  change_display_properties_or_deprecated(c) ||
  tagging_character(c)
}

///|
/// X.520 preparation (ITU-T Recommendation X.520, Section 7).
pub fn x520prep(s : String, case_fold~ : Bool) -> String raise StringprepError {
  if s.is_empty() {
    raise StringprepError::EmptyString
  }
  if is_x520_ascii_fast(s, case_fold) {
    return s
  }
  let sb = StringBuilder::new()
  for c in s {
    if !x520_mapped_to_nothing(c) {
      if x520_mapped_to_space(c) {
        sb.write_char(' ')
      } else {
        sb.write_char(c)
      }
    }
  }
  let normalized = if case_fold {
    let sb2 = StringBuilder::new()
    for c in sb.to_string() {
      let folded = case_fold_for_nfkc(c)
      for fc in folded {
        sb2.write_char(fc)
      }
    }
    nfkc(sb2.to_string())
  } else {
    nfkc(sb.to_string())
  }
  for c in normalized {
    if unassigned_code_point(c) ||
      private_use(c) ||
      non_character_code_point(c) ||
      surrogate_code(c) ||
      c == '\u{FFFD}' {
      raise StringprepError::ProhibitedCharacter(c)
    }
  }
  match s.get_char(0) {
    Some(c) =>
      if is_combining_char(c) {
        raise StringprepError::StartsWithCombiningCharacter
      }
    None => raise StringprepError::EmptyString
  }
  normalized
}

///|
/// Check if a character is a combining character (General Category = Mark).
fn is_combining_char(c : Char) -> Bool {
  match c {
    '\u{0300}'..='\u{036F}'
    | '\u{0483}'..='\u{0489}'
    | '\u{0591}'..='\u{05BD}'
    | '\u{05BF}'
    | '\u{05C1}'..='\u{05C2}'
    | '\u{05C4}'..='\u{05C5}'
    | '\u{05C7}'
    | '\u{0610}'..='\u{061A}'
    | '\u{064B}'..='\u{065F}'
    | '\u{0670}'
    | '\u{06D6}'..='\u{06DC}'
    | '\u{06DF}'..='\u{06E4}'
    | '\u{06E7}'..='\u{06E8}'
    | '\u{06EA}'..='\u{06ED}'
    | '\u{0711}'
    | '\u{0730}'..='\u{074A}'
    | '\u{07A6}'..='\u{07B0}'
    | '\u{07EB}'..='\u{07F3}'
    | '\u{0816}'..='\u{0819}'
    | '\u{081B}'..='\u{0823}'
    | '\u{0825}'..='\u{0827}'
    | '\u{0829}'..='\u{082D}'
    | '\u{0859}'..='\u{085B}'
    | '\u{08E3}'..='\u{0903}'
    | '\u{093A}'..='\u{093C}'
    | '\u{093E}'..='\u{094F}'
    | '\u{0951}'..='\u{0957}'
    | '\u{0962}'..='\u{0963}'
    | '\u{0981}'..='\u{0983}'
    | '\u{09BC}'
    | '\u{09BE}'..='\u{09C4}'
    | '\u{09C7}'..='\u{09C8}'
    | '\u{09CB}'..='\u{09CD}'
    | '\u{09D7}'
    | '\u{09E2}'..='\u{09E3}'
    | '\u{0A01}'..='\u{0A03}'
    | '\u{0A3C}'
    | '\u{0A3E}'..='\u{0A42}'
    | '\u{0A47}'..='\u{0A48}'
    | '\u{0A4B}'..='\u{0A4D}'
    | '\u{0A51}'
    | '\u{0A70}'..='\u{0A71}'
    | '\u{0A75}'
    | '\u{0A81}'..='\u{0A83}'
    | '\u{0ABC}'
    | '\u{0ABE}'..='\u{0AC5}'
    | '\u{0AC7}'..='\u{0AC9}'
    | '\u{0ACB}'..='\u{0ACD}'
    | '\u{0AE2}'..='\u{0AE3}'
    | '\u{0B01}'..='\u{0B03}'
    | '\u{0B3C}'
    | '\u{0B3E}'..='\u{0B44}'
    | '\u{0B47}'..='\u{0B48}'
    | '\u{0B4B}'..='\u{0B4D}'
    | '\u{0B56}'..='\u{0B57}'
    | '\u{0B62}'..='\u{0B63}'
    | '\u{0B82}'
    | '\u{0BBE}'..='\u{0BC2}'
    | '\u{0BC6}'..='\u{0BC8}'
    | '\u{0BCA}'..='\u{0BCD}'
    | '\u{0BD7}'
    | '\u{0C00}'..='\u{0C03}'
    | '\u{0C3E}'..='\u{0C44}'
    | '\u{0C46}'..='\u{0C48}'
    | '\u{0C4A}'..='\u{0C4D}'
    | '\u{0C55}'..='\u{0C56}'
    | '\u{0C62}'..='\u{0C63}'
    | '\u{0C81}'..='\u{0C83}'
    | '\u{0CBC}'
    | '\u{0CBE}'..='\u{0CC4}'
    | '\u{0CC6}'..='\u{0CC8}'
    | '\u{0CCA}'..='\u{0CCD}'
    | '\u{0CD5}'..='\u{0CD6}'
    | '\u{0CE2}'..='\u{0CE3}'
    | '\u{0D01}'..='\u{0D03}'
    | '\u{0D3E}'..='\u{0D44}'
    | '\u{0D46}'..='\u{0D48}'
    | '\u{0D4A}'..='\u{0D4D}'
    | '\u{0D57}'
    | '\u{0D62}'..='\u{0D63}'
    | '\u{0D82}'..='\u{0D83}'
    | '\u{0DCA}'
    | '\u{0DCF}'..='\u{0DD4}'
    | '\u{0DD6}'
    | '\u{0DD8}'..='\u{0DDF}'
    | '\u{0DF2}'..='\u{0DF3}'
    | '\u{0E31}'
    | '\u{0E34}'..='\u{0E3A}'
    | '\u{0E47}'..='\u{0E4E}'
    | '\u{0EB1}'
    | '\u{0EB4}'..='\u{0EB9}'
    | '\u{0EBB}'..='\u{0EBC}'
    | '\u{0EC8}'..='\u{0ECD}'
    | '\u{0F18}'..='\u{0F19}'
    | '\u{0F35}'
    | '\u{0F37}'
    | '\u{0F39}'
    | '\u{0F3E}'..='\u{0F3F}'
    | '\u{0F71}'..='\u{0F84}'
    | '\u{0F86}'..='\u{0F87}'
    | '\u{0F8D}'..='\u{0F97}'
    | '\u{0F99}'..='\u{0FBC}'
    | '\u{0FC6}'
    | '\u{102B}'..='\u{103E}'
    | '\u{1056}'..='\u{1059}'
    | '\u{105E}'..='\u{1060}'
    | '\u{1062}'..='\u{1064}'
    | '\u{1067}'..='\u{106D}'
    | '\u{1071}'..='\u{1074}'
    | '\u{1082}'..='\u{108D}'
    | '\u{108F}'
    | '\u{109A}'..='\u{109D}'
    | '\u{135D}'..='\u{135F}'
    | '\u{1712}'..='\u{1714}'
    | '\u{1732}'..='\u{1734}'
    | '\u{1752}'..='\u{1753}'
    | '\u{1772}'..='\u{1773}'
    | '\u{17B4}'..='\u{17D3}'
    | '\u{17DD}'
    | '\u{180B}'..='\u{180D}'
    | '\u{18A9}'
    | '\u{1920}'..='\u{192B}'
    | '\u{1930}'..='\u{193B}'
    | '\u{19B0}'..='\u{19C0}'
    | '\u{19C8}'..='\u{19C9}'
    | '\u{1A17}'..='\u{1A1B}'
    | '\u{1A55}'..='\u{1A5E}'
    | '\u{1A60}'..='\u{1A7C}'
    | '\u{1A7F}'
    | '\u{1AB0}'..='\u{1ABE}'
    | '\u{1B00}'..='\u{1B04}'
    | '\u{1B34}'..='\u{1B44}'
    | '\u{1B6B}'..='\u{1B73}'
    | '\u{1B80}'..='\u{1B82}'
    | '\u{1BA1}'..='\u{1BAD}'
    | '\u{1BE6}'..='\u{1BF3}'
    | '\u{1C24}'..='\u{1C37}'
    | '\u{1CD0}'..='\u{1CD2}'
    | '\u{1CD4}'..='\u{1CE8}'
    | '\u{1CED}'
    | '\u{1CF2}'..='\u{1CF4}'
    | '\u{1DC0}'..='\u{1DFF}'
    | '\u{20D0}'..='\u{20F0}'
    | '\u{2CEF}'..='\u{2CF1}'
    | '\u{2D7F}'
    | '\u{2DE0}'..='\u{2DFF}'
    | '\u{302A}'..='\u{302F}'
    | '\u{3099}'..='\u{309A}'
    | '\u{A66F}'..='\u{A672}'
    | '\u{A674}'..='\u{A67D}'
    | '\u{A69E}'..='\u{A69F}'
    | '\u{A6F0}'..='\u{A6F1}'
    | '\u{A802}'
    | '\u{A806}'
    | '\u{A80B}'
    | '\u{A823}'..='\u{A827}'
    | '\u{A880}'..='\u{A881}'
    | '\u{A8B4}'..='\u{A8C4}'
    | '\u{A8E0}'..='\u{A8F1}'
    | '\u{A926}'..='\u{A92D}'
    | '\u{A947}'..='\u{A953}'
    | '\u{A980}'..='\u{A983}'
    | '\u{A9B3}'..='\u{A9C0}'
    | '\u{A9E5}'
    | '\u{AA29}'..='\u{AA36}'
    | '\u{AA43}'
    | '\u{AA4C}'..='\u{AA4D}'
    | '\u{AA7B}'..='\u{AA7D}'
    | '\u{AAB0}'
    | '\u{AAB2}'..='\u{AAB4}'
    | '\u{AAB7}'..='\u{AAB8}'
    | '\u{AABE}'..='\u{AABF}'
    | '\u{AAC1}'
    | '\u{AAEB}'..='\u{AAEF}'
    | '\u{AAF5}'..='\u{AAF6}'
    | '\u{ABE3}'..='\u{ABEA}'
    | '\u{ABEC}'..='\u{ABED}'
    | '\u{FB1E}'
    | '\u{FE00}'..='\u{FE0F}'
    | '\u{FE20}'..='\u{FE2F}' => true
    _ => false
  }
}

///|
/// Additional characters not allowed in JID nodes (RFC 3920).
fn prohibited_node_character(c : Char) -> Bool {
  match c {
    '"' | '&' | '\'' | '/' | ':' | '<' | '>' | '@' => true
    _ => false
  }
}

///|
/// X.520: characters mapped to nothing (Section 7.2).
fn x520_mapped_to_nothing(c : Char) -> Bool {
  match c {
    '\u{00AD}'
    | '\u{1806}'
    | '\u{034F}'
    | '\u{180B}'..='\u{180D}'
    | '\u{FE00}'..='\u{FE0F}'
    | '\u{FFFC}'
    | '\u{200B}' => true
    _ => {
      let cp = c.to_uint()
      let is_exception = cp == 0x09 || (cp >= 0x0A && cp <= 0x0D) || cp == 0x85
      if is_exception {
        false
      } else {
        c.is_control()
      }
    }
  }
}

///|
/// X.520: characters mapped to space (Section 7.2).
fn x520_mapped_to_space(c : Char) -> Bool {
  match c {
    '\u{09}' | '\u{0A}'..='\u{0D}' | '\u{85}' => true
    _ => {
      let cp = c.to_uint()
      cp == 0x20 ||
      cp == 0xA0 ||
      cp == 0x1680 ||
      (cp >= 0x2000 && cp <= 0x200A) ||
      cp == 0x2028 ||
      cp == 0x2029 ||
      cp == 0x202F ||
      cp == 0x205F ||
      cp == 0x3000
    }
  }
}

// Fast path helpers

///|
fn is_ascii_safe(s : String) -> Bool {
  for c in s {
    if !c.is_ascii() || ascii_control_character(c) {
      return false
    }
  }
  true
}

///|
fn is_nameprep_ascii_fast(s : String) -> Bool {
  for c in s {
    if !c.is_ascii_lowercase() && !c.is_ascii_digit() && c != '.' && c != '-' {
      return false
    }
  }
  true
}

///|
fn is_nodeprep_ascii_fast(s : String) -> Bool {
  for c in s {
    let cp = c.to_uint()
    if !((cp >= 0x5B && cp <= 0x7E) ||
      (cp >= 0x30 && cp <= 0x39) ||
      (cp >= 0x28 && cp <= 0x2E) ||
      (cp >= 0x23 && cp <= 0x25)) {
      return false
    }
  }
  true
}

///|
fn is_resourceprep_ascii_fast(s : String) -> Bool {
  for c in s {
    let cp = c.to_uint()
    if cp < 0x20 || cp > 0x7E {
      return false
    }
  }
  true
}

///|
fn is_x520_ascii_fast(s : String, case_fold : Bool) -> Bool {
  for c in s {
    let cp = c.to_uint()
    if cp < 0x20 || cp > 0x7E {
      return false
    }
    if case_fold && !c.is_ascii_lowercase() {
      return false
    }
  }
  true
}
