# XWEB3000/5000 EVO 5.8.7 i686 access-chain validation

## Result

The EVO daily-code Administrator command-injection chain transfers to the
large-controller i686 release. The genuine 5.8.7 Lighttpd/Lua service returned
the documentation MAC, accepted the derived Administrator code, executed an
injected command, returned real `uid=0(root)` output, and removed the canary.
The complete loopback HTTP sequence passed on 2026-10-30.

This expands the model/architecture coverage of the existing EVO finding. It is
not a new vulnerability class or a physical-device result.

## Official artifact and extraction

- Catalog: https://webapps.copeland.com/Dixell/Pages/XWEB3000_5000_EVO
- Package: https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/XWEB30005000-EVO/XWEB_EVO_5.8.7.STANDARD.23-f27c2a_3000_5000_LIB20240201.zip
- Original: `firmware/related/XWEB_EVO_5.8.7.STANDARD.23-f27c2a_3000_5000_LIB20240201.zip`
- ZIP SHA-256: `a81bd563ed18028a4857050f7cfaa58e5e8582a7b3bafc06c7958f3cc8f3fb42`
- EVO payload: `EVOPackage-5.8.7.STANDARD.23-f27c2a.i686.rpm`, 10,800,876 bytes
- Decoded EVO cpio: 27,728,828 bytes; decoded FCEVO cpio: 21,233,756 bytes
- Rootfs: `extracted/XWEB_EVO_5.8.7_3000_5000_rootfs`

`tools/xweb_evo_xor_extract.py` now derives the repeating XOR key from each RPM
package name, supports both xz and gzip payloads, and preserves separate EVO and
FCEVO cpio outputs. No installer was executed and the original ZIP was not
modified.

## Static transfer evidence

- `opt/xweb/www/cgi-bin/sysinfo.lua` and `etc/cron.daily/chp` are byte-identical
  to the ARM 5.8.8 copies.
- Public `sysinfo.lua:60-68,102-117` supplies MAC, release, timestamp, and
  timezone.
- `api.lua:311-312` accepts the daily code for Administrator authentication;
  `api.lua:345-383` uses it for SSH start/stop.
- `api.lua:1857-1867` concatenates unescaped `server_username` into a Curl shell
  command.
- `etc/cron.daily/chp:3-6` sets the root password to `xwebdix` plus the daily
  code.
- The 5.8.7/5.8.8 API diff is preserved at
  `build/evo-5.8.7-5.8.8-api.diff`; it does not alter these paths.

The genuine i686 `xwpasswd` ran under QEMU and matched the Python model:
2026-10-30 explicit-year no-MAC `D1BOG1`, 2026-10-26 `C1BOF0`, and
2000-01-01 `D8IKO9`. Current-date mode with documentation MAC
`00:11:22:33:44:55` derives `O0ANI3`.

## Actual HTTP validation

The isolated lab used the recovered i686 Lighttpd 1.4.55, Lua scripts and
modules under QEMU/bubblewrap on `127.0.0.1:18082`. Debian i386 Lua/BusyBox
compatibility files were added only to the derived `build/evo-x86-rootfs`.
The network address and MAC were synthetic, the daily-code executable was
substituted with the independently derived value, and Curl was stubbed after
command construction. No external device or vendor update server was contacted.

`results/evo-x86-5.8.7-sysinfo.json` identifies release
`5.8.7.STANDARD.23--f27c2a` and MAC `001122334455`.
`tools/xweb_evo_rce.py` then completed authentication, injection, proof download,
and cleanup. Its result is `results/evo-x86-5.8.7-rce-validation.json`:

```text
uid=0(root) gid=0(root) groups=...,0(root)
```

The validator reports `validated: true` and `canary_removed: true`. The HTTP 500
after each injection occurs after command execution because the Curl stub does
not produce a download filename; it is not an authentication or injection
failure.

## Restore-member injection validation

The restore-member injection also passed dynamically on 2026-11-02. The
reconstructed launcher `lab/run-evo-x86.sh` starts the same isolated i686 service
with a private network namespace. `EVO_RESTORE_TEST=1` runs
`lab/evo-x86-restore-test.sh`, which verified unauthenticated `sysinfo`, a
synthetic profile granting only `system/restore`, the crafted archive, and a
negative `backup` permission control.

The restore returned `{"status":"ok","reboot":true}` and created the expected
`EVO_RESTORE_CANARY` through `lualib_backup.lua:677-678`. The restore-only
profile's backup action returned `PERMISSION_DENIED`. The validator removed the
canary, session, locks, user, and profile. All seven i686 validators also passed
in the final regression sequence, with the derived Lighttpd configuration
restored afterward. Evidence: `results/evo-x86-5.8.7-restore-member-injection.txt`
and `results/evo-restore-injection-transferability.json`.

## Boundary

Physical network reachability, device-specific firewall rules, and root command
execution on an owned XWEB3000/5000 remain unverified. XWEB Pro is a separate
platform; this result does not decrypt or claim access to Pro 1.13/1.15.1.
