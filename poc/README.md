# Validated PoC index

Researcher: Ole-k2.

“Validated” is scoped to the evidence stated in each report. Static recovery,
local models, actual vendor-code emulation, and physical-device exploitation are
not interchangeable. Personal remote-device artifacts are excluded.

## Legacy firmware and authentication

| PoC | Finding | Evidence boundary |
|---|---|---|
| [PoC2](PoC2_XWEB_EVO_offline_recovery.md) | Offline legacy package recovery | Decoder/recovery enabler, not itself a zero-day |
| [PoC3](PoC3_XWEB_EVO_readonly_access.md) | EVO 4.3.0 directory/file read and default-admin access | Read-only authorized-unit result; all unit identifiers and downloads omitted |
| [PoC4](PoC4_XWEB_EVO_legacy_pass_the_hash.md) | EVO 3.0.8–4.3.0 hardcoded Administrator pass-the-hash | Verified in official package trees; absent in 5.2.3/5.8.8 |
| [PoC5](PoC5_XWEB500_legacy_file_write.md) | XWEB500 default admin and unauthenticated file write/delete | Verified in recovered official files; known CVE-2021-45420, not a new zero-day |
| [PoC6](PoC6_XWEB2009_unauthenticated_sql_import_export.md) | XWEB2009 unauthenticated SQL import/export | Local compatibility model; no live-controller claim |
| [PoC7](PoC7_XWEB2009_unauthenticated_command_injection.md) | XWEB2009 unauthenticated command-injection paths | Local compatibility model; no live-controller claim |
| [PoC8](PoC8_XWEB2009_xwtool_backdoor.md) | XWEB2009 fixed `xwtool` backdoor credential | Locally reproduced; no live-controller claim |
| [PoC9](PoC9_XWEB2009_unauthenticated_file_read_delete.md) | XWEB2009 unauthenticated file read/delete | Local compatibility model; no live-controller claim |
| [PoC10](PoC10_XWEB_EVO_api_preauth.md) | EVO 4.3.0 pre-auth shell injection and SQL login bypass | Local source/shell/SQL models; no live request |
| [PoC11](PoC11_XWEB_EVO_upload_traversal.md) | EVO 4.3.0 unauthenticated upload/delete traversal | Static Ghidra verification; no live write/delete |

## EVO 5.8.7–5.8.8 isolated runtime chains

| PoC | Finding | Evidence boundary |
|---|---|---|
| [PoC12](PoC12_XWEB_EVO_5.8.8_ssh_root_chain.md) | Public-MAC daily credential → SSH enablement → predictable root credential | Actual Lua/runtime components validated; complete physical SSH chain not tested |
| [PoC13](PoC13_XWEB_EVO_5.8.8_admin_command_injection.md) | Administrator `import_preconfiguration` command injection | Actual loopback HTTP root command execution on ARM; physical reachability untested |
| [PoC14](PoC14_XWEB_EVO_config_write_debug_terminal.md) | Unauthenticated central config overwrite; Administrator root terminal | Actual loopback HTTP on ARM and i686; originals restored |
| [PoC15](PoC15_XWEB_EVO_information_disclosure.md) | Unauthenticated error-log disclosure and authenticated monitor-file traversal | Synthetic fixture/loopback runtime evidence |
| [PoC16](PoC16_XWEB_EVO_restore_member_injection.md) | Restore tar member-name command injection | ARM and i686, including restore-only role; cleanup passed |
| [PoC17](PoC17_XWEB_EVO_debug_backup_device_injection.md) | Debug backup `device` command injection | i686 Administrator canary; no-session control passed |
| [PoC18](PoC18_XWEB_EVO_restore_checksum_filename_injection.md) | Restore checksum-filename command injection | i686 Administrator canary; post-execution error bounded |
| [PoC19](PoC19_XWEB_EVO_download_filename_injection.md) | Malicious download-server filename injection | Real API sink with transport-compatible Curl shim; physical Curl behavior unclaimed |
| [PoC20](PoC20_XWEB_EVO_exportpars_traversal_delete.md) | `exportpars` traversal file read/deletion | i686 valid-session dedicated canary |
| [PoC21](PoC21_XWEB_EVO_restore_password_injection.md) | Restore OpenSSL password command injection | i686 Administrator canary; cleanup passed |
| [PoC22](PoC22_XWEB_EVO_backup_password_injection.md) | Backup OpenSSL password command injection | i686 Administrator canary and success response |
| [PoC23](PoC23_XWEB_EVO_restore_server_credential_injection.md) | Restore-server username/password command injection | ARM and i686 with restore-only role; no-session controls passed |
| [PoC24](PoC24_XWEB_EVO_factory_password_reset.md) | Factory-state unauthenticated superadmin password reset | ARM and i686; new login, negative controls, and cleanup passed |

## Excluded or unresolved

- PoC1's SFUB ECB-malleability proposal is excluded because later analysis did
  not validate conventional ECB or a working plaintext/modification path.
- E3/Site Supervisor SFUB and XWEB Pro payloads remain encrypted.
- ZIP/TAR archive traversal through the genuine tested BusyBox tools was not
  reproduced; normalization/refusal checks passed.
- EVO 4.3.0 upload/delete findings do not transfer to 5.8.8, and EVO 5.2.3 lacks
  the 5.8.x SSH action.
