# PoC15 — XWEB EVO unauthenticated logs and Administrator file read

## Status

Validated with genuine current EVO handlers in isolated QEMU/bubblewrap labs.
No physical controller or third-party address was contacted.

## 1. Unauthenticated SQLite log disclosure

`syserrors.lua` has no session check. When notification-error records reference
system-log IDs, it returns `date`, `msg`, `arg`, and `dbinfo` from
`/opt/log/systemLog.sqlite`.

A synthetic log record was inserted only into the derived i686 5.8.7 lab. An
unauthenticated empty POST to `/cgi-bin/syserrors.lua` returned:

```json
{
  "systemlog": {
    "1": {
      "msg": "LAB_LOG_DISCLOSURE",
      "arg": "LAB_PARAMETER",
      "dbinfo": "LAB_DBINFO"
    }
  }
}
```

This proves unauthenticated SQLite log-field disclosure. Real log sensitivity
depends on device activity; the fixture was removed after validation.

Evidence:

- `results/evo-x86-5.8.7-syserrors-fixture.json`
- `extracted/XWEB_EVO_5.8.7_3000_5000_rootfs/opt/xweb/www/cgi-bin/syserrors.lua:320-334`

## 2. Administrator arbitrary file read

`debug.lua get_monitor_file` concatenates unvalidated `monitor` below the
session directory. With a daily-code Administrator session, this request used
traversal to read the lab's non-secret `/etc/xwebconfig.json`:

```http
POST /cgi-bin/debug.lua
Content-Type: application/x-www-form-urlencoded

action=get_monitor_file&monitor=../../../etc/xwebconfig.json&SSES=<fresh-token>
```

The response contained the file in the JSON `monitor` field. This verifies
Administrator-context file read outside the intended directory on ARM 5.8.8;
i686 5.8.7 contains the identical handler.

Evidence:

- `results/evo-arm-5.8.8-monitor-traversal.json`
- `extracted/XWEB_EVO_5.8.7_3000_5000_rootfs/opt/xweb/www/cgi-bin/debug.lua:276-285`

## Remediation direction

Require authentication and authorization before returning logs or monitor data,
and canonicalize file paths to remain below the designated session directory.
Physical-device reachability and the sensitivity of real production logs remain
separate validation steps.
