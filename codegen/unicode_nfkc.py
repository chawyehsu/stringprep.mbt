#!/usr/bin/env python3
"""
Codegen script for MoonBit NFKC normalization tables.

Adapted from unicode-normalization/scripts/unicode.py
Targets Unicode 3.2, outputs MoonBit sorted arrays with binary search.

Usage:
    python3 codegen/unicode_nfkc.py

Downloads Unicode 3.2 data files to codegen/data/ on first run (cached).
Generates unicode-nfkc/tables.mbt.
"""

import hashlib
import os
import urllib.request

UNICODE_VERSION = "3.2.0"
UCD_URL = "https://www.unicode.org/Public/3.2-Update/"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(SCRIPT_DIR, "data")
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "..", "src")

# SHA256 checksums for vendored data files
DATA_CHECKSUMS = {
    "UnicodeData-3.2.0.txt": "5e444028b6e76d96f9dc509609c5e3222bf609056f35e5fcde7e6fb8a58cd446",
    "DerivedNormalizationProps-3.2.0.txt": "bab49295e5f9064213762447224ccd83cea0cced0db5dcfc96f9c8a935ef67ee",
}

# Hangul constants (Unicode 3.2 Section 3.12)
S_BASE = 0xAC00
L_BASE = 0x1100
V_BASE = 0x1161
T_BASE = 0x11A7
L_COUNT = 19
V_COUNT = 21
T_COUNT = 28
N_COUNT = V_COUNT * T_COUNT  # 588
S_COUNT = L_COUNT * N_COUNT  # 11172


def sha256_of_file(filepath):
    """Compute SHA256 checksum of a file."""
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def fetch(filename):
    """Download a Unicode data file, caching in DATA_DIR. Verifies SHA256 if known."""
    os.makedirs(DATA_DIR, exist_ok=True)
    local_path = os.path.join(DATA_DIR, filename)
    if os.path.exists(local_path):
        if filename in DATA_CHECKSUMS:
            actual = sha256_of_file(local_path)
            expected = DATA_CHECKSUMS[filename]
            if actual != expected:
                raise ValueError(
                    f"Checksum mismatch for {filename}:\n"
                    f"  expected: {expected}\n"
                    f"  actual:   {actual}\n"
                    f"Delete {local_path} and re-run to re-download."
                )
        with open(local_path, "r", encoding="utf-8") as f:
            return f.read()
    print(f"Downloading {filename}...")
    resp = urllib.request.urlopen(UCD_URL + filename)
    data = resp.read().decode("utf-8")
    with open(local_path, "w", encoding="utf-8") as f:
        f.write(data)
    print("Verifying data file integrity...")
    if filename in DATA_CHECKSUMS:
        actual = sha256_of_file(local_path)
        expected = DATA_CHECKSUMS[filename]
        if actual != expected:
            os.remove(local_path)
            raise ValueError(
                f"Checksum mismatch for downloaded {filename}:\n"
                f"  expected: {expected}\n"
                f"  actual:   {actual}"
            )
    return data


def is_first_and_last(first, last):
    if not first.startswith("<") or not first.endswith(", First>"):
        return False
    if not last.startswith("<") or not last.endswith(", Last>"):
        return False
    return first[1:-8] == last[1:-7]


def load_unicode_data():
    """Parse UnicodeData.txt, return (combining_classes, canon_decomp, compat_decomp)."""
    combining_classes = {}
    canon_decomp = {}
    compat_decomp = {}

    prev_name = ""

    for line in fetch("UnicodeData-3.2.0.txt").splitlines():
        pieces = line.split(";")
        assert len(pieces) == 15, f"Expected 15 fields, got {len(pieces)}: {line}"
        char_int = int(pieces[0], 16)
        name = pieces[1].strip()
        cc = pieces[3]
        decomp = pieces[5]

        if cc != "0":
            combining_classes[char_int] = int(cc)

        if decomp.startswith("<"):
            # Compatibility decomposition
            compat_decomp[char_int] = [int(c, 16) for c in decomp.split()[1:]]
        elif decomp != "":
            # Canonical decomposition
            canon_decomp[char_int] = [int(c, 16) for c in decomp.split()]

        prev_name = name

    return combining_classes, canon_decomp, compat_decomp


def load_composition_exclusions():
    """Parse DerivedNormalizationProps.txt for Full_Composition_Exclusion."""
    exclusions = set()
    for line in fetch("DerivedNormalizationProps-3.2.0.txt").splitlines():
        prop_data, _, _ = line.partition("#")
        prop_pieces = prop_data.split(";")
        if len(prop_pieces) < 2:
            continue
        prop = prop_pieces[1].strip()
        if prop != "Full_Composition_Exclusion":
            continue
        low, _, high = prop_pieces[0].strip().partition("..")
        low_int = int(low, 16)
        high_int = int(high, 16) if high else low_int
        for c in range(low_int, high_int + 1):
            exclusions.add(c)
    return exclusions


def compute_canonical_comp(canon_decomp, exclusions):
    """Compute canonical composition table: (starter, combining) -> composed."""
    comp = {}
    for char_int, decomp in canon_decomp.items():
        if char_int in exclusions:
            continue
        if len(decomp) == 2:
            key = (decomp[0], decomp[1])
            assert key not in comp, f"Duplicate composition key: {key}"
            comp[key] = char_int
    return comp


