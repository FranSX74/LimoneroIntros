#!/usr/bin/env python3
"""Vista previa PNG de la fuente amarilla: python3 tools/preview_font.py salida.png [TEXTO ...]"""
import sys, zlib, struct, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))
from font_yellow import FONT7
S = 8
def render(lines):
    rows = []
    for ln in lines:
        pix = [[] for _ in range(7)]
        for ch in ln:
            gl = FONT7[ch]
            for r in range(7): pix[r] += [c == '#' for c in gl[r]] + [False]
        rows.append(pix)
    wmax = max(len(p[0]) for p in rows); H = sum(7+3 for _ in rows)+3
    img = [[False]*(wmax+4) for _ in range(H)]
    y = 3
    for p in rows:
        for r in range(7):
            for x, v in enumerate(p[r]): img[y+r][x+2] = v
        y += 10
    return img
def png(img, path):
    h, w = len(img), len(img[0]); raw = b""
    for row in img:
        line = b"".join((b"\xe7\xdc\x44" if v else b"\x04\x0b\x02")*S for v in row)
        raw += (b"\x00"+line)*S
    def ch(t, d): return struct.pack(">I", len(d))+t+d+struct.pack(">I", zlib.crc32(t+d) & 0xffffffff)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n"+ch(b"IHDR", struct.pack(">IIBBBBB", w*S, h*S, 8, 2, 0, 0, 0))+ch(b"IDAT", zlib.compress(raw))+ch(b"IEND", b""))
out = sys.argv[1]
lines = [t.upper() for t in sys.argv[2:]] or ["LIMONERO", "ABCDEFGHIJKLM", "NOPQRSTUVWXYZ", "0123456789 -.!?+:/'"]
png(render(lines), out)
