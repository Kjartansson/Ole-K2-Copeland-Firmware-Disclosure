#!/usr/bin/env python3
"""Decode plaintext or XOR-protected legacy XWEB2009 upload-channel RPMs."""

import argparse
import hashlib
import json
import re
import zipfile
import zlib
from pathlib import Path

BASE_KEY = bytes.fromhex("f9 f6 e4 e3 93 91 91 98 8c d1 c0 d5 c2 c9 8c 95 8f 91 8f 90")
RPM_MAGIC = b"\xed\xab\xee\xdb"
GZIP_MAGIC = b"\x1f\x8b\x08"


def key_for(name):
    key = bytearray(BASE_KEY)
    match = re.search(r"XWEB2009-patch-4\.0\.(\d+)", name)
    if match:
        minor = int(match.group(1))
        if minor < 10:
            key[-1] ^= minor ^ 1
    elif "XWEB2009-patch-4.0.b1" in name:
        key[-1] = 0xC3
    return bytes(key)


def validate_newc(payload):
    position = 0
    entries = 0
    while True:
        if position + 110 > len(payload) or payload[position:position + 6] not in (b"070701", b"070702"):
            raise ValueError("invalid or truncated newc cpio header")
        try:
            fields = [int(payload[position + 6 + index * 8:position + 14 + index * 8], 16) for index in range(13)]
        except ValueError as error:
            raise ValueError("invalid newc cpio header field") from error
        file_size, name_size = fields[6], fields[11]
        name_start = position + 110
        name_end = name_start + name_size
        if not name_size or name_end > len(payload) or payload[name_end - 1] != 0:
            raise ValueError("invalid newc cpio pathname")
        name = payload[name_start:name_end - 1]
        data_start = (name_end + 3) & ~3
        data_end = data_start + file_size
        if data_end > len(payload):
            raise ValueError("truncated newc cpio file data")
        position = (data_end + 3) & ~3
        if name == b"TRAILER!!!":
            return entries
        entries += 1


def decode_rpm(name, encrypted):
    key = key_for(name)
    if encrypted.startswith(RPM_MAGIC):
        plaintext, transform, key_hex = encrypted, "none", None
    else:
        plaintext = bytes(value ^ key[index % len(key)] for index, value in enumerate(encrypted))
        transform, key_hex = "xor", key.hex()
    payload_offset = plaintext.find(GZIP_MAGIC, 96)
    if not plaintext.startswith(RPM_MAGIC) or payload_offset < 0:
        raise ValueError("RPM header or payload offset is invalid")
    decoder = zlib.decompressobj(16 + zlib.MAX_WBITS)
    payload = decoder.decompress(plaintext[payload_offset:]) + decoder.flush()
    if not decoder.eof:
        raise ValueError("gzip payload is incomplete")
    if decoder.unused_data.strip(b"\0"):
        raise ValueError("unexpected data after gzip payload")
    entries = validate_newc(payload)
    return plaintext, payload_offset, payload, transform, key_hex, entries


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    manifest = {"archive": str(args.archive), "files": [], "skipped": []}
    with zipfile.ZipFile(args.archive) as archive:
        for info in archive.infolist():
            if info.is_dir():
                continue
            name = Path(info.filename).name
            encrypted = archive.read(info)
            if not name.endswith(".rpm"):
                (args.output / name).write_bytes(encrypted)
                continue
            output_path = args.output / name
            try:
                plaintext, payload_offset, payload, transform, key_hex, entries = decode_rpm(name, encrypted)
            except (ValueError, zlib.error) as error:
                output_path.unlink(missing_ok=True)
                manifest["skipped"].append({"name": name, "reason": str(error)})
                print(f"SKIP {name}: {error}")
                continue
            output_path.write_bytes(plaintext)
            record = {
                "name": name,
                "size": len(plaintext),
                "sha256": hashlib.sha256(plaintext).hexdigest(),
                "transform": transform,
                "key_hex": key_hex,
                "payload_offset": payload_offset,
                "cpio_size": len(payload),
                "cpio_entries": entries,
            }
            manifest["files"].append(record)
            print(f"OK {name}: {transform}, {len(plaintext)} bytes, {len(payload)}-byte cpio, {entries} entries")
    (args.output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Decoded {len(manifest['files'])} RPMs; skipped {len(manifest['skipped'])}")


if __name__ == "__main__":
    main()
