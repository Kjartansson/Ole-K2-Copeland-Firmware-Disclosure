# Official Sources

All material is publicly available from Copeland. Firmware URLs below are the
vendor's own public download links. Hashes in `firmware/SHA256SUMS` were recorded
only after each local download completed and its expected byte size was verified.

## Product pages and documentation

- E3 Supervisory Control product page:
  https://www.copeland.com/en-us/products/controls-monitoring-systems/facility-controls-electronics/facility-and-system-controls/supervisory-controls-e3
- Site Supervisor (SS) product page:
  https://www.copeland.com/en-us/products/controls-monitoring-systems/facility-controls-electronics/facility-and-system-controls/supervisory-control-ss
- Supervisory E3 documents (manuals, bulletins):
  https://www.copeland.com/en-us/products/controls-monitoring-systems/facility-controls-electronics/facility-and-system-controls/documents/supervisory-e3
- Copeland product security resources (advisories, disclosure contact):
  https://www.copeland.com/en-gb/product-security-resources
- Vendor security advisory (local copy): `firmware/reference/026-4296-security-update-advisory.pdf`

## Firmware packages

Downloaded from the official product pages on 2026-10-24. Sizes and hashes were
verified locally with `sha256sum -c firmware/SHA256SUMS`.

| Product | Version | Local filename | Size (bytes) | SHA-256 | Official URL |
|---|---|---|---:|---|---|
| E3 | 2.23F02 | E3_2.23F02_Display_Update.pkg | 426042820 | c86d16710dd82d0811bb76b683548a221552b65594e855df7c346b4acd980edd | https://media.copeland.com/0c419cb4-5dd9-4e85-813e-b20a00604d94/E3_2.23F02_Display_Update |
| E3 | 2.31F01 | E3_2.31F01_Display_Update.pkg | 438288912 | 8a4f7f63118900b9d45f068f558c66a51b59e8d1b89f6f8ab46b4d19b68768d7 | https://media.copeland.com/8a428fe2-e71c-4291-8a97-b2920095e15b/E3_2.31F01_Display_Update |
| E3 | 2.34F01 | E3_2.34F01_Display_Update.pkg | 438607376 | 883419906d10ff57c50a6951b1d38e1f2ddc56fdd13a5ed11773e5db3e1e7024 | https://media.copeland.com/eeb37990-d29f-4e0a-a61f-b4e4014465e6/E3_2.34F01_Display_Update |
| SS | 2.23F02 | SS_2.23F02_Firmware_Update.pkg | 52754600 | 39f64ba8a9d2ca753bea71f10b857c406e8e4d376c6540c896f8e74ee392ded3 | https://media.copeland.com/c8a3b6da-b79a-43bc-9ecc-b1fc008bf476/SS_2.23F02_Firmware_Update |
| SS | 2.31F01 | SS_2.31F01_Firmware_Update.pkg | 59437584 | d45d1b87757aaac1f87985fd8b1ef9b583248a1dc7da78ac1cc5c13dc58b46b1 | https://media.copeland.com/20ce5c38-e7e5-4749-8f81-b29200960f2e/SS_2.31F01_Firmware_Update |
| SS | 2.34F01 | SS_2.34F01_Firmware_Update.pkg | 62710288 | 649e0aea8b9f4acb5b3bfaf0b6eda21c2fe31bc9b66e137e9b7f310a90d0db4e | https://media.copeland.com/1caf5554-6b4e-4162-8bc0-b4e401446b31/SS_2.34F01_Firmware_Update |

2.31F01 is the version in which Copeland fixed the nine published CVEs
(see `analysis/REGRESSION-MATRIX.md`); 2.23F02 is the pre-fix baseline and
2.34F01 the current release.

## Downloaded reference documents

The `firmware/reference/` directory contains the installation/operation manual,
password-management guide, security advisory, release notes for 2.31–2.34, and
the 2.02 update advisory. PDF hashes are in `firmware/reference/SHA256SUMS`;
matching text was generated locally with `pdftotext -layout` for searching.

- 2.34F01 release notes (026-4097): https://media.copeland.com/41e6c024-bf8e-439c-855d-b4e4014a0aa1/e3-supervisor-234-release-notes.pdf
- 2.33 release notes (026-4096): https://media.copeland.com/69afcc19-e745-4127-8223-b45d007a09a0/supervisory-fw-233-release-notes.pdf
- 2.32 release notes (026-4095): https://media.copeland.com/ae54cb2a-74c2-45fe-804e-b3e5006953bd/4095-supervisory-control-release-notes-2-32f01.pdf
- 2.31 release notes (026-4092): https://media.copeland.com/d2c157ae-2928-423c-a2ea-b3800085ea47/supervisory-controller-2-31-release-notes.pdf
- Installation and operation manual (026-1803): https://media.copeland.com/24cdca41-8c5f-47f7-9ebb-b16d004f4492/Supervisory%20Control%20E3%20Manual.pdf
- Password management guide (026-4293): https://media.copeland.com/17e2abee-4e3c-413d-8bbc-b30900b07bc8/Supervisory-Controller-Password-Management-Guide.pdf
- Security update advisory (026-4296): https://media.copeland.com/09aaa6ae-bcf7-4661-9592-b34e013fe01b/security-update-advisory-for-supervisory-controllers.pdf
- 2.02 update advisory (026-4034): https://media.copeland.com/618e8474-09e9-4e13-b521-b16d002d2a76/Update%20Advisory%20Site%20Supervisor%202.02F01.pdf

## Related tooling and packages acquired during cryptanalysis

