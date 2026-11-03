#!/usr/bin/env python3
"""Extract GETFILE records from decoded XWEB300UF/XWEB500UF archives."""

import argparse
import hashlib
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--json", type=Path)
    args = parser.parse_args()
    data = args.input.read_bytes()
    if not data.startswith((b"XWEB300UF\n", b"XWEB500UF\n")):
        raise ValueError("not a decoded XWEB UF archive")
    marker = b"GETFILE|"
    terminator = b"\nEFI300IFE300!\n"
    position = 0
    records = []
    while True:
        start = data.find(marker, position)
        if start < 0:
            break
        header_end = data.index(b"\n", start)
        path, size_text = data[start + len(marker):header_end - 1].rsplit(b"|", 1)
        size = int(size_text)
        content_start = header_end + 1
        content_end = content_start + size
        if content_end + len(terminator) > len(data):
            raise ValueError("truncated GETFILE record")
        content = data[content_start:content_end]
        if data[content_end:content_end + len(terminator)] != terminator:
            raise ValueError("invalid GETFILE terminator")
        name = path.decode("ascii")
        relative = Path(name.lstrip("/"))
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError(f"unsafe archive path: {name}")
        output = args.output / relative
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(content)
        records.append({"path": name, "size": size, "sha256": hashlib.sha256(content).hexdigest()})
        position = content_end + len(terminator)
    result = {"input": str(args.input), "output": str(args.output),
              "records": len(records), "files": records}
    args.output.mkdir(parents=True, exist_ok=True)
    if args.json:
        args.json.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"records": len(records), "output": str(args.output)}))


if __name__ == "__main__":
    main()
