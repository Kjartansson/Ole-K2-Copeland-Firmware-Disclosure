#!/bin/sh
set -eu

BASE=http://127.0.0.1:18082/cgi-bin
FILE_ID=b57cd8ab24a68f529b528d4d132937d5
CANARY=/opt/setup/templates/evo-restore-canary
AUTH=
SERVER_PID=

cleanup() {
  set +e
  rm -f "$CANARY" /dev/shm/evobk.lock /dev/shm/.r
  if [ -n "$AUTH" ]; then
    rm -f "/dev/shm/usp_$AUTH"
    rm -rf "/opt/tmp/$AUTH"
  fi
  rm -rf /opt/setup/users/1 /opt/setup/profiles/7
  cp /lab/fixtures/lighttpd-custom.conf /etc/lighttpd/lighttpd-custom.conf
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null
    wait "$SERVER_PID" 2>/dev/null
  fi
}
trap cleanup EXIT INT TERM

post() {
  /bin/busybox wget -qO- --post-data "$1" "$BASE/api.lua"
}

rm -f "$CANARY" /dev/shm/evobk.lock /dev/shm/.r
mkdir -p /opt/setup/users/1 /opt/setup/profiles/7
cp /lab/fixtures/restore-user-config.json /opt/setup/users/1/config.json
cp /lab/fixtures/restore-profile-config.json /opt/setup/profiles/7/config.json
cp /lab/fixtures/restore-profile-permissions.json /opt/setup/profiles/7/permissions.json
cp /lab/fixtures/restore-profile-layout.json /opt/setup/profiles/7/layout.json
touch /opt/setup/users/1/RestoreOnly /opt/setup/profiles/7/RestoreOnly
if [[ ${EVO_DEBUG_CGI:-0} == 1 ]]; then
  /usr/bin/qemu-i386 -L / /usr/bin/lua /opt/xweb/www/cgi-bin/sysinfo.lua
fi
/usr/bin/qemu-i386 -L / /usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf -D &
SERVER_PID=$!

SYSINFO=
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  if SYSINFO=$(/bin/busybox wget -qO- "$BASE/sysinfo.lua"); then
    break
  fi
  sleep 1
done
case "$SYSINFO" in
  *'"status":"ok"'*'"release":"5.8.7.STANDARD.23--f27c2a"'*) ;;
  *) echo "FAIL sysinfo: $SYSINFO"; exit 1;;
esac
echo "PASS sysinfo unauthenticated release=5.8.7.STANDARD.23--f27c2a"

AUTH_RESPONSE=$(post 'action=authenticate&username=RestoreOnly&password=restoreprobe')
case "$AUTH_RESPONSE" in
  *'"status":"ok"'*'"auth":"SSES'*) ;;
  *) echo "FAIL authenticate: $AUTH_RESPONSE"; exit 1;;
esac
AUTH=${AUTH_RESPONSE#*\"auth\":\"}
AUTH=${AUTH%%\"*}
echo "PASS restore-only authentication"

RESTORE_RESPONSE=$(post "action=restore&auth=$AUTH&sections=%5B%22data%22%5D&input=system&system_filename=$FILE_ID")
echo "restore response: $RESTORE_RESPONSE"
case "$RESTORE_RESPONSE" in
  *'"status":"ok"'*'"reboot":true'*) ;;
  *) echo "FAIL restore"; exit 1;;
esac
[ "$(cat "$CANARY")" = "EVO_RESTORE_CANARY" ] || { echo "FAIL canary"; exit 1; }
echo "PASS member-name command canary"

BACKUP_RESPONSE=$(post "action=backup&auth=$AUTH&sections=%5B%22data%22%5D&output=system")
case "$BACKUP_RESPONSE" in
  *'"error":"PERMISSION_DENIED"'*) ;;
  *) echo "FAIL backup negative control: $BACKUP_RESPONSE"; exit 1;;
esac
echo "PASS backup denied to restore-only profile"
echo "overall: PASS"
