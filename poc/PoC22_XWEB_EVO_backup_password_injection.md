# PoC22 — XWEB EVO `backup_isto` password command injection

## Status

Dynamically validated against official XWEB3000/5000 EVO 5.8.7 i686
Lighttpd/Lua code in an isolated QEMU/bubblewrap lab. No physical controller or
third-party address was contacted. EVO reached End of Support in March 2026.

A special `Administrator` session is required. This is not an unauthenticated
finding. Physical-device process privileges remain unverified.

## Root cause

`backup_isto` optionally encrypts the output archive and concatenates the
password directly into an OpenSSL command (`debug.lua:373-375`):

```lua
local retcode = os.execute('openssl enc -e -aes256 -in "'..output_file..
  '" -out "'..output_file..'.enc" -pass "pass:'..password..'" > /dev/null 2>/dev/null')
```

The password is not escaped, allowing shell separators to become commands.

## Harmless validation

A request without a session returned `PERMISSION_DENIED`. With an
Administrator session, the password value was:

```text
x";printf BACKUP_PASSWORD_CANARY>/opt/setup/templates/backup-password-canary;#
```

The real handler returned `{"status":"ok"}` and created
`/opt/setup/templates/backup-password-canary` with content
`BACKUP_PASSWORD_CANARY`. The canary and session were removed. Lab-only mount
and archive-creation shims were used; physical mounting and device privileges
were not tested.

## Reproduce

```bash
cd /path/to/Ole-K2-Copeland-Firmware-Disclosure
EVO_BACKUP_PASSWORD_TEST=1 lab/run-evo-x86.sh > \
  results/evo-x86-5.8.7-backup-password-injection.txt 2>&1
```

Expected final output: `overall: PASS`. Evidence:
`results/evo-x86-5.8.7-backup-password-injection.txt` and
`lab/evo-x86-backup-password-test.sh`.

## Remediation

- Replace shell-built OpenSSL commands with a fixed-argument process API or a
  maintained encryption library.
- Reject shell metacharacters in passwords and avoid passwords on command lines;
  use a protected descriptor or library API.
- Keep Administrator-only authorization and least-privilege backup handling.
- Add password-injection tests for every backup/restore action.
