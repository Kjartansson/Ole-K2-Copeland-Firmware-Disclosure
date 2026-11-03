# Ole-K2 Copeland Firmware Disclosure

**Researcher: Ole-k2**

Independent, evidence-first security research on legacy Copeland/Dixell XWEB
controllers and related E2/E3/Site Supervisor firmware.

> **Disclosure status: PRIVATE.** This repository is prepared for coordinated
> disclosure through Copeland product security. It must remain private until
> Ole-k2 explicitly approves public release. No personal information, personal
> remote/test-device identifiers, customer data, session tokens, or raw device
> captures are included.

## Purpose

Provide reproducible evidence for validated legacy-firmware weaknesses and
access chains so Copeland and operators can understand and mitigate them. The
repository distinguishes offline/static evidence, local models, actual vendor
code running in isolated labs, and physical-device boundaries. It does not
claim a current XWEB Pro or E3/Site Supervisor exploit.

Copeland has stated that XWEB EVO reached End of Support in March 2026 and that
no further security updates or vulnerability fixes will be released for those
models. Migration, credential hygiene, and isolation from untrusted networks
are therefore the primary operator mitigations for EVO findings.

## Validated findings and chains

See the [complete PoC index](poc/README.md).

- **Legacy XWEB2009 / XWEB500 / EVO 3.0.8–4.3.0:** package recovery,
  authentication weaknesses, file access, command injection, and default or
  hardcoded credentials (PoC2–PoC11). Evidence ranges from static analysis and
  local models to read-only authorized-unit validation; all personal artifacts
  are omitted.
- **EVO 5.8.7–5.8.8 SSH chain:** public MAC/date information derives the daily
  credential used by the unauthenticated SSH-control API and the predictable
  root credential. Component behavior is validated; a complete physical SSH
  login is not claimed ([PoC12](poc/PoC12_XWEB_EVO_5.8.8_ssh_root_chain.md)).
- **Actual vendor-code HTTP/RCE chains:** daily-code Administrator command
  execution, direct root terminal, unauthenticated configuration overwrite,
  information disclosure, restore/archive injection, and related handlers were
  exercised in isolated ARM/i686 labs (PoC13–PoC23).
- **Factory first-login reset:** an unauthenticated factory-state password reset
  created a working superadmin credential on both architectures, with negative
  controls and cleanup ([PoC24](poc/PoC24_XWEB_EVO_factory_password_reset.md)).
- **OTA update-time execution:** a marker package was retrieved, decoded,
  unpacked, and executed in the isolated runtime; real firmware writes and
  reboot paths were not exercised ([OTA analysis](analysis/XWEB-EVO-5.8.8-OTA.md)).

## Legacy firmware coverage

Official source URLs and hashes are preserved in `SOURCES.md` and
`firmware/SHA256SUMS`. `DECODERS.md` and `tools/` document validated recovery of
XWEB2009, XWEB500, and XWEB EVO packages. Analysis covers the older recovered
firmware trees, updater logic, and the E2/E3/Site Supervisor research boundary.
Large proprietary firmware archives and personal recovered images are not
redistributed.

The disproven SFUB ECB-malleability claim is intentionally excluded. E3/Site
Supervisor SFUB payloads and XWEB Pro `Salted__` payloads remain encrypted; no
validated plaintext, decryptor, current-product exploit, or new Pro zero-day is
claimed. Known public CVEs are not presented as discoveries by Ole-k2.

## Repository layout

- `poc/` — validated legacy and EVO findings with explicit evidence boundaries.
- `analysis/` — legacy-firmware, updater, runtime-chain, and negative-result reports.
- `tools/` — decoders, daily-password model, and authorization-gated validators.
- `lab/` — loopback-only ARM/i686 launchers, validators, and synthetic fixtures.
- `results/` — the sanitized factory-reset result and evidence guidance only.
- `submission/DISCLOSURE-STATUS.md` — sanitized vendor/disclosure status.

## Reproduction

Run offline decoders and password self-tests with Python 3. The SSH validator
additionally requires Paramiko:

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python tools/xweb_evo_password.py 30 10 26 --mac 00:11:22:33:44:55
.venv/bin/python tools/xweb_evo_password.py 30 10 26 --mac 00:11:22:33:44:55 --root-password
```

The example MAC and date are documentation values, not a researcher's device.
The EVO lab launchers require locally supplied official firmware/rootfs artifacts
and QEMU/bubblewrap dependencies. They use private loopback-only namespaces and
synthetic users/profiles. Review each script before execution.

The two controller validators require an explicit `--authorized` flag and a
target supplied by the operator. No target belonging to the researcher is
included. Do not point them at third-party or production systems. Raw output
must be sanitized before sharing and is ignored by Git.

## Responsible use

This material is published for defense: so operators can assess exposure, and
so the industry's update/credential practices improve. The PoCs are written to
be non-destructive (canary/marker proofs, no bricking paths). Do not use this
against systems you do not own or are not authorized to test.

## Disclaimer

Independent research, not affiliated with or endorsed by Copeland or Dixell.
Public firmware packages analyzed were publicly downloadable; no
authentication, license, or access control was circumvented to obtain them.
Personal test-unit evidence and remote-device information are omitted.
