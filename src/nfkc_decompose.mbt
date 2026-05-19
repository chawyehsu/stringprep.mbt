///|
/// Hangul constants (Unicode 3.2 Section 3.12)
const S_BASE : UInt = 0xAC00

///|
const L_BASE : UInt = 0x1100

///|
const V_BASE : UInt = 0x1161

///|
const T_BASE : UInt = 0x11A7

///|
const L_COUNT : UInt = 19

///|
const V_COUNT : UInt = 21

///|
const T_COUNT : UInt = 28

///|
const N_COUNT : UInt = V_COUNT * T_COUNT

///|
const S_COUNT : UInt = L_COUNT * N_COUNT

///|
/// Convert a UInt codepoint to Char.
fn uint_to_char(cp : UInt) -> Char {
  cp.reinterpret_as_int().unsafe_to_char()
}

///|
/// Look up the canonical combining class for a character.
fn canonical_combining_class(c : Char) -> Int {
  let cp : UInt = c.to_uint()
  match
    combining_class_table.binary_search_by(fn(entry : (UInt, Int)) {
      entry.0.compare(cp)
    }) {
    Ok(idx) => combining_class_table[idx].1
    Err(_) => 0
  }
}

///|
/// Look up the canonical decomposition for a character.
fn lookup_canonical_decomp(c : Char) -> Array[Char]? {
  let cp : UInt = c.to_uint()
  if cp >= S_BASE && cp < S_BASE + S_COUNT {
    let s_index = cp - S_BASE
    let l_index = s_index / N_COUNT
    let v_index = s_index % N_COUNT / T_COUNT
    let t_index = s_index % T_COUNT
    let result : Array[Char] = [
      uint_to_char(L_BASE + l_index),
      uint_to_char(V_BASE + v_index),
    ]
    if t_index > 0 {
      result.push(uint_to_char(T_BASE + t_index))
    }
    return Some(result)
  }
  match
    canonical_decomp_table.binary_search_by(fn(entry : (UInt, Array[UInt])) {
      entry.0.compare(cp)
    }) {
    Ok(idx) =>
      Some(canonical_decomp_table[idx].1.map(fn(u : UInt) { uint_to_char(u) }))
    Err(_) => None
  }
}

///|
/// Look up the compatibility decomposition for a character.
fn lookup_compat_decomp(c : Char) -> Array[Char]? {
  let cp : UInt = c.to_uint()
  if cp >= S_BASE && cp < S_BASE + S_COUNT {
    return lookup_canonical_decomp(c)
  }
  match
    compat_decomp_table.binary_search_by(fn(entry : (UInt, Array[UInt])) {
      entry.0.compare(cp)
    }) {
    Ok(idx) =>
      Some(compat_decomp_table[idx].1.map(fn(u : UInt) { uint_to_char(u) }))
    Err(_) => None
  }
}

///|
/// Recursively decompose a character using compatibility decomposition.
fn decompose_compatible_rec(c : Char, emit : (Char) -> Unit) -> Unit {
  if c <= '\u{007F}' {
    emit(c)
    return
  }
  match lookup_compat_decomp(c) {
    Some(decomp) => {
      for d in decomp {
        decompose_compatible_rec(d, emit)
      }
      return
    }
    None => ()
  }
  match lookup_canonical_decomp(c) {
    Some(decomp) =>
      for d in decomp {
        decompose_compatible_rec(d, emit)
      }
    None => emit(c)
  }
}

///|
/// Reorder combining sequences in-place using insertion sort.
fn reorder_combining_sequences(buffer : Array[(Int, Char)]) -> Unit {
  let len = buffer.length()
  let mut i = 0
  while i < len {
    if buffer[i].0 == 0 {
      i += 1
      continue
    }
    let mut j = i + 1
    while j < len && buffer[j].0 > 0 {
      j += 1
    }
    // Insertion sort by ccc (stable)
    let mut k = i + 1
    while k < j {
      let key = buffer[k]
      let mut m = k
      while m > i && buffer[m - 1].0 > key.0 {
        buffer[m] = buffer[m - 1]
        m -= 1
      }
      buffer[m] = key
      k += 1
    }
    i = j
  }
}
