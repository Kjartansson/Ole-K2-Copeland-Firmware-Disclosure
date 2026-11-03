# PoC: XWEB2009 unauthenticated OS command injection

- Product: XWEB3000/5000 legacy PHP application (XWEB2009)
- Source: official 4.0.0 base RPM from `usb-update-4.0.12.zip`
- Status: **locally validated through Apache; candidate new finding**
- Live-controller testing: not performed

## Summary

Five endpoint families pass attacker-controlled data to shell commands without
authentication or adequate shell escaping. Loopback tests produced unique canary
files for each path. No real device utility or third-party service was invoked.

| Endpoint | Input and sink | Local result |
|---|---|---|
| `Backup/dbwrapper.php` | `F=1`: `p1`, `p2`, `p3`, optional `p4` are concatenated into `popen()` at lines 49-57. `F=2` has similar input at lines 84-121. | `p1` canary executed. |
| `service/backupisto_restore.php` | GET `c` is assigned directly to `$Cmd` and passed to `exec()` at lines 129-133. | `c` canary executed. |
| `service/backupisto_checkshare.php` | POST `u`, `p`, `c`, `d`, and `s` enter `exec()` at lines 20-23. | `u` canary executed. |
| `service/backupisto_getshare.php` | POST `c`, `u`, and `p` enter `popen()` at lines 50-64. | `c` canary executed. |
| `Administration/Discovery/ExecFind.php` | POST `c` reaches `exec($Cmd, $DevListResult)` at line 52. Starting a session does not add an authorization check. | `c` canary executed. |

The recovered Apache template listens on port 80 and allows all hosts. These are
OS command-execution paths, not SQL injection.

## Local validation method

The recovered files ran in a loopback-only Apache 2.4.66/PHP 8.5 instance. A
compatibility overlay supplied legacy variables and syntax plus stubbed DBA and
helper functions. Absolute helper paths were replaced with logging stubs. Each
payload created only `/tmp/xweb-rce-<case>` and the canary was removed after the
check.

Representative request forms for an owned isolated lab only:

```text
GET  /Backup/dbwrapper.php?F=1&p1=x;touch /tmp/xweb-rce-dbwrapper;&p2=1&p3=2
GET  /service/backupisto_restore.php?c=touch /tmp/xweb-rce-restore
POST /service/backupisto_checkshare.php  u=x;touch /tmp/xweb-rce-checkshare;&p=p&c=c&d=d&s=s
POST /service/backupisto_getshare.php    id=1&u=u&p=p&c=x;touch /tmp/xweb-rce-getshare;&d=d
POST /Administration/Discovery/ExecFind.php?u=1  c=touch /tmp/xweb-rce-execfind
```

All five canaries were observed. Responses and logs are under
`build/xweb-apache-test/`.

## Remediation

- Require authentication and explicit administrative authorization in every
  command-processing route; starting a session is not an authorization check.
- Replace shell commands with native APIs or fixed argument arrays. Never pass
  request data through a shell.
- If a helper is unavoidable, use a strict allowlist for operation and argument
  values and escape arguments with a platform-appropriate function.
- Remove direct internet exposure and review logs for unexpected helper calls,
  files, and device configuration changes.

This is local compatibility-overlay evidence, not an exact legacy-runtime or
live-controller exploitation claim.
