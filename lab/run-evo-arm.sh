#!/usr/bin/env bash
set -euo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ROOT="$REPO/build/evo-rootfs"
RUN="$REPO/build/evo-runtime"
CROSS="$REPO/build/evo-lab/root"
QEMU=${QEMU_ARM:-/usr/bin/qemu-arm}

[[ -x "$ROOT/usr/sbin/lighttpd" ]] || { echo "missing derived ARM rootfs" >&2; exit 1; }
[[ -x "$QEMU" ]] || { echo "missing qemu-arm: $QEMU" >&2; exit 1; }

BWRAP=(bwrap
  --unshare-net --unshare-pid --unshare-uts --unshare-ipc --die-with-parent
  --bind "$ROOT" /
  --ro-bind "$CROSS/lib" /lib
  --ro-bind "$ROOT/bin/busybox" /bin/sleep
  --ro-bind "$QEMU" /usr/bin/qemu-arm
  --dir /opt/evo-compat
  --dir /opt/evo-compat/sysroot
  --dir /opt/evo-compat/sysroot/lib
  --ro-bind "$CROSS/lib/ld-linux.so.3" /opt/evo-compat/sysroot/lib/ld-linux.so.3
  --ro-bind "$REPO/build/evo-lua-arm/compat" /opt/evo-compat/compat
  --ro-bind "$REPO/build/evo-lua-arm/root/lib/arm-linux-gnueabi" /opt/evo-compat/lib
  --ro-bind "$REPO/build/evo-lua-arm/root/usr/lib/arm-linux-gnueabi" /opt/evo-compat/usr-lib
  --ro-bind "$REPO/build/evo-lua-arm/root/usr/bin/lua5.1" /usr/bin/lua
  --dir /opt/evo-compat/lua
  --ro-bind "$REPO/build/evo-lua-arm/root/usr/lib/arm-linux-gnueabi/liblua5.1-cjson.so.0.0.0" /opt/evo-compat/lua/cjson.so
  --ro-bind "$REPO/build/evo-lua-arm/root/usr/lib/arm-linux-gnueabi/liblua5.1-filesystem.so.0.0.0" /opt/evo-compat/lua/lfs.so
  --ro-bind "$REPO/build/evo-lua-arm/root/usr/lib/arm-linux-gnueabi/liblua5.1-sql-sqlite3.so.2.0.0" /opt/evo-compat/lua/lsqlite3.so
  --setenv LD_LIBRARY_PATH /opt/evo-compat/compat:/opt/evo-compat/lib:/opt/evo-compat/usr-lib:/lib:/usr/lib
  --setenv LUA_CPATH '/opt/evo-compat/lua/?.so;;'
  --setenv QEMU_LD_PREFIX /opt/evo-compat/sysroot
  --proc /proc --dev /dev
  --bind "$RUN/opt-tmp" /opt/tmp
  --bind "$RUN/shm" /dev/shm
  --bind "$RUN/tmp" /tmp
  --bind "$RUN/var-log" /var/log
  --bind "$RUN/var-run" /var/run
  --bind "$RUN/lighttpd-custom.conf" /etc/lighttpd/lighttpd-custom.conf
  --bind "$RUN/xwebconfig.json" /etc/xwebconfig.json
  --bind "$RUN/xwpasswd" /opt/xweb/bin/tools/xwpasswd
  --bind "$RUN/curl" /usr/bin/curl
  --bind "$RUN/ip" /usr/bin/ip
  --ro-bind "$REPO/lab" /lab
  --setenv PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/xweb/bin/tools
)

if [[ ${EVO_CONFIG_TEST:-0} == 1 ]]; then
  exec "${BWRAP[@]}" /bin/busybox sh /lab/evo-arm-config-test.sh
fi
if [[ ${EVO_RESTORE_SERVER_TEST:-0} == 1 ]]; then
  exec "${BWRAP[@]}" /bin/busybox sh /lab/evo-arm-restore-server-test.sh
fi

exec "${BWRAP[@]}" /usr/bin/qemu-arm -L /opt/evo-compat/sysroot /usr/sbin/lighttpd \
  -f /etc/lighttpd/lighttpd.conf -D
