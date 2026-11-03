# PoC: XWEB EVO 4.3.0 API pre-authentication command injection and SQL authentication bypass

- Related analysis report: `analysis/XWEB-EVO-5.2.3.md`
- Related CVE (if any): new candidates; no assignment or independent public overlap established
- Product / version: XWEB300D EVO 4.3.0, exact `api.lua` recovered from the owned test unit
- Status: locally validated source and sink models; not exercised on a live controller

## Summary

The EVO API handles two unauthenticated inputs unsafely. The `auth` parameter is
concatenated into a shell command before session validation, permitting shell
command injection. Independently, `username` is concatenated into the login SQL
query, permitting a UNION query that supplies an attacker-selected password hash
and administrator UID. These are distinct access paths from the previously
documented traversal, default credentials, and `Administrator` pass-the-hash.

## Constraints

- Static and local-only validation. No request was sent to a controller or any
  internet-facing system.
- The command-injection model preserves the exact EVO string construction but
  substitutes a harmless local `xwsses.cgi` stub and a fixed canary.
- The SQL model uses the exact query construction against an in-memory SQLite
  database. It does not claim that a live session was created.
- Only the recovered 4.3.0 file is covered. Other versions require separate
  source review.

## Evidence

Source: `extracted/EVO_4.3.0/api.lua`, SHA-256
`3520e19d246985ea854dc05b935febef61a92c50fed626a4a0b92d9c6b182755`.

### 1. Pre-authentication shell command injection

`getUserSession()` passes `auth` directly to `io.popen()` at `api.lua:68-69`:

```lua
local r = io.popen('/opt/xweb/www/cgi-bin/xwsses.cgi \"?op=4&sses='..auth..'\"'):read()
```

The session check has not happened when this command runs. The `devices_list`
action at `api.lua:437-450` accepts `auth` without a username/password and calls
`getUserSession()` directly. Several other actions use the same function.

A harmless payload of the following form closes the quoted argument, runs a
second command, and comments out the remaining quote:

```text
invalid"; printf EVO_API_CANARY > /tmp/evo_api_canary; #
```

The local validator reproduced the exact command construction and confirmed that
the canary command ran.

### 2. SQL authentication bypass

At `api.lua:93-109`, `username` is inserted into SQL without binding or escaping:

```lua
for data in db:nrows('SELECT UID, UPASS, UENDATE, UENAB FROM user WHERE UNAME=\''..username..'\'') do
    if Core.md5(password) ~= data.UPASS then
        -- reject
    else
        -- create a session for data.UID
    end
end
```

The `authenticate` action reaches this code at `api.lua:216-234`. A UNION input
can return UID 1, an attacker-selected MD5, and enabled/non-expired account
attributes. The local model used a username of this form:

```text
' UNION SELECT 1, '<md5-of-supplied-password>', 0, 1 --
```

The query returned UID 1 and the MD5 of the supplied password, satisfying every
account check in the reviewed branch.

## Reproduction steps

Run the local-only validator:

```bash
python3 tools/xweb_evo_api_validate.py \
  extracted/EVO_4.3.0/api.lua \
  --json results/evo-4.3.0-api-local-validation.json
```

Expected results:

- `shell_command_injection.validated` is `true`.
- `sql_authentication_bypass.validated` is `true`.
- The SQL model returns `returned_uid: 1` and
  `password_hash_matches: true`.

The validator performs no network operations and does not invoke the recovered
CGI binary.

## Impact

- The `auth` path can execute commands with the privileges of the API/web
  process before a valid session is established. Root execution is not claimed
  without runtime privilege evidence.
- The SQL path can create an administrative API session without knowing an
  existing user's password, followed by access to actions available to that
  session. Live session creation and subsequent actions remain unconfirmed.
- Either issue can remove the need for default or previously recovered
  credentials on an affected reachable EVO API.

## Mitigation / vendor fix

- Do not invoke a shell for session validation. Call a session API directly or
  use a non-shell process interface with a fixed argument array.
- Treat session identifiers as opaque values with a strict length and character
  allowlist, and validate them before any process invocation.
- Use prepared statements with bound parameters for all user, permission, and
  configuration queries.
- Return a generic authentication failure and do not allow query results to
  select UID, account state, or password verifier independently of the stored
  user row.
- Review all API actions sharing `getUserSession()`, and preserve coordinated
  disclosure before sharing these candidates outside the project.
