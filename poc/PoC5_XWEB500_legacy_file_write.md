# PoC: XWEB500 v1.1 default admin and unauthenticated file operations

- Product/version: XWEB500 application `V110`, package dated 2007-01-23
- Status: verified in complete official payload files
- Known vulnerability overlap: CVE-2021-45420
- Live write/delete testing: not performed

## Default administrator

`usr/xweb500/db/utenti/dbUser.db` contains the MD5 values
`1161778906` and `1161773656`, which are MD5(`Admin`) and MD5(`admin`).
The default administrator credential is therefore `Admin`/`Admin`.

## File upload and deletion

`usr/xweb500/cgi-bin/lo_utils.cgi` reads `ACTION=%d` from stdin and dispatches
values 0–5 without an authentication check:

- `lo_image_upload` (`0x8bf8`) concatenates an attacker-controlled first line
  with `/usr/xweb500/db/Layout/images/`, then calls `fopen` and writes input.
- `lo_del_image` (`0x8b6c`) uses the same path construction and calls `unlink`.
- `cal_save.cgi` (`0x8e30`) constructs `/usr/xweb500/db/cal/<input>` and writes
  input with no canonical-path validation or authentication check.

The public PoC for CVE-2021-45420 documents the same operation: first line as
filename, second line as content. The recovered code also means traversal
components cannot be assumed safe; a safe implementation must reject absolute
paths and `..` components and require authorization before file access.

## Evidence and reproduction boundary

The official ZIP and six payloads were decoded with `0xa7`, decompressed, and
parsed with `tools/xweb500_uf_extract.py`. All six gzip streams and all 1,801
record files validate. No request was sent to a device. Do not execute the
write/delete operations except in a disposable owned lab.

## Remediation

- Isolate XWEB500 management interfaces; this product is legacy and should be
  replaced or retired where possible.
- Change default credentials and review all accounts.
- Require authentication and authorization in every CGI action, including
  directory, upload, save, and delete handlers.
- Canonicalize filenames to an allowed directory and reject traversal.
- Review logs and filesystem integrity for unexpected files, then preserve
  evidence before remediation.

This is a known-vulnerability verification, not a new zero-day claim and not an
XWEB Pro or E3/SS decryption result.
