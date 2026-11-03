#!/bin/sh
set -eu

BASE=http://127.0.0.1:18082/cgi-bin
CANARY=/opt/setup/templates/debug-backup-canary
AUTH=
SERVER_PID=

cleanup() {
  set +e
  rm -f "$CANARY"
  if [ -n "$AUTH" ]; then
    rm -f "/dev/shm/usp_$AUTH"
    rm -rf "/opt/tmp/$AUTH" "/media/backup_isto_$AUTH"
  fi
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null
    wait "$SERVER_PID" 2>/dev/null
  fi
}
trap cleanup EXIT INT TERM

post() {
  /bin/busybox wget -qO- --post-data "$1" "$BASE/$2"
}

rm -f "$CANARY"
/usr/bin/qemu-i386 -L / /usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -D &
SERVER_PID=$!
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  if /bin/busybox wget -qO- "$BASE/sysinfo.lua" >/dev/null; then
    break
  fi
  sleep 1
done

DENIED=$(post 'action=backup_isto&device=x' debug.lua)
case "$DENIED" in
  *'"error":"PERMISSION_DENIED"'*) ;;
  *) echo "FAIL no-session control: $DENIED"; exit 1;;
esac
echo "PASS backup_isto requires Administrator session"

AUTH_RESPONSE=$(post 'action=authenticate&username=Administrator&password=O0ANI3' api.lua)
case "$AUTH_RESPONSE" in
  *'"status":"ok"'*'"auth":"SSES'*) ;;
  *) echo "FAIL Administrator authentication: $AUTH_RESPONSE"; exit 1;;
esac
AUTH=${AUTH_RESPONSE#*\"auth\":\"}
AUTH=${AUTH%%\"*}
echo "PASS Administrator authentication"

PAYLOAD='x";printf DEBUG_BACKUP_CANARY>/opt/setup/templates/debug-backup-canary;#'
RESPONSE=$(post "action=backup_isto&device=$PAYLOAD&SSES=$AUTH" debug.lua)
echo "backup_isto response after expected mount failure: $RESPONSE"
[ "$(cat "$CANARY")" = "DEBUG_BACKUP_CANARY" ] || { echo "FAIL command canary"; exit 1; }
echo "PASS backup_isto device command canary"
echo "overall: PASS"
