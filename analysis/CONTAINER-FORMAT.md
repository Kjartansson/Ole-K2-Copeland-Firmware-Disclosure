# Copeland SFUB_update container format — static analysis

Static, offline analysis of the `SFUB_update` firmware container used by Copeland
Site Supervisor (SS) and E3 Supervisory Control update packages. No firmware or
updater code was executed; all evidence below is reproducible with
`tools/sfub_info.py` (read-only, stdlib-only) on the packages listed in
`SOURCES.md`. Per-file machine-readable evidence: `results/sfub-*.json`;
human-readable dumps: `results/sfub-*.txt`; comparison table:
`results/sfub-cross-version.txt`.

Analyzed inputs (all hashes verified against `firmware/SHA256SUMS` via
`sha256sum -c`, 2026-10-24):

| Package | Bytes | Outer container | Inner SFUB sha256 |
|---|---|---|---|
| firmware/SS_2.23F02_Firmware_Update.pkg | 52,754,600 | ZIP (deflate), 1 member | ca1b4b84c98af30d34fa41ca0c6bfa4811c096237978f04d238777dfe9c9469d |
| firmware/SS_2.31F01_Firmware_Update.pkg | 59,437,584 | raw SFUB | d45d1b87757aaac1f87985fd8b1ef9b583248a1dc7da78ac1cc5c13dc58b46b1 |
| firmware/SS_2.34F01_Firmware_Update.pkg | 62,710,288 | raw SFUB | 649e0aea8b9f4acb5b3bfaf0b6eda21c2fe31bc9b66e137e9b7f310a90d0db4e |
| firmware/E3_2.23F02_Display_Update.pkg | 426,042,820 | ZIP (deflate), 1 member | a97fb3714a2306a96c5013a031bad95634d25ff1cedb6b5ae363dfcbde77a0d2 |
| firmware/E3_2.31F01_Display_Update.pkg | 438,288,912 | raw SFUB | 8a4f7f63118900b9d45f068f558c66a51b59e8d1b89f6f8ab46b4d19b68768d7 |
| firmware/E3_2.34F01_Display_Update.pkg | 438,607,376 | raw SFUB | 883419906d10ff57c50a6951b1d38e1f2ddc56fdd13a5ed11773e5db3e1e7024 |

Notes on packaging:

- The two 2.23F02 packages are ZIP archives (deflate) each containing exactly one
  raw SFUB member (e.g. `SS_2.23F02_Firmware_Update`, 52,740,624 bytes). The
  compressed size exceeds the uncompressed size (52,754,450 > 52,740,624), i.e.
  the SFUB content is incompressible — first indication of high-entropy payload.
- The 2.31F01 and 2.34F01 `.pkg` files ARE the raw SFUB container (no wrapper):
  their sha256 equals the parsed SFUB hash.
- `extracted/SS_2.23F02/SS_2.23F02_Firmware_Update` is byte-identical to the ZIP
  member (same sha256 ca1b4b84…), verifying the earlier extraction.

## 1. SFUB header layout (0x000–0x20F, 528 bytes)

Identical layout in all six containers:

| Offset | Size | Type | Observed value / meaning |
|---|---|---|---|
| 0x000 | 16 | char[16] | `"SFUB_update"` NUL-padded magic (exact name; expansion unknown) |
| 0x010 | 16 | char[16] | ASCII version string, NUL-padded: `2.23F02`, `2.31F01`, `2.34F01` |
| 0x020 | 16 | bytes | Unidentified per-file field, unique in every file (see §5) |
| 0x030 | 4 | u32 LE | Product-correlated: `0x00000024` on all three SS files, `0x00000044` on all three E3 files (n=3 each; exact semantics unknown) |
| 0x034 | 4 | u32 LE | Declared payload size in bytes (see §3 for boundary math) |
| 0x038 | 4 | u32 LE | Constant `1` in all six files |
| 0x03C | 452 | bytes | Reserved, all zero in all six files |
| 0x210 | — | — | Payload begins here (see §2) |

Header size 0x210 (528) is itself a multiple of 8 and 16.

## 2. Payload region (offset 0x210)

Payload size and file-end math:

