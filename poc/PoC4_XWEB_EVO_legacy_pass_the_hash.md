# PoC: XWEB EVO 3.0.8–4.3.0 hardcoded pass-the-hash login

- Affected recovered versions: XWEB EVO 3.0.8, 4.0.3, and 4.3.0
- Status: verified statically in complete official package trees
- Authentication class: hardcoded credential / pass-the-hash
- Live exploitation: not performed; no third-party target was contacted

## Evidence

Each version's `opt/www/cgi-bin/xwmanager.lua` handles the special username
`Administrator`. It accepts the request when `upass` equals either the MD5 of the
current daily password or this literal value:

```text
df862c19e0bb172846e8853d7bca54a3
```

For example, 4.3.0 `xwmanager.lua:365–375` tests:

```lua
if CGI.params['upass'] ~= md5(dailyPassword)
    and CGI.params['upass'] ~= 'df862c19e0bb172846e8853d7bca54a3' then
    -- reject
else
    -- Administrator password accepted
end
```

The literal value is accepted directly as `upass`; an attacker does not need its
plaintext preimage. Rockyou did not recover that preimage, but password cracking
is irrelevant to this bypass. The same value is absent from the recovered 5.2.3
and 5.8.8 authentication code.

## Reproduction boundary

Use only an isolated owned installation. The request form is the same one used
by the web interface, with `r=l`, `bd=-1`, `uname=Administrator`, and the literal
`upass` above. Do not use this against Internet-facing or third-party devices.
No controller request was used for this finding; the evidence is
based on complete official code, not a claimed live bypass.

## Impact and remediation

The mechanism creates a version-shared administrator credential independent of
the daily password and per-device MAC. It can provide full web management access
on unpatched legacy versions, followed by access to update and backup functions.

- Isolate legacy EVO devices from untrusted networks immediately.
- Upgrade to a later version after a verified backup and compatibility check.
  The literal is absent from 5.2.3 and 5.8.8, but those versions have their own
  security limitations and EVO support ended on 2026-03-16.
- Change all default credentials, review active sessions, and monitor login
  requests containing the literal hash or username `Administrator`.
- Remove hardcoded alternate credentials from authentication code and require
  per-user, salted, slow password hashing with no password-equivalent secrets.

This is a separate finding from the read-only directory traversal and the
verified default `Admin`/`Admin` login on the owned 4.3.0 test unit.
