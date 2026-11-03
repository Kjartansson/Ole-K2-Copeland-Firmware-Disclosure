# PoC16 — XWEB EVO restore tar member-name command injection

## Status

Dynamically validated with official vendor Lighttpd/Lua code in isolated
QEMU/bubblewrap labs. No physical controller or third-party address was
contacted.

- XWEB3000/5000 EVO 5.8.7 i686: confirmed over loopback HTTP.
- XWEB300D EVO 5.8.8 ARM: confirmed over loopback HTTP.
- A session with `system/restore` permission is required. Administrator rights
  are not required; this is not an unauthenticated finding.
- EVO reached End of Support in March 2026. Physical reachability and process
  privileges on a controller remain unverified.

## Root cause

`Backup.restore()` lists the input archive with `tar -tf`, selects lines matching
`isto`, and appends each resulting member name to a shell command without
quoting it. A member name containing shell separators therefore becomes part of
the command rather than only an archive filename.

Relevant code: `lualib_backup.lua:677-678`:

```lua
for xwbk_file in io.popen('tar -tf "'..settings.input_path..'" | grep isto'):lines() do
    os.execute('tar --extract --overwrite --directory='..tempFolder..
               ' --file="'..settings.input_path..'" '..xwbk_file..' > /dev/null')
end
```

The authorized route is `POST /cgi-bin/api.lua action=restore`. The handler
checks Administrator or `Session.isPermitted(SSES, 'system', 'restore')`, then
passes the selected archive to `Backup.restore()`.

## Harmless proof

The probe archive contains this member name:

```text
isto;printf EVO_RESTORE_CANARY>/opt/setup/templates/evo-restore-canary;#.xwbk
```

`tar -tf` emits the name unchanged. The subsequent shell executes `printf`,
creating a fixed canary; `#` comments out the remaining command. No external
command, persistence, credential access, or real restore payload is used.

A synthetic profile grants only:

```json
{"system":{"restore":1}}
```

The restore-only account authenticated successfully. On both architectures, the
restore returned:

```json
{"status":"ok","reboot":true}
```

and `/opt/setup/templates/evo-restore-canary` contained
`EVO_RESTORE_CANARY`. The same profile's `backup` action returned
`PERMISSION_DENIED`, confirming that restore succeeds because of its explicit
permission rather than a general permission-gate bypass.

ARM 5.8.8 was also validated with an Administrator session. The vulnerable data
section and restore route are byte-identical on i686 5.8.7.

## Reproduce i686 5.8.7

```bash
cd /path/to/Ole-K2-Copeland-Firmware-Disclosure
EVO_RESTORE_TEST=1 lab/run-evo-x86.sh > \
  results/evo-x86-5.8.7-restore-member-injection.txt 2>&1
```

The launcher uses a private, loopback-only network namespace and derived rootfs.
The validator creates and then removes its lab-only user/profile, session,
canary, and lock files. Expected final output: `overall: PASS`.

Evidence:

- `results/evo-5.8.8-restore-member-injection.json`
- `results/evo-x86-5.8.7-restore-member-injection.txt`
- `results/evo-restore-injection-transferability.json`
- `lab/run-evo-x86.sh`
- `lab/evo-x86-restore-test.sh`

## Impact and boundaries

A restore-authorized user can execute shell commands through a crafted archive.
The lab process runs as the host user; physical-device process ownership and
root execution are not established by these tests. Full post-restore helper
behavior and hardware reliability were not tested. A real deployment's profile
permission matrix was not enumerated.

## Remediation

- Do not build archive-extraction commands through a shell. Use a fixed-argument
  process API or a maintained archive library with explicit member-name handling.
- Reject unexpected members and path/shell metacharacters before extraction;
  enforce canonical destinations and prevent traversal, links, and special files.
- Require strong authentication and per-operation authorization for restore,
  and run the web/restore process with least privilege.
- Add regression tests for restore-only roles, shell separators, whitespace,
  traversal, absolute paths, and malformed archives. Deny unrelated actions such
  as `backup` when that permission is absent.
