#!/bin/sh
set -eu

BASE=http://127.0.0.1:18080/cgi-bin
SERVER_PID=

cleanup() {
  set +e
  /bin/busybox wget -qO- -T 5 -t 1 --post-data 'action=set&content={"model_type":"XWEB3000","CPF":"LOCALTEST"}' "$BASE/config.lua" >/dev/null
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null
    wait "$SERVER_PID" 2>/dev/null
  fi
}
trap cleanup EXIT INT TERM

post() {
  /bin/busybox wget -qO- -T 5 -t 1 --post-data "$1" "$BASE/$2"
}

/usr/bin/qemu-arm -L /opt/evo-compat/sysroot /usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -D &
SERVER_PID=$!
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  if SYSINFO=$(/bin/busybox wget -qO- -T 5 -t 1 "$BASE/sysinfo.lua"); then
    break
  fi
  sleep 1
done
case "$SYSINFO" in
  *'"status":"ok"'*'"release":"5.8.8.STANDARD.24--25902d"'*) ;;
  *) echo "FAIL sysinfo: $SYSINFO"; exit 1;;
esac
echo "PASS sysinfo unauthenticated release=5.8.8.STANDARD.24--25902d"

SET_RESPONSE=$(post 'action=set&content={"model_type":"XWEB3000","CPF":"LOCALTEST","lab_canary":"ARM_CONFIG"}' config.lua)
case "$SET_RESPONSE" in
  *'"status":"ok"'*) ;;
  *) echo "FAIL config set: $SET_RESPONSE"; exit 1;;
esac
GET_RESPONSE=$(post 'action=get' config.lua)
case "$GET_RESPONSE" in
  *'"lab_canary":"ARM_CONFIG"'*) ;;
  *) echo "FAIL config readback: $GET_RESPONSE"; exit 1;;
esac
echo "PASS unauthenticated config write/read"

RESTORE_RESPONSE=$(post 'action=set&content={"model_type":"XWEB3000","CPF":"LOCALTEST"}' config.lua)
FINAL_RESPONSE=$(post 'action=get' config.lua)
case "$FINAL_RESPONSE" in
  *'"lab_canary"'*) echo "FAIL marker remains: $FINAL_RESPONSE"; exit 1;;
  *'"CPF":"LOCALTEST"'*) ;;
  *) echo "FAIL restore: $FINAL_RESPONSE"; exit 1;;
esac
echo "PASS original config restored"
echo "overall: PASS"
