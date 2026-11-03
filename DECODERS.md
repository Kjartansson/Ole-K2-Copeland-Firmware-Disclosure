# Copeland / Dixell decoder guide

Use these tools only on firmware you own or are authorized to analyze. They run
locally and do not contact a controller. XWEB Pro OpenSSL payloads and E3/Site
Supervisor SFUB payloads are **not** covered by the EVO/XWEB500 decoders.

## 1. XWEB EVO `.epkg` decoder

Tool: `tools/xweb_epkg_decrypt.py`

### Algorithm

1. Start with 20 bytes of `0xa1`.
2. Take the input filename without the final `.epkg` suffix, in ASCII.
3. XOR up to the first 20 package-name bytes into that buffer.
4. Use the resulting 20 bytes as a repeating XOR key over the whole file.

Short names such as `EVOExt-5.6.0-boot` leave the remaining bytes as `0xa1`.
Package names are case-sensitive and must match exactly. The recovered native
`xwcrypt` utility hashes the entire input path string, not just the basename.
Run it from the package directory with basename-only input. A full-path call
produces a different key and fails validation. This was verified against EVO
4.3.0: native `xwcrypt` and this Python decoder then produced byte-identical
output with SHA-256 `eab86acfbcf31fddd4d96f85f752bbfcee48ee2ca12107b0227d6530f9db2f1a`.

Example for `EVOPackage-5.8.8.STANDARD.24-25902d`:

```text
e4 f7 ee f1 c0 c2 ca c0 c6 c4 8c 94 8f 99 8f 99 8f f2 f5 e0
```

### Usage

```bash
python3 tools/xweb_epkg_decrypt.py INPUT.epkg OUTPUT.decoded \
  --json results/decode-result.json
```

The tool rejects output that does not start with either `#!/bin/sh` or little-
endian SquashFS magic `hsqs`. Shell packages must also contain an embedded gzip
stream. JSON output records the key, container type, size, and SHA-256.

Example using the latest EVO release:

```bash
python3 tools/xweb_epkg_decrypt.py \
  extracted/XWEB_EVO_5.8.8_ARM/EVOPackage-5.8.8.STANDARD.24-25902d.epkg \
  build/EVOPackage-5.8.8.decoded \
  --json results/evo-5.8.8-decode.json
```

Expected container: `shell`. This result was also compared byte-for-byte with
the independently recovered 5.8.8 plaintext.

### Unpack the next layers

For a shell installer containing a SquashFS image:

```bash
unsquashfs -f -no-xattrs -d extracted/EVOPackage_5.8.8_SquashFS \
  extracted/EVOPackage-5.8.8.package/update.evo
```

For an installer with an embedded gzip payload, first locate the gzip offset,
decompress it, and validate the tar/cpio framing. Then extract `update.evo` as
above. The final `EVOPackage.tar` expands into the application/package tree.
Archive paths and links should be validated before extraction; do not extract
untrusted archives as root.

## 2. XWEB500 `.xw5` / `.xwb` decoder and UF extractor

Tools: `tools/xweb_epkg_decrypt.py` is **not** used for this generation. Use a
single-byte XOR of `0xa7`, then gzip decompression, then
`tools/xweb500_uf_extract.py`.

### Algorithm

1. XOR every payload byte with `0xa7`.
2. Require a gzip stream and decompress it.
3. Parse `GETFILE|/absolute/path|decimal_size|` records. Each record ends with
   an additional newline followed by `EFI300IFE300!\n`.
4. Write each record under a safe output directory after stripping the leading
   slash and rejecting absolute/parent-traversal paths.

### Usage

```bash
python3 - <<'PY'
from pathlib import Path
import gzip
source = Path('extracted/XWEB500_v11/03_application-V110-2007-01-23.xw5')
ciphertext = source.read_bytes()
decoded = gzip.decompress(bytes(byte ^ 0xa7 for byte in ciphertext))
Path('build/application-v110.uf').write_bytes(decoded)
print(len(decoded), decoded[:16])
PY

python3 tools/xweb500_uf_extract.py \
  build/application-v110.uf \
  extracted/XWEB500_v11_application \
  --json results/xweb500-v110-files.json
```

