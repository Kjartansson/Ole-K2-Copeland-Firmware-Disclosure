# PoC: XWEB EVO 5.8.7–5.8.8 unauthenticated SSH enablement and predictable root credential

- Related analysis report: `analysis/XWEB-EVO-5.2.3.md`
- Related CVE (if any): new chain candidate; no assignment or public overlap established
- Product / version: XWEB EVO 5.8.7 and 5.8.8 ARM, recovered official packages
- Status: public-MAC and API start/stop behavior verified with actual Lua in isolated ARM runtime; physical root SSH login not performed

## Summary

EVO 5.8.7 and 5.8.8 expose the controller MAC address without a session. Their
API accepts that MAC-derived daily password to start the SSH service without a
web session. A daily cron script sets the Unix root password to `xwebdix` plus
the same daily code. These components form a potential unauthenticated remote
root-access chain when the API and SSH port are reachable.

## Constraints

- Actual vendor Lua/API behavior and credential derivation were validated in an
  isolated runtime. No physical controller or external network was contacted.
- A complete physical SSH login and reachability of the SSH port after service
  startup remain unverified.
- The daily code is device- and date-specific. Do not use the example MAC or
  code against another controller.

## Evidence

Preserved artifacts under `extracted/EVO_5.8.8/`:

| File | SHA-256 |
|---|---|
| `api.lua` | `3e62fc7ca7c45282b0dd0cb6b062213e72afc7f7b66fde8b98ffd8158ed233cc` |
| `sysinfo.lua` | `52ce500c3a2abd21dbf715795ab62e21160ac8811933487051bb40ee56771d81` |
| `chp` | `01e8981130f0c3727ad5afbb98e0ac24e0248db9f899e3970cd5c6e734f0f469` |
| `dropbear` | `de1056602a23c58ad93831f257fdde71b92644fce592f697a022948f6543a714` |
| `xwpasswd` | `e069078516ffcf50a4a281d6b8e6b3d12b734a1c0a92e36b116b7a03a24a8827` |

### 1. Public MAC disclosure

`sysinfo.lua:60-68` reads the `eth0` MAC and assigns it to `output.id` regardless
of whether the request has an extended authenticated session. The same response
includes release and timestamp information at lines 102-117.

### 2. Unauthenticated SSH enablement

`api.lua:360-413` handles `action=ssh` without calling `getUserSession()`. It
compares the supplied password with the output of
`/opt/xweb/bin/tools/xwpasswd`, then starts Dropbear on ARM when `target=start`.
The init script contains no root-login restriction.

### 3. Matching root credential

`etc/cron.daily/chp:3-6` sets:

```sh
PASSWORD=xwebdix`/opt/xweb/bin/tools/xwpasswd`
echo "root:${HASH}" | chpasswd -e
```

`etc/passwd` gives root `/bin/sh`. Therefore the API password and root password
share the same MAC/date-derived six-character code; root additionally uses the
`xwebdix` prefix.

### 4. Exact binary validation

The current-date mode uses `year - 100`, while explicit `-w day month year`
uses the full year byte. `tools/xweb_evo_password.py` now preserves that
distinction. On 2026-10-30 with example MAC `00:11:22:33:44:55`:

```text
Daily API code: O0ANI3
Root password:  xwebdixO0ANI3
```

The recovered 4.3.0, 5.8.7, and 5.8.8 `xwpasswd` binaries all returned `O0ANI3`
under QEMU with `-k 001122334455`, matching the corrected Python implementation.
EVO 5.8.7 contains the same public-MAC, `action=ssh`, and root-password logic.
EVO 5.2.3 does not expose `action=ssh` in its recovered `api.lua`, so this exact
chain is not claimed for that version.

## Reproduction steps

Offline only, using the example MAC and date:

```bash
python3 tools/xweb_evo_password.py 30 10 26 --mac 00:11:22:33:44:55
python3 tools/xweb_evo_password.py 30 10 26 --mac 00:11:22:33:44:55 --root-password
```

Expected outputs: `O0ANI3` and `xwebdixO0ANI3`.

For an explicitly owned device, the documented chain to validate later is:

1. Read the public MAC and timestamp from `cgi-bin/sysinfo.lua`.
2. Derive the daily code with that MAC and the controller's current date.
3. Submit `action=ssh`, `target=start`, and the daily code to
   `cgi-bin/api.lua`.
4. If the network policy permits SSH, authenticate as root with `xwebdix` plus
   the same code.
5. Stop SSH after validation and record the result. Do not test this sequence
   against third-party Shodan results.

## Impact

A remote unauthenticated attacker who can reach the API can potentially enable
SSH and obtain a root shell using only public MAC/date information. This bypasses
web accounts entirely. Firewall rules, service startup behavior, and device date
must be correct for the complete chain to succeed.

## Mitigation / vendor fix

- Do not expose the MAC address or other device-unique identifiers before
  authentication.
- Remove daily-password SSH enablement from the unauthenticated API and require
  an authorized administrative session.
- Do not derive root passwords from public or predictable inputs. Use unique,
  randomly generated credentials or key-only administrative access.
- Disable SSH by default, restrict root login, and firewall SSH to a dedicated
  management network.
- Rotate any credential derived with the old scheme after applying a fix.
- Preserve coordinated disclosure before sharing this candidate outside the
  project.
