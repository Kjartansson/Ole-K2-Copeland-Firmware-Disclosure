# PoC19 — XWEB EVO malicious download-server filename command injection

## Status

Dynamically validated against official XWEB3000/5000 EVO 5.8.7 i686
Lighttpd/Lua code in an isolated QEMU/bubblewrap lab. No physical controller or
third-party address was contacted. EVO reached End of Support in March 2026.

A special `Administrator` session is required. The attacker also needs to
control or intercept the preconfiguration download server. This is not an
unauthenticated finding. Physical-device process privileges remain unverified.

## Root cause

`import_preconfiguration` invokes Curl with
`--write-out "%{http_code}|%{filename_effective}"` and parses the returned
filename (`api.lua:1857-1881`). It then inserts that value into a shell `mv`
command without escaping (`api.lua:1891`):

```lua
os.execute('mv -f "'..temp_dir..'/'..filename..'" '..DEVICES_TEMPLATES)
```

A server-supplied filename containing shell separators therefore becomes an OS
command rather than only a download filename.

## Harmless validation

The loopback HTTP response included a crafted `Content-Disposition` filename:

```text
x\";printf DOWNLOAD_CANARY>/opt/setup/templates/download-canary;#
```

After unescaping, `filename_effective` contains:

```text
x";printf DOWNLOAD_CANARY>/opt/setup/templates/download-canary;#
```

The API returned `{"status":"ok"}` and the injected `printf` created
`/opt/setup/templates/download-canary` with content `DOWNLOAD_CANARY`. A request
without an authorized session was denied. The canary and session were removed.

The reduced lab's vendor Curl failed with `curl: (27) Out of memory`, so a small
transport-compatible shim fetched the real response and supplied the same
`200|filename_effective` value to the unmodified vendor API code. The `mv` sink
and command execution are real; physical Curl behavior and device privileges are
not claimed from this test.

## Reproduce

```bash
cd /path/to/Ole-K2-Copeland-Firmware-Disclosure
EVO_DOWNLOAD_TEST=1 lab/run-evo-x86.sh > \
  results/evo-x86-5.8.7-download-filename-injection.txt 2>&1
```

Expected final output: `overall: PASS`. Evidence:
`results/evo-x86-5.8.7-download-filename-injection.txt`,
`lab/evo-x86-download-test.sh`, and
`lab/fixtures/malicious-response.sh`.

## Remediation

- Replace shell-built download/move commands with libcurl plus a fixed-argument
  process API or a safe file-rename operation.
- Treat server filenames as untrusted: reject path separators, shell
  metacharacters, absolute paths, traversal, links, and special files.
- Pin the expected destination filename rather than accepting
  `filename_effective` from a remote server.
- Require authenticated update servers with TLS certificate/hostname validation
  and run download processing with least privilege.
