# Site Supervisor firmware 2.31F01

- Source: official Copeland Site Supervisor product page; exact URL in `SOURCES.md`
- Original: `firmware/SS_2.31F01_Firmware_Update.pkg`
- Size: 59,437,584 bytes
- SHA-256: `d45d1b87757aaac1f87985fd8b1ef9b583248a1dc7da78ac1cc5c13dc58b46b1`
- Role: vendor security-fix release for the nine published E3/SS CVEs

## Inventory

The original is a direct `SFUB_update` container. Its payload is opaque to
standard filesystem/archive identification; no rootfs or application binaries
have been extracted.

## Security review status

Container analysis: see `analysis/CONTAINER-FORMAT.md`. The vendor documents the
nine CVE fixes, but independent code-level fix confirmation is blocked pending
decrypted application/rootfs content or an authorized device image. No dynamic
result or new vulnerability is claimed.
