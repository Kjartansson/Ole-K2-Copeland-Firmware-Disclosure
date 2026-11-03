# PoC: XWEB2009 unauthenticated SQL import and database export

- Product: XWEB3000/5000 legacy PHP application (XWEB2009)
- Source: official `usb-update-4.0.12.zip`, 4.0.0 base RPM; later 4.0.18/4.0.19
  packages were also recovered for comparison
- Status: **locally validated through Apache; candidate new finding**
- Live-controller testing: not performed
- CVE overlap: no matching endpoint-specific CVE found in the initial review

## Summary

`service/upl.php` accepts an unauthenticated multipart upload, decompresses it,
and imports the resulting SQL into `xj1000db` as MySQL root. `service/dwn.php`
exports database tables through the same privileged account without an
authentication check. The recovered Apache configuration listens on port 80 and
allows all hosts, with no global authentication directive protecting these paths.

An unauthenticated network client can therefore compromise database
confidentiality and integrity on a reachable affected deployment. Potential
consequences include configuration and alarm manipulation, account changes,
data disclosure, and denial of service. No operating-system command execution is
claimed from the database behavior alone.

## Evidence

### Unauthenticated SQL import

`extracted/XWEB3000_5000_v4000_cpio/var/www/html/service/upl.php`:

- Lines 4-8 reads `A` and `sd` without starting or checking a session.
- Lines 15, 36, and 57 move the uploaded file to fixed `.sql.gz` paths.
- Lines 20-24, 40-45, and 61-66 run `gunzip` followed by
  `mysql -uroot xj1000db < ...` for `A=1`, `A=2`, and `A=3`.

### Unauthenticated database export

`extracted/XWEB3000_5000_v4000_cpio/var/www/html/service/dwn.php`:

- Lines 3-5 selects the export through `A` without an authentication check.
- Lines 13-16, 42-45, and 71-74 run `mysqldump -uroot` and return the archive via
  an FTP redirect at lines 99-103.

### Network access context

`extracted/XWEB3000_5000_v4000_cpio/var/www/templates/sysconfig/etc/httpd/conf/httpd.conf.temp:134`
listens on port 80. Lines 305-334 configure `/var/www/html` with
`Allow from all`. Unlike protected application pages, these two endpoints do not
call `session_id()`, check `$_SESSION`, or invoke `WrongAccess()`.

## Local validation

The original PHP files were served unchanged by a loopback-only Apache 2.4.66
instance. A compatibility prepend supplied legacy `$HTTP_GET_VARS`,
`$HTTP_POST_VARS`, and `$HTTP_SERVER_VARS` variables required by this old code.
The `mysql` and `mysqldump` executables were replaced with harmless logging
stubs; no real database was contacted.

Upload request:

```bash
printf 'SELECT 4242;\n' > marker.sql
gzip -f marker.sql
curl -F 'sd=1' -F 'nfile=@marker.sql.gz;type=application/gzip' \
  'http://127.0.0.1:18080/service/upl.php?A=1'
```

Observed result:

- HTTP response contained `SUCCESSO!`.
- The stub recorded `mysql -uroot xj1000db`.
- The stub received exactly `SELECT 4242;` on standard input.

Download request:

```bash
curl -D download-headers.txt \
  'http://127.0.0.1:18080/service/dwn.php?A=1'
```

Observed result:

- HTTP `302` redirected to `ftp://localhost/archive/localhost_Category.gz`.
- The dump stub recorded the root-privileged `mysqldump` invocation.
- Decompressing the exported file returned the marker `SELECT 4242;`.

Logs and responses are under `build/xweb-apache-test/`. The same request forms
should only be repeated on an owned, isolated device if deployed-version
confirmation is required.

## Remediation

- Require authentication and explicit administrative authorization in both
  endpoints before any file or database operation.
- Remove or disable these legacy import/export routes when not required.
- Do not run SQL import/export as MySQL root; use a least-privileged account.
- Restrict accepted SQL to a validated backup format and use fixed transaction,
  rollback, size, timeout, and concurrency limits.
- Remove direct internet exposure and place management access behind a secure
  VPN or protected network, consistent with CERT-FR guidance.
- Review web/database logs and configuration integrity for unauthorized imports
  or exports. Preserve evidence before remediation.

This is a locally validated candidate, not a claim of exploitation against a
live controller or an XWEB Pro decryption result.
