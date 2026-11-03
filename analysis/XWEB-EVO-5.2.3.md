# XWEB EVO 5.2.3 and legacy password/update recovery

- Source URLs:
  - https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/XWEB30005000-EVO/XWEB_EVO_5.2.3.STANDARD.5-bbfd5b_3000_5000.zip
  - https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/XWEB-300D-500D-500-EVO/XWEB_EVO_5.2.3.STANDARD.5-bbfd5b_300D_500D_500.zip
  - https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/XWEB3000-XWEB5000/XWEB3000v32.zip
- Release dates: EVO files dated 2018-07-05; legacy 3.2 installer version dated 2007-04-17
- SHA256:
  - EVO x86: `030b8abe282f622efcd4171dd4c85183870bbbbac756cf3107517a90bd633ada`
  - EVO ARM: `98c9e143ed08c2e251a21f6090f124c31eadf13b48bd6df75891c789d889e5b4`
  - Legacy 3.2: `b6551bf0752a25d0f625ef9ffc6e3fecadd3463f191467b9dd12131c01647c86`
- Package formats: ZIP with XOR-obfuscated RPM/xz-cpio, XML descriptors, shell/SquashFS/cpio layers, and partially validated older `.epkg` payloads

## Inventory

- `extracted/XWEB_EVO_5.2.3_3000_5000/`: decrypted 9,863,133-byte i686 RPM and 30,761,932-byte cpio.
- `extracted/XWEB_EVO_5.2.3_rootfs/`: 881 EVO filesystem entries, including the unstripped i386 `xwpasswd`, `xupdate`, OpenSSL, Lua, and web application.
- `extracted/XWEB3000V32/`: statically extracted 3.2 Inno Setup installer and its RPMs.
- `extracted/XWEB3000V32_components/`: original `xjpasswd` and `xjsyswrap` builds.
- `extracted/XWEB_EVO_5.2.3_ARM/`: decrypted shell installer, gzip cpio, and XML manifest.
- `extracted/XWEB_EVO_5.2.3_ARM_package/`: recovered ARM updater and application code, including `new_install_epkg.sh` and `new_xwrpm.cgi`.
- `extracted/XWEB_EVO_5.8.8_ARM/`: 2024 shell installer and 18,534,400-byte cpio recovered with a two-byte key variant.
- `extracted/XWEB500_DIN_update_2011/`: 2011 script, kernel, and 161,105,920-byte filesystem cpio recovered after ZipCrypto and single-byte XOR processing.

## Key findings (severity: critical for legacy confidentiality; info for current products)

1. Official EVO x86 and legacy XWEB packages provide real application code without a device.
2. The daily-password algorithm is fully recovered and independently implemented.
3. XML update descriptors and the legacy `preinstallf9.sh` are recoverable with repeating XOR keys.
4. ARM EVO 5.2.3 and 5.8.8 packages and the 2011 XWEB500 system were also decrypted; XWEB Pro remains unresolved.

## Details per finding

### EVO RPM and XML recovery

The EVO x86 RPM uses this repeating 20-byte XOR key:

`e4 f7 ee f1 c0 c2 ca c0 c6 c4 8c 94 8f 93 8f 92 8f f2 f5 e0`

`tools/xweb_evo_xor_extract.py` validates the complete xz stream and cpio magic.
The x86 and ARM XML descriptors are recovered independently by deriving a
20-byte key from the standard XML declaration. Their plaintext manifests are:

- `extracted/XWEB_EVO_5.2.3_3000_5000/evopack.decrypted.xml`
- `extracted/XWEB_EVO_5.2.3_ARM/epkginfo.decrypted.xml`

The manifests describe package names, versions, sizes, and install actions; they
do not contain the payload decryption key.

### Daily-password algorithm

`extracted/XWEB_EVO_5.2.3_rootfs/opt/xweb/bin/tools/xwpasswd` is unstripped and
contains `GetMAC` and `MakeModbusCrc`. Static disassembly and qemu-i386 debugger
traces established:

- Four date bytes selected by day/month/year parity.
- CRC-16 with initial value `0xffff`, right shifts masked to 16 bits, and
  polynomial `0xa001` optionally XORed with the three little-endian MAC pairs.
- Six output characters derived from CRC nibbles, with the second character
  capped at `7` when its nibble exceeds nine.

`tools/xweb_evo_password.py` implements the algorithm. Eight explicit-`-w`
no-MAC vectors match the real binary: `C1BOF0`, `K5FSO9`, `D6GSG1`, `D4EKH2`,
`L3DJN8`, `C7LKT2`, `F7KFN8`, and `C7KFS2`. The original 2006 `xjpasswd` also
matches the EVO no-MAC result, confirming lineage.

