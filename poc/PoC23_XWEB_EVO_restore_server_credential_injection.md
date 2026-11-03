# PoC23 — XWEB EVO restore-server credential command injection

## Status

Dynamically validated against official XWEB3000/5000 EVO 5.8.7 i686 and
XWEB300D EVO 5.8.8 ARM Lighttpd/Lua code in isolated QEMU/bubblewrap labs. No
physical controller or third-party address was contacted. EVO reached End of
Support in March 2026.

A session with `system/restore` permission is required. The validator used a
non-administrator profile granting only that permission. This is not an
unauthenticated finding, and physical-device process privileges remain unverified.

## Root cause

For `action=restore&input=server`, `api.lua:2309-2319` builds a shell command by
concatenating `server_username` and `server_password` into Curl's `--user`
argument, then executes it with `io.popen`:

```lua
command = command..' --user "'..server_username
if server_password then
  command = command..':'..server_password
end
command = command..'"'
for status_code in io.popen(command):lines() do
```

Neither value is shell-escaped. Either one can terminate the quoted argument and
append shell commands.

## Harmless validation

A request without a session returned `PERMISSION_DENIED` and created no canary.
With the restore-only session, separate requests used these decoded values:

```text
server_password=x";printf RESTORE_SERVER_PASSWORD_CANARY > /opt/setup/templates/restore-server-canary;#
server_username=restoreuser";printf RESTORE_SERVER_USERNAME_CANARY > /opt/setup/templates/restore-server-canary;#
```

On both architectures, the password request created the first expected marker.
After cleanup, the username request created the second expected marker. The
requests used the genuine API and shell sink with lab Curl transport shims and
loopback-only URLs.

The i686 responses were `EXECUTION_ERROR` with `Server HTTP nil`; the ARM
responses were `INVALID_INPUT` with `Missing or invalid input_path`. These
errors occurred after the command canaries because no valid backup was downloaded.
They are not evidence that injection failed. All canaries, sessions, download
artifacts, and restore-only fixtures were removed.

## Reproduce

```bash
cd /path/to/Ole-K2-Copeland-Firmware-Disclosure
EVO_RESTORE_SERVER_TEST=1 lab/run-evo-x86.sh > \
  results/evo-x86-5.8.7-restore-server-injection.txt 2>&1
EVO_RESTORE_SERVER_TEST=1 lab/run-evo-arm.sh > \
  results/evo-arm-5.8.8-restore-server-injection.txt 2>&1
```

Expected final output from each command: `overall: PASS`. Evidence:
`results/evo-x86-5.8.7-restore-server-injection.txt`,
`results/evo-arm-5.8.8-restore-server-injection.txt`,
`lab/evo-x86-restore-server-test.sh`, and
`lab/evo-arm-restore-server-test.sh`.

## Remediation

- Replace shell-built Curl commands with a fixed-argument process API or HTTP
  library; never concatenate credentials into a shell command.
- Keep credentials in protected memory or descriptors rather than command-line
  arguments where possible.
- Retain the `system/restore` authorization check and add separate injection
  tests for username, password, URL, and output-path fields.
