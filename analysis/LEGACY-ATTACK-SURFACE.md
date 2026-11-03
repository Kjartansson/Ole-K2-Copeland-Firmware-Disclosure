# XWEB2009 legacy attack-surface coverage

## Inventory

`tools/xweb_php_attack_surface.py` scanned the recovered 4.0.0 web tree and
produced `results/XWEB3000_5000_v4000.attack-surface.json`.

- 68 PHP files contain 361 dangerous operations.
- 50 files have session/auth markers; 18 have no markers.
- Operations: 137 `exec`, 137 `system`, 24 `passthru`, 17 `popen`, 35 `unlink`,
  six `copy`, and five `move_uploaded_file`.

Auth markers are not proof of enforcement. Static presence is also not proof of
reachability. Each issue below is therefore separated by validation status.

## Locally validated

| Case | Evidence |
|---|---|
| SQL import as MySQL root | `poc/PoC6_XWEB2009_unauthenticated_sql_import_export.md` |
| Database export as MySQL root | same PoC |
| Command injection, five paths | `poc/PoC7_XWEB2009_unauthenticated_command_injection.md` |
| `xwtool` fixed backdoor `Administ`/`po` | `poc/PoC8_XWEB2009_xwtool_backdoor.md` |
| File read and deletion | `poc/PoC9_XWEB2009_unauthenticated_file_read_delete.md` |

All dynamic checks were loopback-only and used harmless markers, command stubs,
and a PHP 8.5 compatibility overlay. They are not exact legacy-runtime or
live-controller claims.

## Rejected or unresolved in this round

- `qa=`: `file_exists($QueryArc)` rejected the injected string before `system()`.
- Uploaded-filename arbitrary-directory write: PHP supplied a basename in this
  lab, so no out-of-directory write was confirmed.
- `Backup/dbservice.php`: shell construction needs caller/data-flow review; no
  direct HTTP parameter is present in the function itself.
- `xwtool` alternate `gbr201067080568` day-password path: verified only with the
  lab's stubbed day password, not with a real device password.
- Other backup/export/upload commands: require per-route data-flow and reachability
  review; they are not automatically vulnerabilities because they call a shell.

## Newly documented static finding

- `analysis/XWEB2009_UPDATE-BACKCHANNEL.md`: update-time collection and email of
  network/device/version metadata to the vendor and two blind-copied external
  recipients when SMTP is configured. No email was sent or observed.

## Coverage limits

- The complete 4.0.0 base plus incremental 4.0.12, 4.0.18, and 4.0.19 packages
  were decoded. Not every one of the 68 files has been dynamically exercised.
- Static source may include operations added by other packages or removed by a
  particular deployment. Exact affected-version claims need local version
  confirmation.
- PRO and Danfoss FF encryption remain separate unresolved tasks.
