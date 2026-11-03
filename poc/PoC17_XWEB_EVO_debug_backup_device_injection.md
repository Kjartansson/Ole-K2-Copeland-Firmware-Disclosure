# PoC17 — XWEB EVO `backup_isto` device command injection

## Status

Dynamically validated against official XWEB3000/5000 EVO 5.8.7 i686
Lighttpd/Lua code in an isolated QEMU/bubblewrap lab. No physical controller or
third-party address was contacted. EVO reached End of Support in March 2026.

A special `Administrator` session is required; this is not an unauthenticated
finding. Physical-device process privileges remain unverified.

## Root cause

`debug.lua:20-27` rejects requests without a valid session whose user ID is not
zero. After that gate, `backup_isto` concatenates the POST `device` value into a
shell `mount` command at `debug.lua:303`:

```lua
local retcode = os.execute('mount "'..tostring(device)..'" "'..tostring(mount_path)..'" > /dev/null')
```

There is no shell escaping or device-path allow-list. Shell separators in
`device` therefore execute before the expected mount failure.

## Harmless validation

A request without a session returned `PERMISSION_DENIED`. The lab then
authenticated as `Administrator` with the daily code and supplied this device
value:

```text
x";printf DEBUG_BACKUP_CANARY>/opt/setup/templates/debug-backup-canary;#
```

The response was `{"status":"error"}`, as expected because the mount does not
succeed in the lab. Nevertheless, the injected `printf` created
`/opt/setup/templates/debug-backup-canary` with content
`DEBUG_BACKUP_CANARY`, proving command execution before the error path. The
canary and session were removed afterward.

## Reproduce

```bash
cd /path/to/Ole-K2-Copeland-Firmware-Disclosure
EVO_DEBUG_BACKUP_TEST=1 lab/run-evo-x86.sh > \
  results/evo-x86-5.8.7-debug-backup-injection.txt 2>&1
```

Expected final output: `overall: PASS`. Evidence:
`results/evo-x86-5.8.7-debug-backup-injection.txt` and
`lab/evo-x86-debug-backup-test.sh`.

## Remediation

- Replace shell-based mount handling with a fixed-argument process API or a
  privileged helper that accepts only an existing block-device path.
- Canonicalize device paths and reject shell metacharacters and unexpected
  prefixes. Do not pass web-supplied values to `os.execute`.
- Keep Administrator-only authorization and run the web/mount operations with
  least privilege.
- Apply the same review to the separate `password` values used by
  `backup_isto` and `restore_isto`; those sinks were not dynamically tested by
  this device-specific proof.