def compute_fully_decomposed(canon_decomp, compat_decomp):
    """
    Precompute recursive decomposition (fully decomposed form).
    Returns (canon_fully, compat_fully) dicts.
    """
    def _decompose(char_int, compatible):
        if char_int <= 0x7F:
            yield char_int
            return
        if S_BASE <= char_int < S_BASE + S_COUNT:
            # Hangul handled algorithmically
            si = char_int - S_BASE
            li = si // N_COUNT
            vi = (si % N_COUNT) // T_COUNT
            ti = si % T_COUNT
            yield L_BASE + li
            yield V_BASE + vi
            if ti > 0:
                yield T_BASE + ti
            return
        decomp = canon_decomp.get(char_int)
        if decomp is not None:
            for d in decomp:
                yield from _decompose(d, compatible)
            return
        if compatible and char_int in compat_decomp:
            for d in compat_decomp[char_int]:
                yield from _decompose(d, compatible)
            return
        yield char_int

    all_keys = set(canon_decomp.keys()) | set(compat_decomp.keys())
    end_codepoint = max(all_keys) if all_keys else 0

    canon_fully = {}
    compat_fully = {}

    for char_int in range(0, end_codepoint + 1):
        if S_BASE <= char_int < S_BASE + S_COUNT:
            continue
        canon = list(_decompose(char_int, False))
        if not (len(canon) == 1 and canon[0] == char_int):
            canon_fully[char_int] = canon
        compat = list(_decompose(char_int, True))
        if not (len(compat) == 1 and compat[0] == char_int):
            compat_fully[char_int] = compat

    # Remove entries from compat that are identical to canon
    for ch in set(canon_fully) & set(compat_fully):
        if canon_fully[ch] == compat_fully[ch]:
            del compat_fully[ch]

    return canon_fully, compat_fully


def hex_char(c):
    """Format a codepoint as a MoonBit char literal."""
    if c <= 0x7F and chr(c).isprintable() and chr(c) != "'" and chr(c) != "\\":
        return f"'{chr(c)}'"
    return f"'\\u{{{c:04X}}}'"


def hex_uint(c):
    """Format a codepoint as a MoonBit hex literal."""
    return f"0x{c:X}"


def generate_tables(combining_classes, canon_fully, compat_fully, composition):
    """Generate unicode-nfkc/tables.mbt."""
    lines = []
    lines.append("// AUTOGENERATED CODE - DO NOT EDIT")
    lines.append(f"// Generated from Unicode {UNICODE_VERSION}")
    lines.append("// by codegen/unicode_nfkc.py")
    lines.append("")

    # Combining class table
    sorted_cc = sorted(combining_classes.items())
    lines.append("/// Canonical combining class table.")
    lines.append("/// Sorted by codepoint for binary search.")
    lines.append("let combining_class_table : Array[(UInt, Int)] = [")
    for cp, cc in sorted_cc:
        lines.append(f"  ({hex_uint(cp)}, {cc}),")
    lines.append("]")
    lines.append("")

    # Canonical decomposition table
    sorted_canon = sorted(canon_fully.items())
    lines.append("/// Canonical fully-decomposed forms.")
    lines.append("/// Sorted by codepoint for binary search.")
    lines.append("let canonical_decomp_table : Array[(UInt, Array[UInt])] = [")
    for cp, decomp in sorted_canon:
        arr = ", ".join(hex_uint(d) for d in decomp)
        lines.append(f"  ({hex_uint(cp)}, [{arr}]),")
    lines.append("]")
    lines.append("")

    # Compatibility decomposition table
    sorted_compat = sorted(compat_fully.items())
    lines.append("/// Compatibility fully-decomposed forms.")
    lines.append("/// Only entries that differ from canonical decomposition.")
    lines.append("/// Sorted by codepoint for binary search.")
    lines.append("let compat_decomp_table : Array[(UInt, Array[UInt])] = [")
    for cp, decomp in sorted_compat:
        arr = ", ".join(hex_uint(d) for d in decomp)
        lines.append(f"  ({hex_uint(cp)}, [{arr}]),")
    lines.append("]")
    lines.append("")

    # Composition table
    sorted_comp = sorted(composition.items())
    lines.append("/// Canonical composition table.")
    lines.append("/// (starter, combining) -> composed. Sorted by (starter, combining).")
    lines.append("let composition_table : Array[(UInt, UInt, UInt)] = [")
    for (c1, c2), c3 in sorted_comp:
        lines.append(f"  ({hex_uint(c1)}, {hex_uint(c2)}, {hex_uint(c3)}),")
    lines.append("]")
    lines.append("")

    return "\n".join(lines)


def main():
    print(f"Generating NFKC tables for Unicode {UNICODE_VERSION}...")
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    combining_classes, canon_decomp, compat_decomp = load_unicode_data()
    exclusions = load_composition_exclusions()
    composition = compute_canonical_comp(canon_decomp, exclusions)
    canon_fully, compat_fully = compute_fully_decomposed(canon_decomp, compat_decomp)

    print(f"  Combining classes: {len(combining_classes)} entries")
    print(f"  Canonical fully decomposed: {len(canon_fully)} entries")
    print(f"  Compatibility fully decomposed: {len(compat_fully)} entries")
    print(f"  Composition table: {len(composition)} entries")

    mbt_code = generate_tables(combining_classes, canon_fully, compat_fully, composition)

    output_path = os.path.join(OUTPUT_DIR, "nfkc_tables.mbt")
    with open(output_path, "w", newline="\n") as f:
        f.write(mbt_code)

    print(f"  Written to {output_path}")
    print("Done.")


if __name__ == "__main__":
    main()
