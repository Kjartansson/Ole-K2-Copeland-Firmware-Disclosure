# Site Supervisor firmware 2.23F02

- Source: official Copeland Site Supervisor product page; exact URL in `SOURCES.md`
- Original: `firmware/SS_2.23F02_Firmware_Update.pkg`
- Size: 52,754,600 bytes
- SHA-256: `39f64ba8a9d2ca753bea71f10b857c406e8e4d376c6540c896f8e74ee392ded3`
- Role: pre-2.31 security baseline

## Inventory

The ZIP outer package contains one 52,740,624-byte `SFUB_update` file. Its
SHA-256 is `ca1b4b84c98af30d34fa41ca0c6bfa4811c096237978f04d238777dfe9c9469d`.
The inner payload is opaque to standard filesystem/archive identification.

## Security review status

Container analysis: see `analysis/CONTAINER-FORMAT.md`. Credential, API,
service, native-code, and known-CVE code-path checks are blocked pending
decrypted application/rootfs content or an authorized device image. No dynamic
result or new vulnerability is claimed.
