# PoC: XWEB EVO 4.3.0 unauthenticated upload/delete path traversal

- Related analysis report: `analysis/XWEB-EVO-5.2.3.md`
- Related CVE (if any): new candidate; no assignment or independent public overlap established
- Product / version: XWEB300D EVO 4.3.0, exact `upload.cgi` recovered from the owned test unit
- Status: verified static in Ghidra; not exercised on a live controller

## Summary

The EVO upload CGI exposes upload and delete actions without performing a
session or permission check. Although the request's `path` must match a small
set of configured base directories, the filename is appended to that base
without rejecting `..` or canonicalizing the result. A traversal filename can
therefore write or delete files outside the selected upload directory with the
CGI process's privileges.

## Constraints

- Offline static analysis only. No write, delete, upload, or other request was
  sent to a controller.
- The exact affected runtime privilege is not established by the binary alone;
  root-level modification is not claimed.
- This is separate from the previously verified read-only `action=list` and
  `utility.lua` download paths.

## Evidence

Input: `extracted/EVO_4.3.0/upload.cgi`, SHA-256
`f13fd1ef7b7278f4c4f540bc6a4415efe354222f4bb8581c750ff73ed25d459a`.

Ghidra 12.2 analysis log: `results/ghidra-evo-upload.log`.
Decompiler output: `build/evo-upload-decompiled.c` (generated analysis artifact).

### No authentication gate

The binary imports no session/authentication function and contains no session,
permission, canonicalization, or `realpath` operation. Its main action dispatcher
reads `action`, `path`, and form-file fields directly after multipart parsing.

### Delete path

At decompiler output lines 1855-1887, the `delete` branch:

1. Retrieves the attacker-controlled filename.
2. Maps `path` through `FUN_0000dc20` at `0x0000dc20`.
3. Builds the target with `sprintf(..., "%s/%s", mapped_base, filename)` at line
   1872.
4. Calls `access()` and `unlink()` on that unchecked string at lines 1876-1887.

The mapping function at lines 3129-3150 compares only the configured path name
and returns its corresponding base directory. It does not inspect the filename.
For example, the configured `templates` base is `/opt/setup/templates/`; a
filename such as `../../tmp/canary` resolves outside that directory to
`/opt/tmp/canary`.

### Upload path

At decompiler output lines 2072-2097, the upload branch uses the same base
mapping and appends either the multipart filename or the requested `finalfile`.
No traversal rejection occurs before the subsequent file creation/copy logic.
The initial file-exists check at lines 2145-2154 also operates on this unchecked
path.

## Reproduction steps

Reproduce the static analysis locally:

```bash
mkdir -p build/ghidra-evo
analyzeHeadless "$PWD/build/ghidra-evo" upload \
  -import "$PWD/extracted/EVO_4.3.0/upload.cgi" \
  -scriptPath "$PWD/build/ghidra-scripts" \
  -postScript DecompileAll.java "$PWD/build/evo-upload-decompiled.c" \
  -deleteProject
```

Inspect `FUN_0000dc20` and the delete/upload branches identified above. A local
path-resolution model also demonstrates the traversal without modifying any
firmware or device file:

```bash
python3 - <<'PY'
import os
base = '/opt/setup/templates/'
filename = '../../tmp/canary'
constructed = base + filename
print('constructed:', constructed)
print('resolved:   ', os.path.normpath(constructed))
assert os.path.normpath(constructed) == '/opt/tmp/canary'
PY
```

Expected resolved path: `/opt/tmp/canary`.

## Impact

An unauthenticated client can delete or place files outside the intended upload
directories wherever the web/CGI identity has filesystem access. Depending on
runtime permissions and reachable paths, this may destroy configuration,
corrupt databases, alter web content, or enable follow-on code execution. Those
follow-on impacts require owned-device validation and are not asserted here.

## Mitigation / vendor fix

- Require an authenticated, authorized session before every upload, delete,
  list, and check action.
- Reject absolute filenames, `..` components, path separators, and symlink
  traversal. Use a server-generated filename rather than client-supplied paths.
- Canonicalize the parent directory and verify that the final target remains
  beneath the intended base immediately before opening or unlinking it.
- Use non-shell file APIs, least-privilege filesystem permissions, and a
  dedicated upload account with no access to configuration or executable paths.
- Preserve coordinated disclosure before sharing this candidate outside the
  project.
