# stringprep.mbt

> Preparation of Internationalized Strings ("stringprep") as defined in [RFC 3454] in MoonBit

[![ci][ci-badge]][ci]
[![ci-daily][ci-daily-badge]][ci-daily]
[![version-svg]][mooncakes-url]
[![license][license-badge]](LICENSE-APACHE)

## Installation

Add the library to your project as a dependency:

```sh
moon add chawyehsu/stringprep
```

## API

**⚠️ The API is subject to change.**

### `stringprep.saslprep(s: String): String raise StringprepError`

Prepares a string using the SASLprep profile of the stringprep algorithm, as defined in [RFC 4013].

```mbt nocheck
@stringprep.saslprep("user") // "user"
@stringprep.saslprep("I\u{00AD}X") // "IX" (soft hyphen removed)
@stringprep.saslprep("a\u{00A0}b") // "a b" (non-ASCII space mapped to ASCII space)
@stringprep.saslprep("\u{2168}") // "IX" (roman numeral normalized via NFKC)
```

### `stringprep.nameprep(s: String): String raise StringprepError`

Prepares a string using the Nameprep profile of the stringprep algorithm, as defined in [RFC 3491]. Used for internationalized domain name (IDN) processing.

```mbt nocheck
@stringprep.nameprep("CAFE") // "cafe" (case folding)
@stringprep.nameprep("\u{00DF}") // "ss" (German sharp s)
@stringprep.nameprep("安室奈美恵-with-SUPER-MONKEYS") // "安室奈美恵-with-super-monkeys"
```

### `stringprep.nodeprep(s: String): String raise StringprepError`

Prepares a string using the Nodeprep profile of the stringprep algorithm, as defined in [RFC 3920, Appendix A]. Used for XMPP node identifier processing.

```mbt nocheck
@stringprep.nodeprep("räksmörgås.josefßon.org") // "räksmörgås.josefsson.org"
```

### `stringprep.resourceprep(s: String): String raise StringprepError`

Prepares a string using the Resourceprep profile of the stringprep algorithm, as defined in [RFC 3920, Appendix B]. Used for XMPP resource identifier processing.

```mbt nocheck
@stringprep.resourceprep("foo@bar") // "foo@bar"
```

### `stringprep.x520prep(s: String, case_fold~ : Bool): String raise StringprepError`

Prepares a string according to the procedures described in Section 7 of [ITU-T Recommendation X.520 (2019)]. Used for X.500 distinguished name processing.

```mbt nocheck
@stringprep.x520prep("UPPERCASED", case_fold=true) // "uppercased"
@stringprep.x520prep("foo@bar", case_fold=true) // "foo@bar"
```

### Error Handling

All profile functions raise `StringprepError` with the following variants:

- `ProhibitedCharacter(Char)` - The string contains a prohibited character
- `ProhibitedBidirectionalText` - The string violates bidirectional text rules
- `StartsWithCombiningCharacter` - The string starts with a combining character (x520prep only)
- `EmptyString` - The input string is empty (x520prep only)

```mbt nocheck
try @stringprep.saslprep("a\u{007F}b") catch {
  StringprepError::ProhibitedCharacter(c) => println("Prohibited: \{c}")
  _ => ()
}
```

## Contributing

The codebase might not yet be updated to support the latest version of MoonBit
language. An explicit version of the MoonBit toolchain has been pinned in the
`moonbit-version` file, which is used by the [moonup] tool.

```sh
moonup pin toolchain-version
```

To contribute, it is suggested to use `moonup` to manage the MoonBit toolchain.

### Code Generation

The project uses code generation for Unicode tables:

```sh
# Generate NFKC normalization tables (Unicode 3.2)
python3 codegen/unicode_nfkc.py

# Generate RFC 3454 stringprep tables
python3 codegen/rfc3454_tables.py
```

Unicode data files are downloaded on first run and cached in `codegen/data/`.

## References

- [RFC 3454] - Preparation of Internationalized Strings ("stringprep")
- [RFC 3491] - Nameprep: A Stringprep Profile for Internationalized Domain Names
- [RFC 3920] - Extensible Messaging and Presence Protocol (XMPP): Core
- [RFC 4013] - SASLprep: Stringprep Profile for User Names and Passwords
- [ITU-T X.520] - Information technology – Open Systems Interconnection – The Directory: Selected attribute types
- [Unicode 3.2.0] - Unicode Character Database

## License

**stringprep.mbt** © [Chawye Hsu](https://github.com/chawyehsu). Licensed under either of the [Apache License 2.0](LICENSE-APACHE) or [The Unlicense](UNLICENSE) license at your option.

> [Blog](https://chawyehsu.com) · GitHub [@chawyehsu](https://github.com/chawyehsu) · Twitter [@chawyehsu](https://twitter.com/chawyehsu)

[ci-badge]: https://github.com/chawyehsu/stringprep.mbt/workflows/CI/badge.svg
[ci-daily-badge]: https://github.com/chawyehsu/stringprep.mbt/actions/workflows/daily.yml/badge.svg
[ci]: https://github.com/chawyehsu/stringprep.mbt/actions/workflows/ci.yml
[ci-daily]: https://github.com/chawyehsu/stringprep.mbt/actions/workflows/daily.yml
[version-svg]: https://img.shields.io/badge/mooncakes.io-v0.0.1-orange
[mooncakes-url]: https://mooncakes.io/docs/chawyehsu/stringprep
[license-badge]: https://img.shields.io/github/license/chawyehsu/stringprep.mbt
[moonup]: https://github.com/chawyehsu/moonup
[RFC 3454]: https://datatracker.ietf.org/doc/html/rfc3454
[RFC 3491]: https://datatracker.ietf.org/doc/html/rfc3491
[RFC 3920]: https://datatracker.ietf.org/doc/html/rfc3920
[RFC 4013]: https://datatracker.ietf.org/doc/html/rfc4013
[ITU-T X.520]: https://www.itu.int/rec/T-REC-X.520-201910-I/en
[Unicode 3.2.0]: https://www.unicode.org/versions/Unicode3.2.0/
