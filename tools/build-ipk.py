#!/usr/bin/env python3
"""Build a webOS .ipk in the exact layout ares-package produces.

webOS's pkgVerifier uses a classic SysV ar parser, which chokes on GNU `ar -r`
output (trailing '/' in names, zero mtime, mode without leading 0). We emit
member headers with space-padded names, real mtime, and octal mode "100644",
matching org.webosbrew.hbchannel_0.7.3_all.ipk byte-for-byte in structure.
"""
import io
import json
import os
import tarfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
PKG = os.path.join(ROOT, "pkg")
APP = "org.webosbrew.regionchanger"
VER = "1.0.2"
OUT = os.path.join(ROOT, f"{APP}_{VER}_all.ipk")

WANTED_UID = 1001   # ares-package runs tar as the "ares" dev user (1001)
WANTED_GID = 1001
MTIME = int(time.time())


def set_owner(ti):
    ti.uid = WANTED_UID
    ti.gid = WANTED_GID
    ti.uname = "1001"
    ti.gname = "1001"
    ti.mtime = MTIME
    if ti.isdir():
        ti.mode = 0o777
    else:
        ti.mode = 0o644
    return ti


def make_control(addroot):
    size = 0
    for cur, _, files in os.walk(os.path.join(PKG, "usr")):
        for f in files:
            size += os.path.getsize(os.path.join(cur, f))
            size += 512  # loose approximation ares uses
    control = (
        f"Package: {APP}\n"
        f"Version: {VER}\n"
        "Section: misc\n"
        "Priority: optional\n"
        "Architecture: all\n"
        f"Installed-Size: {size}\n"
        "Maintainer: N/A <nobody@example.com>\n"
        "Description: This is a webOS application.\n"
        "webOS-Package-Format-Version: 2\n"
        "webOS-Packager-Version: x.y.x\n"
    )
    addroot(control)
    return control


def tar_bytes(members):
    bio = io.BytesIO()
    with tarfile.open(fileobj=bio, mode="w:gz", format=tarfile.GNU_FORMAT) as t:
        for path, arcname, isfile, data in members:
            if isfile:
                info = tarfile.TarInfo(arcname)
                info.size = len(data)
                info.mode = 0o644
            else:
                info = tarfile.TarInfo(arcname)
                info.type = tarfile.DIRTYPE
                info.mode = 0o777
            info.uid, info.gid = WANTED_UID, WANTED_GID
            info.mtime = MTIME
            info.uname = info.gname = "1001"
            t.addfile(info, io.BytesIO(data) if isfile else None)
    return bio.getvalue()


def collect_data():
    members = []
    base = os.path.join(PKG, "usr")
    for cur, dirs, files in os.walk(base):
        rel = os.path.relpath(cur, PKG)
        # always include chain of dirs up to "usr"
        for d in (rel, rel):
            pass
        members.append(("", rel, False, b""))  # the dir itself (with trailing / implicit)
        for f in files:
            p = os.path.join(cur, f)
            members.append((cur if False else p, os.path.relpath(p, PKG), True, open(p, "rb").read()))
    # ensure "usr" dir entries are emitted for every ancestor
    return members


def ar_header(name, mtime, size):
    def pad(field, width):
        if len(field) > width:
            field = field[:width]
        return field.ljust(width, " ")

    return (
        pad(name, 16)
        + pad(str(mtime), 12)
        + pad("0", 6)
        + pad("0", 6)
        + pad("100644", 8)
        + pad(str(size), 10)
        + "`\n"
    ).encode("ascii")


def main():
    control_content = make_control(lambda c: None)
    control_tgz = tar_bytes([("", "control", True, control_content.encode("utf-8"))])

    data_members = []
    base = os.path.join(PKG, "usr")
    for cur, dirs, files in os.walk(base):
        rel = os.path.relpath(cur, PKG)
        data_members.append(("", rel, False, b""))
        for f in sorted(files):
            p = os.path.join(cur, f)
            arc = os.path.relpath(p, PKG)
            with open(p, "rb") as fh:
                data_members.append((p, arc, True, fh.read()))
    data_tgz = tar_bytes(data_members)

    debian_binary = b"2.0\n"
    now = int(time.time())

    out = io.BytesIO()
    out.write(b"!<arch>\n")
    for name, blob in (("debian-binary", debian_binary),
                       ("control.tar.gz", control_tgz),
                       ("data.tar.gz", data_tgz)):
        out.write(ar_header(name, now, len(blob)))
        out.write(blob)
        if len(blob) % 2:
            out.write(b"\n")

    with open(OUT, "wb") as f:
        f.write(out.getvalue())

    print(f"Built: {OUT}")
    print(f"  size : {len(out.getvalue())} bytes")
    print(f"  ar   : debian-binary / control.tar.gz / data.tar.gz")


if __name__ == "__main__":
    main()