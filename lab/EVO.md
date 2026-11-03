# EVO isolated ARM/i686 labs

Researcher: Ole-k2.

The launchers and validators use actual recovered vendor code in private
loopback-only QEMU/bubblewrap environments with synthetic users, profiles, and
configuration. No personal remote-device configuration is included or required.

Supply official firmware/rootfs artifacts locally at the ignored paths expected
by `run-evo-arm.sh` and `run-evo-x86.sh`. Review the launchers and each
validator before execution. Validators use fixed canaries, restore original
configuration where applicable, and remove synthetic accounts, sessions,
canaries, and locks.

The shell validators cover factory reset, configuration overwrite, restore
member/server injection, debug backup/restore, download filename, exportpars,
and backup/restore password paths. `evo_archive_tool_probe.py` checks the
negative ZIP/TAR containment result using disposable extraction roots.

E3/Site Supervisor remains at a different boundary: no executable SFUB runtime
has been recovered, so there is no honest E3 QEMU smoke test. Do not infer an
E3 or XWEB Pro exploit from the EVO labs.