Expected archive prefix: `XWEB500UF`. The 2007 v1.1 payloads also include
`XWEB300UF` for the updater. All six supplied payloads decoded successfully and
produced 1,801 files in total.

The user database contains MD5(`Admin`) and MD5(`admin`). The CGI code also
contains unauthenticated file-write/delete handlers matching CVE-2021-45420.
See `poc/PoC5_XWEB500_legacy_file_write.md` before any security testing.

## 3. XWEB2009 and EVO XOR packages

Existing tools for older XWEB2009 RPMs and EVO x86/XML packages are:

```bash
python3 tools/xweb2009_xor_extract.py INPUT.zip OUTPUT_DIRECTORY
python3 tools/xweb_evo_xor_extract.py INPUT.zip OUTPUT_DIRECTORY
```

The XWEB2009 tool accepts both plaintext RPMs and RPMs protected by the
recovered repeating-XOR scheme. It detects plaintext before applying a key,
requires a complete gzip stream, and validates every `newc` cpio header, entry,
and pathname through `TRAILER!!!`. XML validation belongs to the separate EVO
x86 decoder, not the XWEB2009 tool.

The EVO x86 decoder derives the XOR key from each RPM package name, accepts xz
or gzip payloads, and writes a separate cpio for every RPM. This preserves both
EVO and FCEVO payloads in combined archives. XWEB3000/5000 EVO 5.8.7 validates
as 27,728,828-byte EVO and 21,233,756-byte FCEVO cpio outputs.

New reference validations:

- XWEB3000/5000 4.0.18: plaintext RPM, 864 cpio entries.
- XWEB3000/5000 4.0.19: plaintext RPM, five cpio entries. Both recovered
  binaries match independent `rpm2cpio` extraction byte-for-byte.
- XWEB3000/5000 4.0.12: all 16 bundled RPMs decoded successfully, including
  plaintext versions where the recovered XOR key is not applicable.
- A synthetic XOR round trip verifies that the recovered-key path still
  reproduces the original RPM.

These are separate from the generalized EVO `.epkg` decoder.

## 4. Validation requirements

Do not claim successful decryption based only on a short magic prefix. Use:

- Full gzip decompression for compressed payloads.
- Valid SquashFS and tar/cpio structure for nested packages.
- Expected executable, script, XML, or RPM structure for recovered files.
- SHA-256 comparisons against independently recovered plaintext where possible.
- Complete-stream failure handling for any candidate that looks valid initially.

Current reference validations:

- EVO 5.2.3 and 5.8.8 outputs match previous plaintext byte-for-byte.
- EVO 5.8.7 expands to a 1,452-member package tree.
- EVO 3.0.8, 4.0.3, and 4.3.0 expand to 1,745, 1,799, and 1,832 members.
- XWEB500 v1.1 expands to 1,801 files across six payloads.

## 5. Out of scope

- XWEB Pro `Salted__` payloads: use `tools/xweb_openssl_probe.py` or the fused
  SHA-256/AES-256-CBC implementation `tools/xweb_openssl_fused.py` and `.cl`.
  The CPU probe accepts `--target PATH` and optionally `--words PATH` or
  `--expanded`, and records results with `--json PATH`. The fused probe accepts
  `--target` and `--words` directly. August 1.15.1 probes on all three models'
  `manifest` and `libraries` files returned no hit; this is not decryption.
  Newly acquired XWEB5000 PRO x86 1.1.2 and xw5000 1.3.0 packages retain the
  same six-file encrypted structure; all signatures verify, but neither contains
  a bootable rootfs or updater. Bounded probes on all four components returned
  no hit.
- E3/Site Supervisor SFUB payloads: the EVO decoder is unrelated. The separate
  E3 permuted-key test is `tools/e3_permuted_blowfish_probe.py`.
- Select 8.47.1: a Windows MSI application, not a controller-firmware target.

No current Pro or E3/SS plaintext is claimed by this guide.