Current-date mode uses `year - 100`, unlike explicit `-w` mode's full year byte;
`--today` now preserves that distinction. On 2026-10-30 with supplied MAC
`00:11:22:33:44:55`, both the 4.3.0 and 5.8.8 binaries returned `O0ANI3` under
QEMU, matching the Python model. The earlier `J0ARL6` value belongs to the
explicit-full-year model and is not a current-date binary vector.

The recovered `etc/cron.daily/chp` sets the Unix root password to
`xwebdix` plus the six-character daily code. The web `Administrator` account
instead compares against the unprefixed daily code in the recovered Lua
authentication path. EVO 5.8.8 also exposes the MAC through `sysinfo.lua` and
accepts the daily code to start SSH through `api.lua`; see
`poc/PoC12_XWEB_EVO_5.8.8_ssh_root_chain.md`. The derivations and isolated API
behavior are validated, but successful login to every EVO version or physical
device is not claimed.

### Generalized EVO package decoding and legacy authentication

The recovered 4.3.0 `xwrpm.cgi` establishes the complete `.epkg` key rule:
initialize 20 bytes to `0xa1`, XOR up to 20 package-name bytes into them, and
repeat the resulting key. `tools/xweb_epkg_decrypt.py` implements this directly.
All previously unresolved payloads were validated: 3.0.8 and 4.0.3 are genuine
SquashFS images; all three 4.3.0 components are shell installers with embedded
payloads. Their unpacked package trees contain 1,745, 1,799, and 1,832 members
under `extracted/EVOPackage_3.0.8_package`,
`extracted/EVOPackage_4.0.3_package`, and
`extracted/EVOPackage_4.3.0_package`. The 4.3.0 `xwpasswd`, `xwcrypt`, `xupdate`,
`upload.cgi`, `utility.lua`, and `api.lua` are byte-identical to the files
downloaded from the owned test unit. Direct decoder tests on 5.2.3 and latest
5.8.8 reproduce the previous plaintext byte-for-byte. An independent 5.8.7
download also decodes into a valid shell/gzip/tar/SquashFS chain and a
1,452-member package tree (`results/evo-5.8.7-decode.json`).

The 3.0.8, 4.0.3, and 4.3.0 `xwmanager.lua` files also accept a hardcoded MD5
`df862c19e0bb172846e8853d7bca54a3` directly as `upass` for `Administrator`.
This is a pass-the-hash authentication bypass; plaintext recovery is unnecessary.
The value is absent from the recovered 5.2.3 and 5.8.8 authentication code. See
`poc/PoC4_XWEB_EVO_legacy_pass_the_hash.md`.

### Legacy preinstall recovery

`extracted/XWEB2009_upload-4.0.19/preinstallf9.decrypted.sh` was recovered with
key `d1 d3 c4 c8 cf d2 d5 c0 cd cd c7 98 8f d2 c9 a1 a1 a1 a1 a1`.
The decrypted script is 99.75% printable and contains the complete package
sequence, download preparation, and RPM signature checks.

### XWEB Pro comparison and Windows tools

`extracted/XWEB_PRO_xwcoolmate_1.15.1/` has different wrapped-key blobs,
signatures, and salts from xw5000, xw500d, and x86 samples. No direct key reuse
was observed.

LIB Builder and WIZMATE were statically unpacked, including UPX decompression.
Their code handles device libraries and application/database functions; no
XWEB Pro `Salted__` update decryptor was found. The supplied WIZMATE
`Driver_ProgTool_2022.03.zip` contains a Prolific USB-serial driver, not an
updater.

All recovered legacy/EVO key families and password-derived candidates were
tested against four XWEB Pro rootfs/data payloads using seven OpenSSL
cipher/KDF combinations: 448 first-block operations and zero hits
(`results/xweb-evo-derived-probe.json`).

## Known-CVE regression notes

The E3/SS Frostbyte10 and XWEB Pro 2026 CVEs are separate product/version
families. No current CVE is claimed as reproduced by this legacy analysis.

## Notes / limitations

- Official-package analysis used no third-party live device. Separately, an
  explicitly owned EVO 4.3.0 test site was inspected read-only and its session
  was closed normally; see the sanitized `poc/PoC3_XWEB_EVO_readonly_access.md`.
- EVO 3.0.8, 4.0.3, 4.3.0, 5.2.3, and 5.8.8 payloads are decoded and their
  package trees validated. The 5.8.8 full update CGI still needs base-system
  libraries not included in the patch.
- XWEB Pro remains encrypted. The EVO/legacy password algorithm is an
  authentication-recovery result, not an update-decryption result for Pro.
- The full XWEB Pro access chain still requires an owned Pro image/device or a
  plaintext updater recovered from another artifact.

## Responsible disclosure status

No new submission has been made. All artifacts are official public Copeland
packages analyzed offline.
