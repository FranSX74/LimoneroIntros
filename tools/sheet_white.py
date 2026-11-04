#!/usr/bin/env python3
"""Hoja PNG a tamaño real de la fuente blanca 3x5.
  sheet_white.py export [hoja.png]    escribe la hoja (celdas de 4x6 con rejilla gris tenue)
  sheet_white.py import [hoja.png]    lee la hoja editada y reescribe src/font_white.py
Pinta en cualquier color claro (suma RGB > 150); la rejilla gris no cuenta."""
import sys, os, zlib, struct
here = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(here, "..")); sys.path.insert(0, os.path.join(here, "..", "src"))
from font_white import FONT5
ORDER = ["ABCDEFGHIJKLM", "NOPQRSTUVWXYZ", "0123456789", "-.!?+:/'"]
CW, CH, COLS = 4, 6, 13
BG, GRID, FG = (0, 0, 0), (45, 45, 45), (240, 240, 232)
def export(out):
    h, w = CH*len(ORDER)+1, CW*COLS+1
    img = [[BG]*w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if x % CW == 0 or y % CH == 0: img[y][x] = GRID
    for r, row in enumerate(ORDER):
        for c, ch in enumerate(row):
            for y, line in enumerate(FONT5[ch]):
                for x, v in enumerate(line):
                    if v == '#': img[1+r*CH+y][1+c*CW+x] = FG
    raw = b"".join(b"\x00"+b"".join(bytes(p) for p in row) for row in img)
    def chunk(t, d): return struct.pack(">I", len(d))+t+d+struct.pack(">I", zlib.crc32(t+d) & 0xffffffff)
    open(out, "wb").write(b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))+chunk(b"IDAT", zlib.compress(raw))+chunk(b"IEND", b""))
    print(out, f"{w}x{h}")
def imp(path):
    from tools.pngdec import decode
    w, h, pix = decode(path); print("imagen", w, "x", h)
    new = {}
    for r, row in enumerate(ORDER):
        for c, ch in enumerate(row):
            new[ch] = ["".join('#' if (lambda p: p[3] > 0 and sum(p[:3]) > 150)(pix(1+c*CW+x, 1+r*CH+y)) else '.' for x in range(3)) for y in range(5)]
    changed = [ch for ch in new if new[ch] != FONT5[ch]]
    print("glifos cambiados:", " ".join(changed) or "ninguno")
    for ch in changed:
        print(f"-- {ch!r} (antes | ahora)")
        for i in range(5): print("  ", FONT5[ch][i], "|", new[ch][i])
    out = ['"""Fuente blanca 3x5 (ancho fijo 3). Base Lowres-NX (CC0) + R y N de la captura; editada desde la hoja PNG."""', "", "FONT5 = {"]
    for ch in FONT5: out.append(f" {ch!r}: {new.get(ch, FONT5[ch])!r},")
    out += ["}", "for k, v in FONT5.items():", "    assert len(v) == 5 and all(len(r) == 3 for r in v), k", ""]
    open(os.path.join(here, "..", "src", "font_white.py"), "w").write("\n".join(out))
if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "export"
    p = sys.argv[2] if len(sys.argv) > 2 else os.path.join(here, "..", "font_white_sheet.png")
    export(p) if cmd == "export" else imp(p)
