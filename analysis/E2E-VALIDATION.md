# E2E CpcPackage validation order and attack surface

## Verified package behavior

The E2E 4.11F03 updater at `extracted/E2E_4.11F03/SysUpdt.embedded.elf` uses this
validation sequence:

1. Read a 32-bit payload length (`0x62ca4d`) and 16-bit CRC (`0x62c9da`).
2. Enforce `length <= 0xFFFFF` at `0x62c963`, then allocate the payload buffer.
3. Read the payload and check for short reads.
4. Verify payload CRC16, if enabled (`0x62c8ba`).
5. Parse the element table.
6. Verify per-element CRC16, if enabled (`0x62e5b0`).
7. For type-2 elements, run the Crunch decoder (`0x630140` -> `0x6475c0` ->
   `0x6470c0` -> virtual decode at `0x64715e`).
8. Run platform/type validation and recurse for type-3 embedded packages.

The entry at `fcn.006246d0` enables CRC and element validation, then calls the
validator at `0x624883` and aborts on failure.

## Integrity and cryptography

No package authentication or package decryption was found. CRC16 is the only
integrity control, and an attacker can recompute it. No signature, MAC, or keyed
hash is present in this path. The Blowfish code in the `0x655xxx` range is a
separate data-protection module and is not called by CpcPackage/Crunch.
Therefore, the Crunch decoder processes fully attacker-controlled input without
a cryptographic gate.

## Reachable test surfaces, not proven vulnerabilities

- `fcn.00649790` checks the Crunch magic `0x5aa5a55a` and returns the 32-bit
  value at blob+4. `fcn.006470c0` allocates `value+1` at `0x647130` with no
  visible upper bound before decoding. This is a resource-exhaustion/decompression
  bomb surface, not a demonstrated memory corruption.
- Type-3 elements recursively invoke package validation at `0x62e6ef` and
  `0x62e020`/`0x628e10`. No nesting-depth limit was observed in the reviewed
  disassembly.
- `0x62c963` enforces a separate 1 MiB input-payload cap before allocation and
  short-read checks are present. These are correct defensive checks and do not
  bound the decompressed-size allocation described above.
- Type-2 decompression happens during validation, so any decoder memory-safety
  defect would be reachable by a crafted package. No such defect has been shown.

These findings apply to the related E2E updater only. They do not establish an
E3/Site Supervisor vulnerability, an SFUB decryption path, or a new zero-day.
Further work would need to validate a concrete impact in an isolated emulator or
on an authorized test device, without using production systems.
