# XWEB EVO 5.8.8 OTA repository validation

## Result

The actual recovered `new_xwrpm.cgi` retrieved, descrambled, parsed, and filtered
a local fake OTA manifest successfully. It returned `err:0` and one test package.
No package was downloaded or installed.

## Protocol confirmed

- `gu=0` performs repository checking.
- `server` is the repository host; `path` is the repository base path, not the
  manifest filename.
- ARM manifest filename is `epkginfo`.
- With `path=/`, the final URL was `http://127.0.0.1:18081/epkginfo`.
- The manifest and packages use the recovered 20-byte XOR-`0xA1` package-name
  obfuscation rule.
- `<evopacket>` includes `info`, `action`, `evo`, and localized `desc` fields.
- Update state matters: an earlier failed run leaves `/tmp/update_lock`, which
  must be removed in the lab before another attempt.

The fake manifest used version `0.0.1.TEST-LOCAL` and action `cmd=true`, so no
installation was performed.

## Evidence

`results/evo-5.8.8-ota-retrieval.json` records the exact result. Updater logs
show successful Curl completion, descrambling, parsing, and filtering with one
available package.

## Marker-package installation

A follow-on test used a 4096-byte SquashFS package with a marker-only
`updater.sh`. The updater downloaded and descrambled it, the safe extractor
unpacked it, and the real action runner reported `SUCCES` with packet error `0`.
The canary file contains `EVO_OTA_CANARY`. See
`results/evo-5.8.8-ota-install.json`.

This validates update-time script execution in the isolated environment. The
real loop-mount, service-stop, watchdog, firmware-write, and reboot paths were
not exercised, and no real reboot was performed.

## Normal Copeland update system

The recovered default repository is `https://fcmresources.copeland.com/files`.
Public research also confirmed live manifest endpoints under `/evo/`, but no
update credentials were sent and no vendor-side action was attempted.