| File | Declared payload size | size mod 8 | size mod 16 | 0x210+size vs EOF | Trailing |
|---|---|---|---|---|---|
| SS 2.23F02 | 52,740,096 (0x324C000) | 0 | 0 | exact | none |
| SS 2.31F01 | 59,437,056 (0x38AF000) | 0 | 0 | exact | none |
| SS 2.34F01 | 62,708,990 (0x3BCDCFE) | 6 | 14 | EOF − 770 | 770 bytes |
| E3 2.23F02 | 425,914,368 (0x1962F000) | 0 | 0 | exact | none |
| E3 2.31F01 | 438,288,384 (0x1A1FC000) | 0 | 0 | exact | none |
| E3 2.34F01 | 438,605,990 (0x1A2498A6) | 6 | 6 | EOF − 858 | 858 bytes |

Payload byte statistics (exact histogram over the full payload, every file):
Shannon entropy 7.999997–8.000000 bits/byte; chi-square vs uniform (df=255)
222.67–269.95, i.e. statistically indistinguishable from uniform random at byte
level. No known compression/archive/filesystem magic at payload start or in a
magic scan (gzip, zlib 0x78, xz, zstd, lz4-frame, bzip2, lzma, lzo, ZIP,
squashfs, UBI tested); `zlib`/`gzip`/`raw-deflate`/`bz2`/`lzma` decompression
attempts on the payload prefix all fail immediately. binwalk on the SS 2.23F02
SFUB (`results/SS_2.23F02_binwalk.txt`) finds only random false-positive JBOOT
STAG patterns. Conclusion: the payload is not a plain compressed stream;
byte-level randomness plus the block structure below indicate encryption.

### 2.1 Evidence for an 8-byte block cipher in ECB mode (2.23F02 / 2.31F01)

Offsets below are payload-relative (file offset = payload offset + 0x210).

1. **Identical ciphertext blocks at identical offsets across different files.**
   All four 2.23F02/2.31F01 payloads (both products, both versions) share the
   16 bytes `a67094665b094a3072bd0fc47621f2cf` at payload+0x10 and the 8 bytes
   `539ab1e748bc7789` at payload+0x38. SS 2.23F02 and SS 2.31F01 additionally
   share `f3c288cb85b65922` at payload+0x00. All matches are 8-byte aligned.
   Blockwise-independent encryption (ECB) maps identical plaintext blocks to
   identical ciphertext blocks; chained/stream modes (CBC/CTR/OFB/ChaCha) cannot
   produce identical blocks at identical offsets after upstream differences
   (payload+0x08 differs between all four files, yet +0x10 matches).
2. **Consecutive identical 8-byte ciphertext blocks (runs).** E.g. in SS 2.31F01
   `805886993a95d9ad` occurs at payload+0x1F04118, +0x1F04120, …, +0x1F04158
   (9 consecutive 8-byte blocks); in E3 2.31F01 `de711335ef40a265` occurs 8
   times consecutively at payload+0xD1D6190. A stream/CTR keystream would have
   to be 8-byte-periodic to produce this — implausible; ECB reproduces it
   naturally from a repeated plaintext 8-byte pattern (e.g. fill bytes).
   Full-file scan: 11 (SS 2.23) / 19 (SS 2.31) / 123 (E3 2.23) / 126 (E3 2.31)
   distinct blocks appear in consecutive runs; random expectation is ~0
   (≈5×10⁻¹¹ for the largest file).
3. **Block size is 8, not 16.** Repeated 8-byte blocks appear at offsets with
   different alignment mod 16 (e.g. SS 2.31F01 `b8e95188775db1d6` at
   payload+0x1D1CF80 (≡0 mod 16) and payload+0x1D1CFD8 (≡8 mod 16)) without the
   enclosing 16-byte blocks being equal — so plaintext repeats at 8-byte
   granularity only.
4. **Identical terminal padding in all four files.** Every 2.23F02/2.31F01
   payload ends with a run of the same 8-byte block `985aecbcb0d9ed8a`:
   216 blocks / 1728 bytes (SS 2.23F02, from payload+0x324B940),
   241 blocks / 1928 bytes (SS 2.31F01, from payload+0x38AE878),
   46 blocks / 368 bytes (E3 2.23F02, from payload+0x1962EE90),
   95 blocks / 760 bytes (E3 2.31F01, from payload+0x1A1FBD08).
   This block occurs nowhere else in any file — consistent with
   E(fill-pattern) under one shared key, padding each image to its declared
   (16-aligned) size.
