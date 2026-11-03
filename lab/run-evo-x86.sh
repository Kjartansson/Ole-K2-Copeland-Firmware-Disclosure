#!/usr/bin/env bash
set -euo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ROOT="$REPO/build/evo-x86-rootfs"
RUN="$REPO/build/evo-x86-runtime"
QEMU=${QEMU_I386:-/usr/bin/qemu-i386}

[[ -x "$ROOT/usr/sbin/lighttpd" ]] || { echo "missing derived i686 rootfs" >&2; exit 1; }
[[ -x "$QEMU" ]] || { echo "missing qemu-i386: $QEMU" >&2; exit 1; }

CURL="$RUN/curl"

BWRAP=(bwrap
  --unshare-net --unshare-pid --unshare-uts --unshare-ipc --die-with-parent
  --bind "$ROOT" /
  --ro-bind "$ROOT/bin/bash" /bin/sh
  --ro-bind "$ROOT/bin/busybox" /bin/rm
  --ro-bind "$ROOT/bin/busybox" /bin/cp
  --ro-bind "$ROOT/bin/busybox" /bin/tar
  --ro-bind "$ROOT/bin/busybox" /usr/bin/tar
  --ro-bind "$ROOT/bin/busybox" /bin/mkdir
  --ro-bind "$ROOT/bin/busybox" /bin/chmod
  --ro-bind "$ROOT/bin/busybox" /usr/bin/touch
  --ro-bind "$ROOT/bin/busybox" /bin/sleep
  --ro-bind "$QEMU" /usr/bin/qemu-i386
  --ro-bind /lib/i386-linux-gnu/ld-linux.so.2 /lib/ld-linux.so.2
  --ro-bind /lib/i386-linux-gnu /lib/i386-linux-gnu
  --ro-bind /usr/lib/i386-linux-gnu /usr/lib/i386-linux-gnu
  --dir /opt/evo-compat
  --ro-bind "$REPO/build/evo-lua-x86/root/lib/i386-linux-gnu" /opt/evo-compat/lib
  --ro-bind "$REPO/build/evo-lua-x86/root/usr/lib/i386-linux-gnu" /opt/evo-compat/usr-lib
  --setenv LD_LIBRARY_PATH /opt/evo-compat/lib:/opt/evo-compat/usr-lib:/lib/i386-linux-gnu:/usr/lib/i386-linux-gnu:/lib:/usr/lib
  --proc /proc --dev /dev
  --bind "$RUN/opt-tmp" /opt/tmp
  --bind "$RUN/shm" /dev/shm
  --bind "$RUN/tmp" /tmp
  --bind "$RUN/var-log" /var/log
  --bind "$RUN/var-run" /var/run
  --bind "$RUN/lighttpd-custom.conf" /etc/lighttpd/lighttpd-custom.conf
  --bind "$RUN/xwebconfig.json" /etc/xwebconfig.json
  --bind "$RUN/xwpasswd" /opt/xweb/bin/tools/xwpasswd
  --bind "$RUN/wlua" /opt/xweb/bin/tools/wlua
  --bind "$CURL" /usr/bin/curl
  --bind "$RUN/ip" /usr/bin/ip
  --bind "$RUN/mount" /bin/mount
  --bind "$RUN/mount" /usr/bin/mount
  --bind "$RUN/umount" /usr/bin/umount
  --bind "$RUN/unzip" /usr/bin/unzip
  --bind "$RUN/find" /usr/bin/find
  --bind "$RUN/md5sum" /usr/bin/md5sum
  --bind "$RUN/zip" /usr/bin/zip
  --ro-bind "$RUN/restore-injection.zip" /opt/restore-injection.zip
  --ro-bind "$REPO/lab" /lab
  --setenv PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/xweb/bin/tools
)

if [[ ${EVO_RESTORE_TEST:-0} == 1 ]]; then
  exec "${BWRAP[@]}" /bin/busybox sh /lab/evo-x86-restore-test.sh
fi
if [[ ${EVO_RESTORE_SERVER_TEST:-0} == 1 ]]; then
  exec "${BWRAP[@]}" /bin/busybox sh /lab/evo-x86-restore-server-test.sh
fi
if [[ ${EVO_FACTORY_RESET_TEST:-0} == 1 ]]; then
  exec "${BWRAP[@]}" /bin/busybox sh /lab/evo-x86-factory-reset-test.sh
fi
if [[ ${EVO_DEBUG_BACKUP_TEST:-0} == 1 ]]; then
  exec "${BWRAP[@]}" /bin/busybox sh /lab/evo-x86-debug-backup-test.sh
fi
if [[ ${EVO_DEBUG_RESTORE_TEST:-0} == 1 ]]; then
  exec "${BWRAP[@]}" /bin/busybox sh /lab/evo-x86-debug-restore-test.sh
fi
if [[ ${EVO_DOWNLOAD_TEST:-0} == 1 ]]; then
  exec "${BWRAP[@]}" /bin/busybox sh /lab/evo-x86-download-test.sh
fi
if [[ ${EVO_EXPORTPARS_TEST:-0} == 1 ]]; then
  exec "${BWRAP[@]}" /bin/busybox sh /lab/evo-x86-exportpars-test.sh
fi
if [[ ${EVO_RESTORE_PASSWORD_TEST:-0} == 1 ]]; then
  exec "${BWRAP[@]}" /bin/busybox sh /lab/evo-x86-restore-password-test.sh
fi
if [[ ${EVO_BACKUP_PASSWORD_TEST:-0} == 1 ]]; then
  exec "${BWRAP[@]}" /bin/busybox sh /lab/evo-x86-backup-password-test.sh
fi

exec "${BWRAP[@]}" /usr/bin/qemu-i386 -L / /usr/sbin/lighttpd \
  -f /etc/lighttpd/lighttpd.conf -D
