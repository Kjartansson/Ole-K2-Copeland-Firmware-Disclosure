# PoC24 — XWEB EVO factory-state unauthenticated superadmin password reset

Researcher: Ole-k2.

## Status

Dynamically validated with official vendor Lighttpd/Lua code in isolated
QEMU/bubblewrap labs. No physical controller or third-party address was used.

- XWEB300D EVO 5.8.8 ARM: confirmed over loopback HTTP.
- XWEB3000/5000 EVO 5.8.7 i686: confirmed over loopback HTTP.
- Transfer to XWEB Pro 1.15.1 is not claimed.

## Root cause

The `update_password` action accepts the factory administrator record (ID 1)
without a session when that record is in the initial factory state
`password_expiration=-2`. The action replaces the password and advances the
expiration state. The new password then authenticates with superadmin
privileges.

This is a factory-first-login state issue, not a reset that works against every
normally configured account.

## Harmless validation

The labs used synthetic user/profile data and a dedicated runtime. On both
architectures:

1. An unauthenticated request changed the factory ID-1 password and returned
   `status: ok`.
2. The new password authenticated successfully with superadmin privileges.
3. A normal-state control (`password_expiration=-1`) returned
   `PERMISSION_DENIED`.
4. The i686 missing-ID control returned `EXECUTION_ERROR`.
5. The password hash changed and expiration advanced to `-1`.
6. Synthetic users, profiles, and sessions were removed after the test.

Sanitized result: `results/evo-factory-password-reset.json`. The i686 validator
is `lab/evo-x86-factory-reset-test.sh`; its final result is `overall: PASS`.

## Impact and boundaries

An attacker who can reach a device still in the factory first-login state can
set the initial administrative password without authenticating, gaining the
resulting management privileges. Physical deployment state, network
reachability, and subsequent refrigeration-control impact were not tested.

## Remediation

- Require an authenticated, locally proven commissioning flow before changing
  the factory administrator credential.
- Treat the first-login transition as a security boundary: bind setup to a
  restricted interface or physical presence and expire incomplete setup safely.
- Reject password updates without a valid session outside a narrowly defined,
  one-time provisioning state; validate ID, state, and permissions server-side.
- Add regression tests for no-session, wrong-ID, normal-state, replay, and
  concurrent first-login requests.

## Operator mitigation

Keep EVO management interfaces off untrusted networks, complete commissioning
with a unique strong password, review accounts for unauthorized changes, and
migrate from end-of-support EVO hardware using Copeland's published upgrade
resources.
