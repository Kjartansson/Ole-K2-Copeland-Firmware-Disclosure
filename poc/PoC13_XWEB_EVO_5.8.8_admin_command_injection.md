# PoC: XWEB EVO 5.8.8 daily administrator session to API command execution

- Related analysis report: `analysis/XWEB-EVO-5.8.8-SSH-RUNTIME.md`
- Related CVE (if any): new candidate; no assignment or public overlap established
- Product / version: XWEB EVO 5.8.8 ARM
- Status: HTTP injection and command execution validated against actual Lighttpd/Lua on isolated loopback; no physical controller contacted

## Summary

The daily password authenticates the special `Administrator` account and creates
an API session. That session reaches `import_preconfiguration`, whose
`server_username` value is concatenated into a Curl shell command without
escaping. A crafted username closes the quote and executes a second command.
This provides a direct code-execution route independent of SSH reachability.

## Constraints

- Isolated ARM runtime only; loopback HTTP was used, with no controller or external network request.
- The canary writes a fixed marker under `/tmp`; no real Curl request, update,
  restore, or privileged external command was performed.
- Execution privileges on a physical controller are not established by this
  test, so root execution is not claimed here.

## Evidence

### Administrator session

`lualib_users.lua:106-112` assigns the `Administrator` account
`password_mode = 'daily_password'`. Lines 133-139 compare the supplied password
with `xwpasswd`. The actual API returned `status: ok` and an SSES token when the
correct local daily code was supplied.

### Command construction

`api.lua:1889-1899` builds the command:

```lua
local command = 'cd "'..temp_dir..'"; curl --verbose ...'
if server_username then
    command = command..' --user "'..server_username
    if server_password then
        command = command..':'..server_password
    end
    command = command..'"'
end
command = command..' "'..server_url..'"'
for cli_output in io.popen(command):lines() do
```

The session is administrator-authorized before this code. No quoting or
metacharacter rejection protects `server_username`.

### Runtime validation

The request used a username of this form:

```text
x:y"; printf EVO_RCE_CANARY >/tmp/evo-rce; #
```

The generated command logged by the API was:

```text
curl ... --user "x:y"; printf EVO_RCE_CANARY >/tmp/evo-rce; #" "http://192.0.2.1/x"
```

QEMU syscall tracing in `results/evo-import-strace.log` records the shell opening
`/tmp/evo-rce` for writing. The file contains `EVO_RCE_CANARY`. A follow-on
injection wrote real `id` output into the templates directory. That output was
then retrieved through `utility.lua`, confirming `uid=0(root)` remotely in the
lab.
Machine-readable outcome: `results/evo-5.8.8-admin-command-injection-runtime.json`.

For an explicitly owned device where creating a canary is approved:

```bash
source ~/.venvs/firmware/bin/activate
python tools/xweb_evo_rce.py https://192.0.2.10 --authorized
```

The validator retrieves the command output through `utility.lua` and removes
its canary by default. Mock harness: `results/evo-rce-validator-harness.json`.

## Impact

An attacker who can derive the daily code can create an administrator API
session and execute commands with the API process's privileges. This route does
not require the SSH service or a reachable SSH port. `rcS` starts Lighttpd as
root, no alternate server user/group is configured, and the privilege-drop
lines are commented out. A follow-on loopback injection executed the real `id`
command and produced `uid=0(root)` output, confirming root command execution in
the lab. Physical process ownership and network reachability remain unverified.
See `analysis/XWEB-EVO-5.8.8-HTTP-RCE.md` and
`results/evo-5.8.8-http-rce-validation.json`.

## Mitigation / vendor fix

- Remove shell invocation from download handling. Use libcurl or a fixed
  argument-array process API with no shell.
- Reject shell metacharacters in all server credential and URL fields.
- Require a strong, unique administrator password rather than the public
  MAC/date-derived daily code for sensitive API actions.
- Run the web/API process with least privilege even when commands are properly
  constructed.
- Preserve coordinated disclosure before sharing this candidate outside the
  project.
