# E3 / Site Supervisor lab status

No firmware emulation or hardware test has been performed.

The downloaded SFUB containers do not expose executable applications, a kernel,
a root filesystem, or a loadable disk image through standard offline extraction.
Consequently there is currently no honest QEMU smoke-test target. The installed
`qemu-arm` and `qemu-aarch64` binaries are not evidence that these opaque
packages can be emulated.

To enable runtime work, obtain one of the following through an authorized route:

- a decrypted firmware/rootfs image and its architecture-specific runtime libs;
- an authorized E3 or Site Supervisor controller for non-destructive lab tests;
- vendor update/emulation tooling that lawfully exposes the package contents.

Runtime tests must remain on an isolated lab network, use non-destructive
markers, avoid persistent changes, and distinguish application responses from
actual operating-system or refrigeration-control impact. Do not test production
or internet-facing controllers.
