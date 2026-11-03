# XWEB EVO 5.8.8 SSH chain — isolated ARM runtime verification

## Result

The actual recovered 5.8.8 `api.lua` and `sysinfo.lua` were executed in an
isolated ARM bubblewrap/QEMU environment. The API-level chain is now verified;
only physical-device SSH connectivity remains untested.

No external network request was made and no physical controller was contacted;
all execution stayed inside the isolated runtime.

## Environment

- Genuine EVO 5.8.8 ARM package under the original Copeland research tree.
- Debian ARM Lua 5.1.5 interpreter with vendor Lua sources and libraries.
- Unchanged `api.lua` and `sysinfo.lua`.
- Minimal runtime configuration and an empty `libxwfunc` compatibility stub for
  the SSH-only action. `libconfig` was stubbed only for the sysinfo run.
- The Dropbear init script was replaced with a recorder, never a real service.
- A synthetic `ip` command returned only documentation MAC/IP values.

The `/bin/sh` symlink was replaced with the real BusyBox binary because QEMU
otherwise returned empty subprocess output. After that correction, the genuine
`xwpasswd` subprocess returned `H5FOG1`, matching its direct QEMU invocation.

## Verified behavior

Machine-readable result: `results/evo-5.8.8-api-arm-runtime.json`.

### Public system information

With no session supplied, the real `sysinfo.lua` returned `status: ok` and:

```json
{
  "id": "001122334455",
  "model_type": "XWEB300D",
  "release": "5.8.8.STANDARD.24--25902d",
  "timezone": "Europe/Rome"
}
```

The ID came from the synthetic `ip` stub. This verifies that the script's public
response path includes the MAC field; it is not a claim about a real device's
address.

### Wrong password rejected

Request body with `action=ssh`, `password=WRONG`, and `target=start` returned:

```json
{"status":"error","error":"PERMISSION_DENIED"}
```

The init recorder was not called.

### Correct password starts and stops SSH

With the actual code produced by the local `xwpasswd` subprocess:

```json
{"SSH":"start"}
{"SSH":"stop"}
```

The recorder contained exactly:

```text
start
stop
```

This verifies real password comparison, action dispatch, and init-script
execution in the recovered API code.

## Actual Dropbear password authentication

The recovered Dropbear 2022.83 service was also started on `127.0.0.1:2222`
with a synthetic root account and host key. With the documentation-only password
`xwebdixO0ANI3`, the service log recorded:

```text
Password auth succeeded for 'root' from 127.0.0.1
```

See `results/evo-5.8.8-dropbear-auth-validation.json`. A local user-namespace
group-mapping error prevented the subsequent shell session. This verifies the
credential with the real SSH service but not command execution or device network
reachability.

## Remaining device-only gaps

- No physical root SSH login or command execution has been performed.
- Firewall behavior, service startup timing, and exact device MAC/date remain
  runtime properties.
- This is stronger evidence than static analysis and password-only emulation,
  but it is not yet a physical end-to-end exploit demonstration.

## Next safe validation

On an explicitly owned 5.8.7 or 5.8.8 controller only, use the prepared
`tools/xweb_evo_ssh_chain.py` validator. It reads public system information,
starts SSH, requires a root `uid=0` proof, and stops SSH by default. Do not run
it against third-party Shodan results.
