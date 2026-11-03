#!/usr/bin/env python3
"""Recover XWEB EVO RPMs and XML descriptors from official update archives."""

import argparse
import gzip
import lzma
import zipfile
from pathlib import Path

XML_PREFIX = b'<?xml version="1.0" encoding="UTF-8"?>'
RPM_MAGIC = b"\xed\xab\xee\xdb"
XZ_MAGIC = b"\xfd7zXZ\x00"
GZIP_MAGIC = b"\x1f\x8b\x08"


def xor_period(data, key):
    return bytes(value ^ key[index % len(key)] for index, value in enumerate(data))


def derive_key(name):
    key = bytearray([0xA1] * 20)
    for index, byte in enumerate(name.encode("ascii")[:20]):
        key[index] ^= byte
    return bytes(key)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.archive) as archive:
        for info in archive.infolist():
            if info.is_dir():
                continue
            name = Path(info.filename).name
            encrypted = archive.read(info)
            if name.endswith(".rpm"):
                package_name = name.removesuffix(".i686.rpm").removesuffix(".rpm")
                plaintext = xor_period(encrypted, derive_key(package_name))
                if not plaintext.startswith(RPM_MAGIC):
                    raise ValueError(f"invalid RPM header in {name}")
                xz_offset = plaintext.find(XZ_MAGIC, 96)
                gzip_offset = plaintext.find(GZIP_MAGIC, 96)
                offsets = [(offset, lzma.decompress) for offset in [xz_offset] if offset >= 0]
                offsets += [(offset, gzip.decompress) for offset in [gzip_offset] if offset >= 0]
                if not offsets:
                    raise ValueError(f"no xz or gzip payload in {name}")
                offset, decompress = min(offsets, key=lambda item: item[0])
                payload = decompress(plaintext[offset:])
                if not payload.startswith((b"070701", b"070702")):
                    raise ValueError(f"invalid cpio payload in {name}")
                (args.output / name).write_bytes(plaintext)
                (args.output / (Path(name).stem + ".cpio")).write_bytes(payload)
                print(f"OK {name}: {len(plaintext)} bytes, {len(payload)}-byte cpio")
            elif name in ("evopack", "epkginfo"):
                key = bytes(value ^ known for value, known in zip(encrypted, XML_PREFIX))[:20]
                plaintext = xor_period(encrypted, key)
                if not plaintext.startswith(XML_PREFIX + b"\n<content>") or not plaintext.rstrip().endswith(b"</content>"):
                    raise ValueError(f"invalid XML descriptor in {name}")
                (args.output / name).write_bytes(encrypted)
                (args.output / (name + ".decrypted.xml")).write_bytes(plaintext)
                print(f"OK {name}: {len(plaintext)}-byte XML, key {key.hex()}")
            else:
                (args.output / name).write_bytes(encrypted)


if __name__ == "__main__":
    main()
