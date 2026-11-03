#!/bin/sh
set -eu

BASE=http://127.0.0.1:18082/cgi-bin
AUTH=
SERVER_PID=

cleanup() {
  set +e
  if [ -n "$AUTH" ]; then
    rm -f "/dev/shm/usp_$AUTH"
    rm -rf "/opt/tmp/$AUTH"
  fi
  rm -rf /opt/setup/users/1 /opt/setup/profiles/0
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null
    wait "$SERVER_PID" 2>/dev/null
  fi
}
trap cleanup EXIT INT TERM

post() {
  /bin/busybox wget -qO- --post-data "$1" "$BASE/$2"
}

mkdir -p /opt/setup/users/1 /opt/setup/profiles/0
cp /lab/fixtures/factory-user-config.json /opt/setup/users/1/config.json
cp /lab/fixtures/factory-profile-config.json /opt/setup/profiles/0/config.json
cp /lab/fixtures/factory-profile-permissions.json /opt/setup/profiles/0/permissions.json
cp /lab/fixtures/factory-profile-layout.json /opt/setup/profiles/0/layout.json
touch /opt/setup/users/1/Admin /opt/setup/profiles/0/superadmin
/usr/bin/qemu-i386 -L / /usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -D &
SERVER_PID=$!

for attempt in 1 2 3 4 5 6 7 8 9 10; do
  if /bin/busybox wget -qO- "$BASE/sysinfo.lua" >/dev/null; then
    break
  fi
  sleep 1
done

LIST_RESPONSE=$(post 'action=list' users.lua)
case "$LIST_RESPONSE" in
  *'"error":"PERMISSION_DENIED"'*) ;;
  *) echo "FAIL unauthenticated list control: $LIST_RESPONSE"; exit 1;;
esac
echo "PASS unauthenticated list denied"

BEFORE=$(cat /opt/setup/users/1/config.json)
RESET_RESPONSE=$(post 'action=update_password&id=1&password=ResetCanary1' users.lua)
case "$RESET_RESPONSE" in
  *'"status":"ok"'*) ;;
  *) echo "FAIL factory reset: $RESET_RESPONSE"; exit 1;;
esac
echo "PASS unauthenticated factory reset"

AUTH_RESPONSE=$(post 'action=authenticate&username=Admin&password=ResetCanary1' api.lua)
case "$AUTH_RESPONSE" in
  *'"status":"ok"'*'"auth":"SSES'*) ;;
  *) echo "FAIL new password authentication: $AUTH_RESPONSE"; exit 1;;
esac
AUTH=${AUTH_RESPONSE#*\"auth\":\"}
AUTH=${AUTH%%\"*}
echo "PASS new superadmin password authentication"

AFTER=$(cat /opt/setup/users/1/config.json)
case "$AFTER" in
  *'"password_expiration":-1'*) ;;
  *) echo "FAIL expiration not cleared: $AFTER"; exit 1;;
esac
[ "$BEFORE" != "$AFTER" ] || { echo "FAIL hash/config unchanged"; exit 1; }
echo "PASS expiration and password hash updated"

NEGATIVE_RESPONSE=$(post 'action=update_password&id=1&password=ResetCanary2' users.lua)
case "$NEGATIVE_RESPONSE" in
  *'"error":"PERMISSION_DENIED"'*) ;;
  *) echo "FAIL normal-state control: $NEGATIVE_RESPONSE"; exit 1;;
esac
echo "PASS normal-state reset denied"

MISSING_RESPONSE=$(post 'action=update_password&id=999&password=ResetCanary2' users.lua)
case "$MISSING_RESPONSE" in
  *'"error":"EXECUTION_ERROR"'*) ;;
  *) echo "FAIL missing-id control: $MISSING_RESPONSE"; exit 1;;
esac
echo "PASS missing-id control"
echo "overall: PASS"
