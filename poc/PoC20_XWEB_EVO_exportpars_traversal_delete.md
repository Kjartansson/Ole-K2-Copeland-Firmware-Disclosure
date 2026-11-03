# PoC20 — XWEB EVO `exportpars` traversal file read and deletion

## Status

Dynamically validated against official XWEB3000/5000 EVO 5.8.7 i686
Lighttpd/Lua code in an isolated QEMU/bubblewrap lab. No physical controller or
third-party address was contacted. EVO reached End of Support in March 2026.

A valid session is required. This is not an unauthenticated finding. The session
must also have the expected export-directory structure; no export-permission
check is made by this branch. Physical-device file permissions and process
ownership remain unverified.

## Root cause

`utility.lua:83-86` constructs a download path by appending the supplied
`filename` to the session export directory without canonicalization:

```lua
downloadFile = '/opt/tmp/'..SSES..'/parameters/00000000000000000000000000000000/'..tostring(filename)
file = io.open(downloadFile, 'rb')
removeFile = true
```

After returning the file, the handler calls `os.remove(downloadFile)`. Traversal
can therefore read and delete files outside the session directory, subject to
process filesystem permissions and existence of intermediate export directories.

## Harmless validation

The lab created a dedicated `/opt/setup/templates/exportpars-canary` and the
required session `parameters/000...` directory, then supplied:

```text
../../../../setup/templates/exportpars-canary
```

The real handler returned `EXPORTPARS_CANARY`, proving a read outside the
session directory. It then deleted that file, proving deletion through the same
traversal. A request without a session returned `PERMISSION_DENIED`. No real
configuration or system file was touched.

## Reproduce

```bash
cd /path/to/Ole-K2-Copeland-Firmware-Disclosure
EVO_EXPORTPARS_TEST=1 lab/run-evo-x86.sh > \
  results/evo-x86-5.8.7-exportpars-traversal.txt 2>&1
```

Expected final output: `overall: PASS`. Evidence:
`results/evo-x86-5.8.7-exportpars-traversal.txt` and
`lab/evo-x86-exportpars-test.sh`.

## Remediation

- Canonicalize the resolved path and require it to remain beneath the intended
  session export directory; reject absolute paths and `..` components.
- Perform export authorization before both reading and deleting files, and never
  delete a file selected by an untrusted filename.
- Use a safe file API with least-privilege filesystem permissions and add
  read/write/delete traversal regression tests.
