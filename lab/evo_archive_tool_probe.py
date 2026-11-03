#!/usr/bin/env python3
import io
import stat
import subprocess
import tarfile
import tempfile
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
QEMU = "/usr/bin/qemu-i386"
ROOTFS = REPO / "build/evo-x86-rootfs"
BUSYBOX = ROOTFS / "bin/busybox"


def extract(kind, archive, output):
    if kind == "zip":
        args = ["unzip", "-qqo", str(archive), "-d", str(output)]
    else:
        args = ["tar", "--extract", "--overwrite", f"--directory={output}", f"--file={archive}"]
    result = subprocess.run(
        [QEMU, "-L", str(ROOTFS), str(BUSYBOX), *args],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    return result.stdout.strip()


def plain_archive(kind, base):
    archive = base / f"plain.{kind}"
    names = [f"../{kind}-escape.txt", str(base / f"absolute-{kind}-escape.txt")]
    if kind == "zip":
        with zipfile.ZipFile(archive, "w") as container:
            for name in names:
                container.writestr(name, "PLAIN_CANARY")
    else:
        with tarfile.open(archive, "w") as container:
            for name in names:
                data = b"PLAIN_CANARY"
                info = tarfile.TarInfo(name)
                info.size = len(data)
                container.addfile(info, io.BytesIO(data))
    return archive, names


def symlink_archive(kind, base):
    archive = base / f"symlink.{kind}"
    member = f"link/symlink-{kind}-escape.txt"
    if kind == "zip":
        with zipfile.ZipFile(archive, "w") as container:
            link = zipfile.ZipInfo("link")
            link.create_system = 3
            link.external_attr = (stat.S_IFLNK | 0o777) << 16
            container.writestr(link, "..")
            container.writestr(member, "SYMLINK_CANARY")
    else:
        with tarfile.open(archive, "w") as container:
            link = tarfile.TarInfo("link")
            link.type = tarfile.SYMTYPE
            link.linkname = ".."
            container.addfile(link)
            data = b"SYMLINK_CANARY"
            info = tarfile.TarInfo(member)
            info.size = len(data)
            container.addfile(info, io.BytesIO(data))
    return archive, member


def main():
    with tempfile.TemporaryDirectory(prefix="evo-archive-probe-", dir=REPO / "build") as tmp:
        base = Path(tmp)
        for kind in ("zip", "tar"):
            output = base / f"{kind}-root"
            output.mkdir()
            archive, names = plain_archive(kind, base)
            log = extract(kind, archive, output)
            print(f"{kind} plain: {log}")
            assert (output / f"{kind}-escape.txt").read_text() == "PLAIN_CANARY"
            assert (output / names[1].lstrip("/")).read_text() == "PLAIN_CANARY"
            assert not (base / f"{kind}-escape.txt").exists()
            assert not (base / f"absolute-{kind}-escape.txt").exists()
            print(f"PASS {kind} plain and absolute members contained")

            output = base / f"{kind}-symlink-root"
            output.mkdir()
            archive, member = symlink_archive(kind, base)
            log = extract(kind, archive, output)
            print(f"{kind} symlink: {log}")
            link = output / "link"
            assert link.is_dir() and not link.is_symlink()
            assert (output / member).read_text() == "SYMLINK_CANARY"
            assert not (base / f"symlink-{kind}-escape.txt").exists()
            print(f"PASS {kind} symlink member contained")
    print("overall: PASS")


if __name__ == "__main__":
    main()