- UltraSite 5.11 installer: https://media.copeland.com/781e34d0-08ba-4f35-983d-b39b00d99cbf/UltraSite32_511_StandAlone.exe?apr_optimization=false
- E2 3.11F02: https://media.copeland.com/676cfc35-e565-4c94-bf1b-b16d0016fd67/E2_3.11F02_Firmware_Update.pkg
- E2E 4.11F03: https://media.copeland.com/564d5cb8-8251-48d9-a11b-b16d0019b93a/e2e-4-11f03-firmware-update.pkg
- SS 2.30F02: https://media.copeland.com/20ce5c38-e7e5-4749-8f81-b29200960f2e/SS_2.30F02_Firmware_Update
- Legacy XWEB2009 plaintext USB update 4.0.19: https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/XWEB3000-XWEB5000/usb-update-4.0.19.zip
- Legacy XWEB2009 encrypted upload update chain through 4.0.19: https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/XWEB3000-XWEB5000/upload-update-4.0.19.zip
- Legacy XWEB3000/5000 3.3.3 installer: https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/XWEB3000-XWEB5000/XWEB3000_5000_V333-20090407.zip
- Legacy XWEB3000/5000 3.2 base installer: https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/XWEB3000-XWEB5000/XWEB3000v32.zip
- XWEB EVO 5.2.3 x86 package: https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/XWEB30005000-EVO/XWEB_EVO_5.2.3.STANDARD.5-bbfd5b_3000_5000.zip
- XWEB EVO 5.2.3 ARM package: https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/XWEB-300D-500D-500-EVO/XWEB_EVO_5.2.3.STANDARD.5-bbfd5b_300D_500D_500.zip
- XWEB500B PRO Coolmate 1.15.1: https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/XWEB300D-500D-500-PRO/XWEB_PRO_xwcoolmate_standard.1.15.1_LIB20260816.update.xweb
- WIZMATE 1.4.0.0 installer: https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/WIZMATE/wizmate_1_4_0_0_Setup.zip
- WIZMATE programming-driver package: https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/WIZMATE/Driver_ProgTool_2022.03.zip
- LIB Builder 1.1.12: https://webapps.copeland.com/Dixell/Content/Pages/LIBBuilder_Setup.zip
- XWEB500 USB recovery/update 1.6-to-2.0: https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/XWEB300D-XWEB500-XWEB500D/20120111-XWEB500-USB-1.6to2.0.zip
- XWEB500 update 2.02: https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/XWEB300D-XWEB500-XWEB500D/Update202.zip
- XWEB500 v1.1 (2007): https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/XWEB300D-XWEB500-XWEB500D/XWEB500v11.zip
- Select 8.47.1 (user-supplied Copeland Select download): https://selectonline.eu.copeland.com/downloads/Select8.47.1_FULLDRAW.zip
- XWEB EVO 5.8.8 ARM package: https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/XWEB-300D-500D-500-EVO/XWEB_EVO_5.8.8.STANDARD.24-25902d_300D_500D_500.zip
- XWEB EVO 5.8.7 ARM package: https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/XWEB-300D-500D-500-EVO/XWEB_EVO_5.8.7.STANDARD.23-f27c2a_300D_500D_500.zip
- XWEB3000/5000 EVO 5.8.7 i686 package with libraries: https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/XWEB30005000-EVO/XWEB_EVO_5.8.7.STANDARD.23-f27c2a_3000_5000_LIB20240201.zip
- XWEB EVO 3.0.8 package: https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/XWEB-300D-500D-500-EVO/EVOPackage-3.0.8-c84e92.zip
- XWEB EVO 4.0.3 package: https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/XWEB-300D-500D-500-EVO/EVOPackage-4.0.3-628fe8_300_500.zip
- XWEB EVO 4.3.0 package: https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/XWEB-300D-500D-500-EVO/EVOPackage-4.3.0-75f7e9_300_500.zip
- XWEB EVO download index and 5.8.8 changelog/EOS bulletin: https://webapps.copeland.com/Dixell/Pages/XWEB300D_500D_500_EVO
- Claroty Team82 XWEB Pro research: https://claroty.com/team82/research/chilling-discoveries-unpacking-vulnerabilities-in-copeland-xweb-pro-controllers
- Dixell XWEB-500 arbitrary file write reference (distinct product): https://www.exploit-db.com/exploits/50639
- XWEB500D PRO 1.3.0: https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/XWEB300D-500D-500-PRO/XWEB_PRO_xw500d_standard.1.3.0_v1.update.xweb
- E2 4.11F02: https://media.copeland.com/564d5cb8-8251-48d9-a11b-b16d0019b93a/E2_4.11F02_Firmware_Update.pkg
- E2 4.11F03 (ELF byte-identical to E2E 4.11F03): https://media.copeland.com/564d5cb8-8251-48d9-a11b-b16d0019b93a/E2_4.11F03_Firmware_Update.pkg
- XWEB5000 PRO 1.13.0: https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/XWEB5000-PRO/XWEB_PRO_xw5000_standard.1.13.0_LIB20260201.update.xweb
- XWEB5000 PRO 1.12.1 catalog entry (10-byte `Dummy file`, not firmware): https://webapps.copeland.com/dixell/Content/Pages/SystemSoftwareUpdate/XWEB5000-PRO/XWEB_PRO_xw5000_standard.1.12.1_LIB20251002.update.xweb

Local paths, byte sizes, SHA-256 hashes, extraction outcomes, and third-party
source links are recorded in `analysis/RELATED-TOOLING.md`. These related files
are not part of the original six-package `firmware/SHA256SUMS` manifest.
