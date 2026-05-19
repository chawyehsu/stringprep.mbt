#!/usr/bin/env python3
"""
Codegen script for RFC 3454 stringprep tables.

Reads from codegen/data/rfc3454.txt (vendored).
Generates src/tables.mbt with all RFC 3454 tables.

Usage:
    python3 codegen/rfc3454_tables.py
"""

import hashlib
import os
import re

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RFC3454_TXT = os.path.join(SCRIPT_DIR, "data", "rfc3454.txt")
OUTPUT = os.path.join(SCRIPT_DIR, "..", "src", "tables.mbt")

# SHA256 checksum for vendored rfc3454.txt
RFC3454_CHECKSUM = "eb722fa698fb7e8823b835d9fd263e4cdb8f1c7b0d234edf7f0e3bd2ccbb2c79"


def sha256_of_file(filepath):
    """Compute SHA256 checksum of a file."""
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def verify_rfc3454():
    """Verify the rfc3454.txt checksum."""
    if not os.path.exists(RFC3454_TXT):
        raise FileNotFoundError(f"Data file not found: {RFC3454_TXT}")
    actual = sha256_of_file(RFC3454_TXT)
    if actual != RFC3454_CHECKSUM:
        raise ValueError(
            f"Checksum mismatch for rfc3454.txt:\n"
            f"  expected: {RFC3454_CHECKSUM}\n"
            f"  actual:   {actual}"
        )


def read_table(table_name, filename=None):
    """Read a table from rfc3454.txt, return list of lines."""
    if filename is None:
        filename = RFC3454_TXT
    with open(filename, "r") as f:
        lines = f.readlines()

    start_marker = f"Start Table {table_name}"
    end_marker = "End Table"

    result = []
    in_table = False
    for line in lines:
        stripped = line.strip()
        if start_marker in stripped:
            in_table = True
            continue
        if in_table and end_marker in stripped:
            break
        if in_table:
            if stripped and "Hoffman & Blanchet" not in stripped and "RFC 3454" not in stripped:
                result.append(stripped)
    return result


def parse_range_line(line):
    """Parse a line like '0221' or '0234-024F' or '00A0; NO-BREAK SPACE' into (start, end) tuple of ints."""
    line = line.strip().rstrip(';').strip()
    # Remove any comment after #
    line = line.split('#')[0].strip()
    # Handle lines with semicolons (e.g., "00A0; NO-BREAK SPACE")
    # Also handle lines like "00A0..00A0; NO-BREAK SPACE"
    if ';' in line:
        line = line.split(';')[0].strip()
    # Handle range notation with ..
    if '..' in line:
        parts = line.split('..')
        return (int(parts[0], 16), int(parts[1], 16))
    elif '-' in line:
        parts = line.split('-')
        return (int(parts[0], 16), int(parts[1], 16))
    else:
        val = int(line, 16)
        return (val, val)


def parse_mapping_line(line):
    """Parse a line like '0041; 0061' into (input, [output_chars])."""
    line = line.strip()
    parts = line.split(';')
    input_cp = int(parts[0].strip(), 16)
    output_cps = [int(x.strip(), 16) for x in parts[1].strip().split()]
    return (input_cp, output_cps)


def hex_char(c):
    """Format codepoint as MoonBit char literal."""
    if 0x20 <= c <= 0x7E and c != ord("'") and c != ord("\\"):
        return f"'{chr(c)}'"
    return f"'\\u{{{c:04X}}}'"


def gen_range_table(table_name, mbt_name, lines):
    """Generate a range-based lookup table."""
    ranges = []
    for line in lines:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        s, e = parse_range_line(line)
        # Skip surrogate codepoints (invalid in MoonBit)
        if s >= 0xD800 and s <= 0xDFFF:
            continue
        if e >= 0xD800 and e <= 0xDFFF:
            continue
        ranges.append((s, e))

    out = []
    out.append(f"/// {table_name}")
    out.append(f"let {mbt_name} : Array[(Char, Char)] = [")
    for start, end in ranges:
        out.append(f"  ({hex_char(start)}, {hex_char(end)}),")
    out.append("]")
    return "\n".join(out), ranges