5. **A second shared constant.** `49b9f8397062e325` appears at 8-aligned
   offsets scattered through all SIX payloads (including both 2.34F01 files):
   9× (SS 2.23), 14× (SS 2.31), 79× (E3 2.23), 110× (E3 2.31), 2× (SS 2.34,
   payload+0x31C0178/+0x3208380), 23× (E3 2.34, first at payload+0x18).
   Random probability of one such hit per file is < 10⁻⁹. Consistent with a
   common plaintext block (e.g. 8 bytes of zero/fill inside structures)
   encrypted under the same key in all files — which would mean the payload
   key is shared across products AND across the 2.23/2.31 → 2.34 format
   change. This specific inference rests on a single 8-byte value and is marked
   **likely, not proven**.

**Not established:** the cipher algorithm. The evidence proves an 8-byte block
cipher in ECB mode (or an equivalent blockwise-independent scheme) for the
2.23F02/2.31F01 payloads, but DES, 3DES, Blowfish, IDEA, etc. cannot be
distinguished from ciphertext alone, and no key material exists in the
container. No algorithm is claimed.

### 2.2 Apparent plaintext-header layout inside the encrypted payload (2.23F02/2.31F01)

Reading the shared/unique ciphertext blocks as ECB images of plaintext blocks,
the first 64 payload bytes behave like a small structured header:

| Payload offset | Block | Behaviour |
|---|---|---|
| 0x00 | 8 B | Same for SS 2.23F02/SS 2.31F01 (`f3c288cb85b65922`); different in E3 2.23F02, E3 2.31F01 and both 2.34F01 |
| 0x08 | 8 B | Unique per file |
| 0x10 | 16 B | Constant across all four 2.23/2.31 files (`a6709466…` + `72bd0fc4…`) |
| 0x20 | 24 B | Unique per file |
| 0x38 | 8 B | Constant across all four 2.23/2.31 files (`539ab1e748bc7789`) |
| 0x40 | … | Diverges entirely |

Interpretation of individual fields would be speculation; recorded here only as
observed block behaviour.

## 3. Trailing/padding data (2.34F01 only)

Both 2.34F01 files carry extra bytes after `0x210 + payload_size`:
770 bytes (SS 2.34F01, file offset 0x3BCDF0E) and 858 bytes (E3 2.34F01, file
offset 0x1A249AB6). Their lengths exactly equal
`(-payload_size) mod 1024`. Thus the physical post-header region is the declared
payload rounded up to a 1 KiB boundary. Older payloads are already 1 KiB-aligned
and need no such padding. This identifies the region length as physical padding,
not evidence of an added authentication segment.

Properties of the padding bytes:

- High entropy (7.74 / 7.81 bits/byte over the region; small sample).
- Not DER/ASN.1 (`openssl asn1parse` rejects the first bytes; no `30 82`
  structure), no PEM/ASCII markers, no known compression magic, and
  zlib/gzip/bz2/lzma/raw-deflate all fail on it.
- Different lengths and content between products. A signature inside some bytes
  is possible but unproven and is not needed to explain the region length.

For 2.23F02/2.31F01 the declared payload size reaches EOF exactly: there is no
container-level signature or MAC trailer at all. Any authenticity check for
those versions must happen inside the encrypted payload (or not at all) —
unverifiable without decryption. The 2.34F01 padding relationship does not
establish package authentication either.

## 4. Format changes across versions

| Aspect | 2.23F02 | 2.31F01 | 2.34F01 |
|---|---|---|---|
| Distribution wrapper | ZIP (deflate) around SFUB | raw SFUB | raw SFUB |
| u32 @0x30 | 0x24 (SS) / 0x44 (E3) | same | same |
| Payload size alignment | 16-aligned | 16-aligned | ≡ 6 mod 8 (both products) |
| Terminal ECB padding run | yes (shared constant) | yes (shared constant) | none |
| Consecutive 8-byte runs | 11 / 123 distinct (SS / E3) | 19 / 126 | 0 / 0 |
| Payload prefix block 0 | `f3c288cb…` (SS pair), per-file E3 | per-file | `9a4d60069633674e` shared by SS+E3 2.34F01 |
| Trailing data after payload | none | none | 1 KiB alignment padding: 770 / 858 bytes |

