#!/usr/bin/env python3
"""Tao hotupdate_manifest.txt tu thu muc android/media.

Chay moi khi sua/them/xoa file trong android/media, roi commit + push:
    python3 tools/make_manifest.py
    git add -A && git commit -m "update" && git push

Dinh dang manifest:
    V <phien ban>
    F <kich thuoc> <crc32 hex> <duong dan tuong doi voi android/media>
    D <duong dan can xoa>             (lay tu deleted.txt)
"""
import os, sys, time, zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MEDIA = os.path.join(ROOT, "android", "media")
ALLOW = ("src/", "res/")          # phai khop M.allow_prefix trong HotUpdate.lua
MAX_BYTES = 24 * 1024 * 1024      # phai khop M.max_file_bytes

def ok_path(p):
    if not p.startswith(ALLOW) or ".." in p or "\\" in p or "//" in p or len(p) > 240:
        return False
    if any(ord(c) < 32 or c in ':*?"<>|' for c in p):
        return False
    if p.startswith("src/client/offline/seed/") and p.endswith(".txt"):
        return False      # file trang thai do game tu sinh ra: khong cap nhat de
    if p.endswith(".tmp"):
        return False
    return True

def crc32_hex(path):
    c = 0
    with open(path, "rb") as f:
        while True:
            b = f.read(1 << 20)
            if not b:
                break
            c = zlib.crc32(b, c)
    return "%08x" % (c & 0xFFFFFFFF)

def main():
    version = sys.argv[1] if len(sys.argv) > 1 else time.strftime("%Y%m%d.%H%M%S", time.gmtime())
    lines, skipped = [], []
    for base, _, files in os.walk(MEDIA):
        for name in files:
            full = os.path.join(base, name)
            rel = os.path.relpath(full, MEDIA).replace(os.sep, "/")
            size = os.path.getsize(full)
            if not ok_path(rel) or size > MAX_BYTES:
                skipped.append(rel)
                continue
            lines.append((rel, size, crc32_hex(full)))
    lines.sort()
    out = ["V " + version]
    out += ["F %d %s %s" % (s, c, p) for p, s, c in lines]
    dpath = os.path.join(ROOT, "deleted.txt")
    n_del = 0
    if os.path.exists(dpath):
        for ln in open(dpath, encoding="utf-8"):
            ln = ln.strip()
            if ln and not ln.startswith("#") and ok_path(ln):
                out.append("D " + ln)
                n_del += 1
    with open(os.path.join(ROOT, "hotupdate_manifest.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    print("phien ban %s: %d file, %d xoa, bo qua %d" % (version, len(lines), n_del, len(skipped)))
    for p in skipped:
        print("  bo qua:", p)

if __name__ == "__main__":
    main()