def gen_set_table(table_name, mbt_name, lines):
    """Generate a character set table using match arms."""
    chars = []
    ranges = []
    for line in lines:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        s, e = parse_range_line(line)
        # Skip surrogate codepoints (invalid in MoonBit)
        if s >= 0xD800 and s <= 0xDFFF:
            continue
        if e >= 0xD800 and e <= 0xDFFF:
            continue
        if s == e:
            chars.append(s)
        else:
            ranges.append((s, e))

    out = []
    out.append(f"/// {table_name}")
    out.append(f"fn {mbt_name}(c : Char) -> Bool {{")
    out.append("  match c {")
    for s, e in ranges:
        out.append(f"    {hex_char(s)}..={hex_char(e)} => true")
    for c in chars:
        out.append(f"    {hex_char(c)} => true")
    out.append("    _ => false")
    out.append("  }")
    out.append("}")
    return "\n".join(out)


def gen_mapping_table(table_name, mbt_name, lines):
    """Generate a mapping table (char -> string)."""
    mappings = []
    for line in lines:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        mappings.append(parse_mapping_line(line))

    out = []
    out.append(f"/// {table_name}")
    out.append(f"let {mbt_name} : Array[(Char, String)] = [")
    for input_cp, output_cps in mappings:
        output_str = "".join(f"\\u{{{c:04X}}}" for c in output_cps)
        out.append(f"  ({hex_char(input_cp)}, \"{output_str}\"),")
    out.append("]")
    return "\n".join(out), mappings


def gen_b1_set():
    """Generate B.1 commonly mapped to nothing."""
    chars = [
        0x00AD, 0x034F, 0x1806,
        0x180B, 0x180C, 0x180D,
        0x200B, 0x200C, 0x200D, 0x2060,
        0xFE00, 0xFE01, 0xFE02, 0xFE03, 0xFE04,
        0xFE05, 0xFE06, 0xFE07, 0xFE08, 0xFE09,
        0xFE0A, 0xFE0B, 0xFE0C, 0xFE0D, 0xFE0E, 0xFE0F,
        0xFEFF,
    ]
    out = []
    out.append("/// B.1 Commonly mapped to nothing")
    out.append("fn commonly_mapped_to_nothing(c : Char) -> Bool {")
    out.append("  match c {")
    for cp in chars:
        out.append(f"    {hex_char(cp)} => true")
    out.append("    _ => false")
    out.append("  }")
    out.append("}")
    return "\n".join(out)


