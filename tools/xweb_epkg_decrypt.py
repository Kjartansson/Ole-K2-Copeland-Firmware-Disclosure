#!/usr/bin/env python3
"""Decrypt an XWEB EVO .epkg using the updater's package-name key rule."""

import argparse
import hashlib
import json
from pathlib import Path


def derive_key(name):
    key = bytearray([0xA1] * 20)
    for index, byte in enumerate(name.encode("ascii")[:20]):
        key[index] ^= byte
    return bytes(key)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--json", type=Path)
    args = parser.parse_args()
    ciphertext = args.input.read_bytes()
    key = derive_key(args.input.stem)
    plaintext = bytes(byte ^ key[index % 20] for index, byte in enumerate(ciphertext))
    if plaintext.startswith(b"#!/bin/sh"):
        container = "shell"
        if b"\x1f\x8b\x08" not in plaintext:
            raise ValueError("shell installer has no embedded gzip payload")
    elif plaintext.startswith(b"hsqs"):
        container = "squashfs-le"
        if len(plaintext) < 96:
            raise ValueError("truncated SquashFS output")
    else:
        raise ValueError(f"decoded output has no supported magic: {plaintext[:16].hex()}")
    args.output.write_bytes(plaintext)
    result = {
        "input": str(args.input),
        "output": str(args.output),
        "package_name": args.input.stem,
        "key_hex": key.hex(),
        "key_rule": "20 bytes 0xa1, XOR package-name bytes, repeat",
        "container": container,
        "size": len(plaintext),
        "sha256": hashlib.sha256(plaintext).hexdigest(),
    }
    if args.json:
        args.json.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
