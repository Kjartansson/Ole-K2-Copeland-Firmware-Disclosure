# E2E system-update ELF recovery and Blowfish analysis

## Outcome

A complete, readable i386 VxWorks system-update ELF was recovered from the
official E2E 4.11F03 package. It is a useful related-code sample, but no
`SFUB`/`SFUB_update` string or E3/Site Supervisor plaintext has been found in it.
It has not decrypted SFUB and is not evidence of an E3/SS access path.

## Complete ELF recovery

The source is `firmware/related/e2e-4-11f03-firmware-update.pkg`, SHA-256
`00561ce8dd860cc87221b70f3aa0cef66c1b1f62d818dfdc45b46ec003ccdf02`.
The earlier `extracted/E2E_4.11F03/SysUpdt.tmp` region ends at package offset
`0x120c5c`, but valid x86 instructions continue unchanged across that boundary.
The ELF header at package offset `0x8a483` declares a larger image, so the old
region is not a complete executable.

The complete ELF was carved directly from the outer package using its ELF section
header table:

- package offset: `0x8a483`
- ELF size: `0x167080` (1,470,592 bytes)
- package end offset: `0x1f1503`
- output: `extracted/E2E_4.11F03/SysUpdt.embedded.elf`
- SHA-256: `2df8e8163518acd97996c709422cdeb6585fa2d1821aa848188a337149d890b0`

`readelf -h -l -S` validates one load segment and six sections: `.text`, `.data`,
`.bss`, `.wrs_build_vars`, and `.shstrtab` plus the null section. The file is a
statically linked, stripped i386 executable with entry point `0x608000`.
`.wrs_build_vars` identifies VxWorks 6.8, `pcPentium2`, and
`C:/code/E2ESoftware/Software/code/sysUpdate/SystemUpdateImage`.
Ghidra 12.2 imported and analyzed it successfully in `ghidra/CopelandE3.gpr`;
the log is `results/ghidra-e2e-sysupdt.log`.

## Update and crypto code

The ELF contains the E2E system-update task and `CpcPackage` parser strings,
including `/ata00:2/SysUpdt.bin`, `/ata00:2/SysUpdt.tmp`, and
`/ata00:2/e2_fw.pkg`. Their presence establishes that this is related update
code, not that it supports the later SFUB container.

The data-protection routines are standard Blowfish:

- `0x655c90`: Blowfish F function, four 256-entry S-boxes.
- `0x655ce0`: 16-round encryption with 18 P-array words.
- `0x655d50`: corresponding decryption routine.
- `0x655db0`: cyclic-key Blowfish expansion and P/S initialization.
- `0x6561b0`: encrypts 8-byte blocks and renders each as 16 hexadecimal chars.
- `0x656000`: parses the hexadecimal form and decrypts.
- Initial constants are at file offsets `0x134fc0` (S-boxes) and `0x135fc0`
  (P-array), matching the published Blowfish constants.

At `0x6563cf`, the code references exactly 16 bytes at virtual address
`0x74837c` (file offset `0x1403dc`): `kb?A68D+tl?2@KL_`.
The routine concatenates another string with this value using `%s%s` before key
setup. It is therefore evidence of a salt/input to this E2E mechanism, not a
stand-alone SFUB key.

### Signed-key-byte implementation detail

At `0x655e16`, key bytes are loaded with `movsx`, not `movzx`, during the
four-byte key-word assembly. For a high-bit byte in the fourth position of a
32-bit key word, this produces a different expanded key from standard Blowfish.
High-bit bytes in earlier positions are shifted out and have no effect. ASCII
keys are unaffected. This variant was absent from the earlier standard-cipher
sweeps and is now tested separately.

`tools/sfub_blowfish_signed.py` extracts the constants from the ELF and
implements both block endian conventions and both primitive directions. Its
mandatory checks cover the published zero-key vector, signed roundtrips,
unsigned cross-checks against the existing validated backend, equality with
standard Blowfish for the recovered ASCII salt, and divergence for a high-bit
byte at key position 3 mod 4.

## Bounded SFUB tests

- `tools/sfub_related_binary_probe.py`: 4,535 unique strings from the complete
  updater generated 173,211 candidates across the existing DES/3DES/Blowfish/
  CAST5/IDEA derivations. Both directions over seven documented SFUB targets
  produced 2,424,954 block operations and zero hits
  (`results/related-binary-probe.json`). Raw variable-length Blowfish keys are
  included; this is not limited to fixed 16-byte keys.
- Signed-byte Blowfish, header/hash candidates: 201 keys whose derivations
  contain high-bit bytes, both directions and big/little-endian block words,
  5,628 block operations, zero hits
  (`results/blowfish-signed-header-probe.json`).
- Signed-byte Blowfish, updater-derived candidates: 13,168 keys with a high-bit
  byte at a schedule-affecting position, both directions and block endian
  conventions, 368,704 block operations, zero hits
  (`results/blowfish-signed-related-probe.json`).

A hit would still require multi-block and multi-file plaintext validation before
any decrypted output or access claim. No such hit has occurred.

## PlayStation-tool review

The user-supplied PS5 SELF-to-ELF, self-patcher, and PS2 unpacker repositories
were cloned and inspected statically under `tools/third-party/ps-reference/`;
nothing was executed or built. Sony SELF uses different containers and keyed
AES-CTR/CBC constructions, while the PS2 unpacker targets MIPS R5900. None
matches this i386 VxWorks ELF or SFUB's 8-byte ECB structure. Only the general
PS2 technique of emulating an available unpacker, tracking written memory, and
dumping the result is transferable as a future method; it requires a runnable
E3/SS updater and does not supply one.

## Crunch codec assessment

The ELF contains a `Crunch` codec at `0x649920`/`0x6499f0`, with magic
`0x5aa5a55a`. Project-local Unicorn and an independent QEMU i386 harness were
used for bounded function-level analysis. A synthesized compressor/decompressor
roundtrip failed under both engines. An earlier attempt to concatenate
independent embedded streams produced invalid large outputs, not plaintext;
those artifacts and logs are quarantined under `results/failed-crunch/`.
`tools/e2e_crunch_unpack.py` is now restricted to one explicitly selected stream
per run. No Crunch-derived plaintext is claimed or used for SFUB analysis.

## Next evidence needed

The E2E code confirms vendor use of Blowfish and supplies a new implementation
variant to test, but it does not supply an SFUB key or decryptor. Direct SFUB
progress still requires an E3/SS updater/rootfs, an exact plaintext component
for ECB pattern matching, or new key-derivation evidence tied to SFUB.