The 2.34F01 payload still contains the cross-file constant `49b9f8397062e325`
at 8-aligned offsets (§2.1 point 5), but shows no consecutive-block runs, no
terminal padding, and a non-block-aligned declared size. Whether 2.34F01 uses
the same 8-byte-ECB scheme with changed packaging (e.g. partial final block /
ciphertext stealing) or a different transform is **unresolved**; the evidence
does not distinguish these.

## 5. Unidentified header field @0x20 (16 bytes)

Unique per file. Tested and **excluded**: MD5(payload), SHA-1(payload)[:16],
SHA-256(payload)[:16] over the ciphertext payload (values in
`results/sfub-*.json`; all six files, all negative). Remaining candidates: hash
of the *plaintext* payload, a random nonce/IV, or key-check material — none
testable without the payload key. No claim made.

## 6. Extraction feasibility with standard tools (safe, read-only)

- **Outer packaging:** fully extractable — `unzip`/`zipfile` for the 2.23F02
  ZIPs; 2.31F01/2.34F01 `.pkg` need no unwrapping. Verified: extracted SS 2.23F02
  member hash matches.
- **Header:** fully parseable — `tools/sfub_info.py` reproduces every value in
  this document (`python3 tools/sfub_info.py [--json out.json] [--find HEX]…
  <file>`).
- **Payload:** **not extractable** with installed standard tools. Concrete
  blockers: (1) payload is not a recognized compressed/archive format (magic
  scan + decompression attempts all fail); (2) it is encrypted with an
  unidentified 8-byte block cipher in ECB mode whose key is not present in the
  container; the key presumably lives in the on-device updater, which is itself
  inside the encrypted payload (bootstrap problem); (3) no public documentation
  of the `SFUB_update` format was found in the vendor's installation/operation
  manual (026-1803, Appendix G describes the update *procedure* and a
  "legitimacy check" but not the file format) or via web search. Obtaining the
  key would require analyzing a device's updater binary — out of scope here and
  not attempted.

## 7. Security-relevant observations (facts only; no vulnerability claim)

- ECB mode is deterministic and structure-preserving: identical plaintext blocks
  are visible as identical ciphertext blocks across files, products and (likely)
  versions, and blocks can be cut/pasted without detection by the cipher itself.
- The evidence (shared padding constant `985aecbcb0d9ed8a` in four files across
  two products; shared fill constant `49b9f8397062e325` in all six) indicates a
  single payload key shared at least across SS and E3 for 2.23F02/2.31F01.
- No container-level authenticity trailer exists in 2.23F02/2.31F01; 2.34F01
  adds an unidentified 770/858-byte high-entropy trailer.
- These are format observations, not verified vulnerabilities; per project rules
  they stay `unverified` as security findings unless confirmed against device
  behaviour (which is out of scope).

## 8. Limitations

- n=3 per product line, one release each of 2.23F02/2.31F01/2.34F01; field
  semantics inferred from correlation (e.g. u32@0x30 ↔ product) are not proven.
- Cipher algorithm, key, and the 2.34F01 trailer purpose are unknown; nothing
  about the plaintext (filesystems, binaries) could be inspected.
- Chi-square/entropy establish byte-level uniformity, not proof of encryption;
  the encryption conclusion rests on the block-structure evidence in §2.1.
- The "shared key across 2.34" inference rests on one repeated 8-byte value
  (2 hits in SS 2.34F01); treated as likely but not proven.
- `E3_2.31F01_Display_Update.pkg` was confirmed complete before analysis
  (exactly 438,288,912 bytes, no curl process holding it open, sha256 matches
  `firmware/SHA256SUMS`).

## 9. Reproduction

```sh
cd copeland-e3
sha256sum -c firmware/SHA256SUMS
for f in firmware/*.pkg; do
  python3 tools/sfub_info.py \
    --find f3c288cb85b65922 --find a67094665b094a30 --find 72bd0fc47621f2cf \
    --find 539ab1e748bc7789 --find 49b9f8397062e325 --find 985aecbcb0d9ed8a \
    --find 9a4d60069633674e "$f"
done
```

Per-file JSON/txt used for this report are under `results/sfub-*`.