def main():
    print("Verifying data file integrity...")
    verify_rfc3454()
    print("Generating RFC 3454 tables...")

    parts = []
    parts.append("// AUTOGENERATED CODE - DO NOT EDIT")
    parts.append("// Generated from RFC 3454 by codegen/rfc3454_tables.py")
    parts.append("")

    # A.1 Unassigned code points
    a1_lines = read_table("A.1")
    a1_code, a1_ranges = gen_range_table("A.1 Unassigned code points in Unicode 3.2", "a_1_table", a1_lines)
    parts.append(a1_code)
    parts.append("")
    print(f"  A.1: {len(a1_ranges)} ranges")

    # A.1 lookup function
    parts.append("/// Check if a character is an unassigned code point in Unicode 3.2.")
    parts.append("fn unassigned_code_point(c : Char) -> Bool {")
    parts.append("  let cp = c")
    parts.append("  match a_1_table.binary_search_by(fn(entry : (Char, Char)) {")
    parts.append("    if entry.1 < cp { return -1 }")
    parts.append("    if entry.0 > cp { return 1 }")
    parts.append("    0")
    parts.append("  }) {")
    parts.append("    Ok(_) => true")
    parts.append("    Err(_) => false")
    parts.append("  }")
    parts.append("}")
    parts.append("")

    # B.1 Commonly mapped to nothing
    parts.append(gen_b1_set())
    parts.append("")

    # B.2 Case folding for NFKC
    b2_lines = read_table("B.2")
    b2_code, b2_mappings = gen_mapping_table("B.2 Mapping for case-folding used with NFKC", "b_2_table", b2_lines)
    parts.append(b2_code)
    parts.append("")
    print(f"  B.2: {len(b2_mappings)} mappings")

    # B.2 lookup function
    parts.append("/// Case fold a character for NFKC.")
    parts.append("/// Returns the folded characters, or [c] if no mapping exists.")
    parts.append("fn case_fold_for_nfkc(c : Char) -> Array[Char] {")
    parts.append("  match b_2_table.binary_search_by(fn(entry : (Char, String)) { entry.0.compare(c) }) {")
    parts.append("    Ok(idx) => {")
    parts.append("      let s = b_2_table[idx].1")
    parts.append("      let result : Array[Char] = []")
    parts.append("      for ch in s { result.push(ch) }")
    parts.append("      result")
    parts.append("    }")
    parts.append("    Err(_) => [c]")
    parts.append("  }")
    parts.append("}")
    parts.append("")

    # C.1.1 ASCII space characters
    parts.append("/// C.1.1 ASCII space characters")
    parts.append("fn ascii_space_character(c : Char) -> Bool { c == ' ' }")
    parts.append("")

    # C.1.2 Non-ASCII space characters
    c12_lines = read_table("C.1.2")
    parts.append(gen_set_table("C.1.2 Non-ASCII space characters", "non_ascii_space_character", c12_lines))
    parts.append("")

    # C.2.1 ASCII control characters
    parts.append("/// C.2.1 ASCII control characters")
    parts.append("fn ascii_control_character(c : Char) -> Bool {")
    parts.append("  match c {")
    parts.append("    '\\u{0000}'..='\\u{001F}' | '\\u{007F}' => true")
    parts.append("    _ => false")
    parts.append("  }")
    parts.append("}")
    parts.append("")

    # C.2.2 Non-ASCII control characters
    c22_lines = read_table("C.2.2")
    parts.append(gen_set_table("C.2.2 Non-ASCII control characters", "non_ascii_control_character", c22_lines))
    parts.append("")

    # C.3 Private use
    parts.append("/// C.3 Private use")
    parts.append("fn private_use(c : Char) -> Bool {")
    parts.append("  match c {")
    parts.append("    '\\u{E000}'..='\\u{F8FF}' | '\\u{F0000}'..='\\u{FFFFD}' | '\\u{100000}'..='\\u{10FFFD}' => true")
    parts.append("    _ => false")
    parts.append("  }")
    parts.append("}")
    parts.append("")

    # C.4 Non-character code points
    parts.append("/// C.4 Non-character code points")
    parts.append("fn non_character_code_point(c : Char) -> Bool {")
    parts.append("  match c {")
    parts.append("    '\\u{FDD0}'..='\\u{FDEF}'")
    parts.append("    | '\\u{FFFE}'..='\\u{FFFF}'")
    parts.append("    | '\\u{1FFFE}'..='\\u{1FFFF}'")
    parts.append("    | '\\u{2FFFE}'..='\\u{2FFFF}'")
    parts.append("    | '\\u{3FFFE}'..='\\u{3FFFF}'")
    parts.append("    | '\\u{4FFFE}'..='\\u{4FFFF}'")
    parts.append("    | '\\u{5FFFE}'..='\\u{5FFFF}'")
    parts.append("    | '\\u{6FFFE}'..='\\u{6FFFF}'")
    parts.append("    | '\\u{7FFFE}'..='\\u{7FFFF}'")
    parts.append("    | '\\u{8FFFE}'..='\\u{8FFFF}'")
    parts.append("    | '\\u{9FFFE}'..='\\u{9FFFF}'")
    parts.append("    | '\\u{AFFFE}'..='\\u{AFFFF}'")
    parts.append("    | '\\u{BFFFE}'..='\\u{BFFFF}'")
    parts.append("    | '\\u{CFFFE}'..='\\u{CFFFF}'")
    parts.append("    | '\\u{DFFFE}'..='\\u{DFFFF}'")
    parts.append("    | '\\u{EFFFE}'..='\\u{EFFFF}'")
    parts.append("    | '\\u{FFFFE}'..='\\u{FFFFF}'")
    parts.append("    | '\\u{10FFFE}'..='\\u{10FFFF}' => true")
    parts.append("    _ => false")
    parts.append("  }")
    parts.append("}")
    parts.append("")

    # C.5 Surrogate codes
    parts.append("/// C.5 Surrogate codes")
    parts.append("fn surrogate_code(_c : Char) -> Bool { false }")
    parts.append("")

    # C.6 Inappropriate for plain text
    parts.append("/// C.6 Inappropriate for plain text")
    parts.append("fn inappropriate_for_plain_text(c : Char) -> Bool {")
    parts.append("  match c {")
    parts.append("    '\\u{FFF9}' | '\\u{FFFA}' | '\\u{FFFB}' | '\\u{FFFC}' | '\\u{FFFD}' => true")
    parts.append("    _ => false")
    parts.append("  }")
    parts.append("}")
    parts.append("")

    # C.7 Inappropriate for canonical representation
    parts.append("/// C.7 Inappropriate for canonical representation")
    parts.append("fn inappropriate_for_canonical_representation(c : Char) -> Bool {")
    parts.append("  match c {")
    parts.append("    '\\u{2FF0}'..='\\u{2FFB}' => true")
    parts.append("    _ => false")
    parts.append("  }")
    parts.append("}")
    parts.append("")

    # C.8 Change display properties or are deprecated
    parts.append("/// C.8 Change display properties or are deprecated")
    parts.append("fn change_display_properties_or_deprecated(c : Char) -> Bool {")
    parts.append("  match c {")
    parts.append("    '\\u{0340}' | '\\u{0341}'")
    parts.append("    | '\\u{200E}' | '\\u{200F}'")
    parts.append("    | '\\u{202A}' | '\\u{202B}' | '\\u{202C}' | '\\u{202D}' | '\\u{202E}'")
    parts.append("    | '\\u{206A}' | '\\u{206B}' | '\\u{206C}' | '\\u{206D}' | '\\u{206E}' | '\\u{206F}' => true")
    parts.append("    _ => false")
    parts.append("  }")
    parts.append("}")
    parts.append("")

    # C.9 Tagging characters
    parts.append("/// C.9 Tagging characters")
    parts.append("fn tagging_character(c : Char) -> Bool {")
    parts.append("  match c {")
    parts.append("    '\\u{E0001}' | '\\u{E0020}'..='\\u{E007F}' => true")
    parts.append("    _ => false")
    parts.append("  }")
    parts.append("}")
    parts.append("")

    # D.1 Characters with bidi property "R" or "AL"
    d1_lines = read_table("D.1")
    d1_code, d1_ranges = gen_range_table("D.1 Characters with bidirectional property R or AL", "d_1_table", d1_lines)
    parts.append(d1_code)
    parts.append("")
    print(f"  D.1: {len(d1_ranges)} ranges")

    # D.1 lookup function
    parts.append("/// Check if character has bidirectional property R or AL.")
    parts.append("fn bidi_r_or_al(c : Char) -> Bool {")
    parts.append("  match d_1_table.binary_search_by(fn(entry : (Char, Char)) {")
    parts.append("    if entry.1 < c { return -1 }")
    parts.append("    if entry.0 > c { return 1 }")
    parts.append("    0")
    parts.append("  }) {")
    parts.append("    Ok(_) => true")
    parts.append("    Err(_) => false")
    parts.append("  }")
    parts.append("}")
    parts.append("")

    # D.2 Characters with bidi property "L"
    d2_lines = read_table("D.2")
    d2_code, d2_ranges = gen_range_table("D.2 Characters with bidirectional property L", "d_2_table", d2_lines)
    parts.append(d2_code)
    parts.append("")
    print(f"  D.2: {len(d2_ranges)} ranges")

    # D.2 lookup function
    parts.append("/// Check if character has bidirectional property L.")
    parts.append("fn bidi_l(c : Char) -> Bool {")
    parts.append("  match d_2_table.binary_search_by(fn(entry : (Char, Char)) {")
    parts.append("    if entry.1 < c { return -1 }")
    parts.append("    if entry.0 > c { return 1 }")
    parts.append("    0")
    parts.append("  }) {")
    parts.append("    Ok(_) => true")
    parts.append("    Err(_) => false")
    parts.append("  }")
    parts.append("}")

    with open(OUTPUT, "w", newline="\n") as f:
        f.write("\n".join(parts))
        f.write("\n")

    print(f"  Written to {OUTPUT}")
    print("Done.")


if __name__ == "__main__":
    main()
