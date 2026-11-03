# Copeland E3 / Site Supervisor research status

## Bottom line

No validated SFUB or XWEB Pro plaintext, current-product exploit, or new zero-day
has been established. Legacy XWEB2009 and XWEB EVO plaintext application/update
code was recovered separately; see `analysis/XWEB2009_4.0.19.md` and
`analysis/XWEB-EVO-5.2.3.md`. All original six E3/SS packages and both extracted
inner SFUB files pass their recorded SHA-256 checks. No original under
`firmware/` was modified.

Newer addendum: the E3 updater's separate 56-byte permuted Blowfish key was
recovered and emulation-validated, but produced zero SFUB hits over 58,700 block
operations. A fused OpenSSL SHA-256/AES-256-CBC OpenCL probe now passes OpenSSL
and CPU known-answer tests; recovered/transformed and Rockyou sweeps produced
103,908,282 operations across six Pro components with zero validated hits. All
five primary Pro RSA `key` blobs rejected public recovery. The generalized EVO
name/0xa1 rule recovered full 3.0.8, 4.0.3, and 4.3.0 package trees. Authorized
read-only validation of EVO 4.3.0 confirmed directory/file downloads and
factory-admin access; the administrative session was closed normally. The 3.0.8–4.3.0 code also has a hardcoded pass-the-hash
`Administrator` bypass, absent from 5.2.3/5.8.8. See
the sanitized `poc/PoC3_XWEB_EVO_readonly_access.md` and
`poc/PoC4_XWEB_EVO_legacy_pass_the_hash.md`.

## Verified technical findings

- SFUB exhibits deterministic, equality-preserving behavior at aligned 8-byte
  granularity. Conventional 16-byte ECB is strongly excluded and ordinary
  nonperiodic stream/CTR operation is strongly disfavored; periodic bytewise
  and otherwise equivalent transforms remain possible.
- SS 2.30F02 and 2.31F01 share 1,023,793 aligned ciphertext blocks (8,190,344 B),
  including 7,771,904 B at payload+0x1F7E0. This is identical encrypted content,
  not known plaintext.
- A complete related E2E i386 VxWorks updater was recovered:
  `extracted/E2E_4.11F03/SysUpdt.embedded.elf`, SHA-256
  `2df8e8163518acd97996c709422cdeb6585fa2d1821aa848188a337149d890b0`.
  Ghidra imported and analyzed it successfully. It contains standard Blowfish and
  a signed-key-byte expansion detail, but no SFUB handler or key.
- A second updater, `extracted/E2_4.11F02/SysUpdt.embedded.elf`, is explicitly
  built from `C:/code/E3sysUpdate/SystemUpdateImage`. Its `$tI...` salt produced
  no SFUB hit. The fleet-wide XWEB Pro RSA-4096/SHA-512 public key verifies all
  24 available signatures, including the earliest 1.3.0 package.
- `tools/e2e_blowfish_schedule_validate.py` confirms the signed model against
  emulated E2E ground truth for ASCII, high-bit, and binary keys.
- XWEB uses OpenSSL `Salted__`, a different container from SFUB. All 27 checked
  component salts are unique, so no cross-version salt reuse was found.
- Copeland's official security-resources page lists CVEs and mitigations, not
  exploit kits. Published E3/XWEB vulnerabilities are not reproduced by this work.

## Validated negative results

All listed sweeps returned zero validated hits:

- Factory/default, expanded dictionary, endian, GOST/Skipjack/XXTEA, RC2/RC5/
  TEA/XTEA, DES/3DES/Blowfish/CAST5/IDEA, and raw-constant probes.
- Header-derived, wrapped-header, payload-boundary, arbitrary-length, and
  recovered E2E salt-composition keys.
- E2E-derived XWEB keys: 5,268 candidates over five components, 184,380 operations.
- OpenSSL `EVP_BytesToKey` with header salts and 16/32-byte Blowfish, DES, and
  3DES plus MD5/SHA-1/SHA-256/SHA-512/RIPEMD-160: 51,626,400 block operations.
- PBKDF2-HMAC-SHA256 with all 35 salt/package combinations: 10,325,280 block
  operations per iteration-count run. Counts 1, 1,000, 10,000, and 100,000 all
  returned zero hits. The final 100,000-count run tested 5,268 passwords in
  6,615.143 seconds; evidence is `results/pbkdf2-100000-probe.json`.
- Raw GOST/Magma and Skipjack: 20,105,022 block operations.
- DES seed spaces: lowercase hex, uppercase hex, raw-space, raw-SFUB, raw-zero,
  and decimal. Each binary/hex variant covered 4,294,967,296 seeds; decimal
  covered 111,111,110. All exhausted with zero hits.

Reproduction details and exact counts are in `analysis/CRYPTANALYSIS.md`,
`analysis/E2E-UPDATER.md`, and the machine-readable files under `results/`.

## Pattern and emulation evidence

- `tools/sfub_ecb_pattern_match.cpp` passes repeat-rich and sparse exact-recovery
  tests. Complete E2E updater and all 32 updater/BootROM 64-KiB segments produced
  no exact match in SS 2.30F02 or E3 2.31F01.
- Blowfish P-array/S-boxes and the E2E CRC16 table produced no exact match.
- CpcPackage matches with only one repeated block were rejected as weak
  collisions. The subsequent four-repeat check found zero exact matches in all
  32 alignments.
- An earlier attempt to concatenate independent `Crunch` streams produced invalid
  large outputs. Those artifacts are quarantined under `results/failed-crunch/`
  and are not plaintext evidence. A synthesized compressor/decompressor
  roundtrip also failed under Unicorn and QEMU i386.

## E2E validation-order analysis

The E2E package path performs length checks, CRC16, payload read, payload CRC16,
element-table parsing, per-element CRC16, and finally type-2 Crunch decompression
and platform/type checks. No package authentication or decryption was found; the
integrity value is attacker-computable CRC16. Crunch therefore processes fully
attacker-controlled input without a cryptographic gate. Reachable test surfaces
include declared output-size allocation and nested-package recursion, but no
memory-safety vulnerability is proven and these are not E3/SS findings.

## Final completion checks

All planned probes have finished; no background workers remain. In addition to
the results above, PBKDF2-HMAC-SHA1/SHA512/RIPEMD-160 at 10,000 returned zero
SFUB hits, and XWEB PBKDF2-HMAC-SHA1/SHA512/RIPEMD-160 at both 1,000 and 10,000
returned zero hits. OpenSSL DES table matching found zero exact matches in all
32 alignments.

The final public-artifact checks found no E3/SS updater or plaintext image.
Wayback returned no indexed files on `fcmresources.copeland.com`; the older
advisory QR code is only a product-page link. Details and one inconclusive
archive query (answer 5381, repeated HTTP 503) are recorded in
`analysis/UPDATER-ACQUISITION-REVIEW.md`.

`python3 tools/summarize_results.py` read 281 JSON result files and reported
`validated_hit_records=0`. `sha256sum -c firmware/SHA256SUMS` and
`sha256sum -c results/inner-sfub-SHA256SUMS` passed for all recorded files.

## Exact next artifacts required

The realistic decryption path now requires one of:

1. An actual E3/Site Supervisor updater, rootfs, or authorized device image.
2. A lawful vendor update emulator or a plaintext updater/component pair.
3. An exact known plaintext component large enough for strong ECB pattern
  matching, ideally the component in the 7.41 MiB SS 2.30/2.31 shared region.

Copeland support/portal distribution is the remaining identified legitimate
source for those artifacts. Public searches found no indexed E3/SS updater,
rootfs, emulator, or SFUB decryptor.
