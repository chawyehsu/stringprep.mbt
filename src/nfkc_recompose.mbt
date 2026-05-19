///|
/// Look up canonical composition: given (starter, combining), return composed char.
fn lookup_composition(starter : Char, combining : Char) -> Char? {
  let a = starter.to_uint()
  let b = combining.to_uint()
  // L + V -> LV (Hangul)
  let is_lv = a >= L_BASE &&
    a <= L_BASE + L_COUNT - 1 &&
    b >= V_BASE &&
    b <= V_BASE + V_COUNT - 1
  if is_lv {
    let l_index = a - L_BASE
    let v_index = b - V_BASE
    let lv_index = l_index * N_COUNT + v_index * T_COUNT
    return Some(uint_to_char(S_BASE + lv_index))
  }
  // LV + T -> LVT (Hangul)
  let is_lvt = a >= S_BASE &&
    a <= S_BASE + S_COUNT - 1 &&
    b >= T_BASE + 1 &&
    b <= T_BASE + T_COUNT - 1 &&
    (a - S_BASE) % T_COUNT == 0
  if is_lvt {
    return Some(uint_to_char(a + (b - T_BASE)))
  }
  // Table lookup
  match
    composition_table.binary_search_by(fn(entry : (UInt, UInt, UInt)) {
      if entry.0 < a {
        return -1
      }
      if entry.0 > a {
        return 1
      }
      entry.1.compare(b)
    }) {
    Ok(idx) => Some(uint_to_char(composition_table[idx].2))
    Err(_) => None
  }
}

///|
/// NFKC normalization: compatibility decomposition + canonical composition.
fn nfkc(s : String) -> String {
  // Phase 1: NFKD decomposition
  let decomposed : Array[(Int, Char)] = []
  for c in s {
    decompose_compatible_rec(c, fn(d) {
      decomposed.push((canonical_combining_class(d), d))
    })
  }
  reorder_combining_sequences(decomposed)

  // Phase 2: canonical composition
  let result : Array[Char] = []
  let mut composee : Char? = None
  let mut last_ccc : Int = 0

  for entry in decomposed {
    let (ccc, ch) = entry
    match composee {
      None => if ccc == 0 { composee = Some(ch) } else { result.push(ch) }
      Some(k) => {
        let can_compose = last_ccc == 0 || last_ccc < ccc
        if can_compose {
          match lookup_composition(k, ch) {
            Some(composed) => {
              composee = Some(composed)
              continue
            }
            None =>
              if ccc == 0 {
                result.push(k)
                composee = Some(ch)
                last_ccc = 0
              } else {
                result.push(ch)
                last_ccc = ccc
              }
          }
        } else if ccc == 0 {
          result.push(k)
          composee = Some(ch)
          last_ccc = 0
        } else {
          result.push(ch)
          last_ccc = ccc
        }
      }
    }
  }

  match composee {
    Some(k) => result.push(k)
    None => ()
  }

  let sb = StringBuilder()
  for c in result {
    sb.write_char(c)
  }
  sb.to_string()
}
