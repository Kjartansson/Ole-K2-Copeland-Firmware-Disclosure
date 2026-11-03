# PoC18 — XWEB EVO `restore_isto` checksum-filename command injection

## Status

Dynamically validated against official XWEB3000/5000 EVO 5.8.7 i686
Lighttpd/Lua code in an isolated QEMU/bubblewrap lab. No physical controller or
third-party address was contacted. EVO reached End of Support in March 2026.

A special `Administrator` session is required. This is not an unauthenticated
finding. Physical-device process privileges remain unverified.

## Root cause

After validating an uploaded archive, `restore_isto` reads `md5sum_list.txt` and
recovers each `isto_...` filename. It interpolates that filename into shell
commands without quoting it (`debug.lua:491-508`), including:

```lua
local retcode = os.execute('unzip -qq "'..input_file..'" "'..filename..'" -d "/opt/isto" > /dev/null')
```

A crafted checksum-list filename containing shell separators therefore becomes
an OS command rather than only an archive member name.

## Harmless validation

The valid lab ZIP contains this line in `md5sum_list.txt`:

```text
00000000000000000000000000000000 isto_probe";printf DEBUG_RESTORE_CANARY>/opt/setup/templates/debug-restore-canary;#
```

A request without a session returned `PERMISSION_DENIED`. An Administrator
session then selected the archive through `restore_isto`. The shell executed
`printf`, creating `/opt/setup/templates/debug-restore-canary` with content
`DEBUG_RESTORE_CANARY`.

The reduced lab subsequently returned HTTP 500 during later restore handling;
the canary was already present. This is not treated as an authentication or
injection failure. No physical mount was needed: lab-only no-op mount shims and
the real vendor archive-validation/extraction path were used. The canary,
session, temporary archive, and instrumentation were removed.

## Reproduce

```bash
cd /path/to/Ole-K2-Copeland-Firmware-Disclosure
EVO_DEBUG_RESTORE_TEST=1 lab/run-evo-x86.sh > \
  results/evo-x86-5.8.7-debug-restore-injection.txt 2>&1
```

Expected final output: `overall: PASS`. Evidence:
`results/evo-x86-5.8.7-debug-restore-injection.txt`,
`lab/evo-x86-debug-restore-test.sh`, and
`build/evo-x86-runtime/restore-injection.zip`.

## Remediation

- Replace shell-built unzip/md5sum commands with fixed-argument process APIs or
  a maintained archive/checksum library.
- Validate member names before extraction and reject shell metacharacters,
  absolute paths, traversal, links, and special files.
- Require per-operation authorization and run restore processing with least
  privilege.
- Add regression tests for crafted checksum-list filenames, malformed archives,
  whitespace, and post-extraction error paths.
