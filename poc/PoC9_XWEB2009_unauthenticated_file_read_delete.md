# PoC: XWEB2009 unauthenticated file read and deletion

- Product: XWEB3000/5000 legacy PHP application (XWEB2009)
- Source: official 4.0.0 base RPM from `usb-update-4.0.12.zip`
- Status: **locally validated through Apache; candidate new finding**
- Live-controller testing: not performed

## Arbitrary file read

`service/BackupRestoreSup.php:5-18` concatenates GET `dw` with `/tmp/` and calls
`readfile()` without canonicalization or an authorization check. A request with
`dw=../tmp/xweb-download-marker.txt`
returned exactly `DOWNLOAD_MARKER_4242`, proving traversal outside `/tmp` in the
isolated lab.

## Arbitrary file deletion

`Exports/ExportImportLibSup.php:5-13` concatenates GET `dwn` with `/tmp/`, calls
`readfile()`, then calls `unlink()` with the same value. A separate marker file
was returned and then deleted, confirming the operation.

Both endpoints are reachable under the recovered Apache `Allow from all`
configuration without a session or permission check.

## Boundary

The file-write path using an uploaded filename was **not** confirmed: PHP
normalized the uploaded name to a basename in this lab. `qa=` command injection
was also **not** confirmed because `file_exists($QueryArc)` rejects the injected
string before `system()` executes. These negative results are not claims that
those paths are safe under every runtime.

## Remediation

- Require authentication and administrative authorization for file operations.
- Resolve paths against an explicit allowed directory and reject absolute paths,
  `..` components, links, and non-regular files.
- Do not delete or return files based solely on request parameters.
- Keep management interfaces off the internet and review unexpected file access
  and deletion in application and filesystem logs.
