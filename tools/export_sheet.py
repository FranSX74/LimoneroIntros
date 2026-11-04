#!/usr/bin/env python3
"""Exporta la fuente amarilla a una hoja PNG a tamaño real (1 px de imagen = 1 px de glifo).
Cada glifo ocupa una celda de 8x9 px (1 px de margen) en una rejilla de 13 columnas.
Orden: A-M / N-Z / 0-9 y espacio / - . ! ? + : / '   -> tools/import_sheet.py hace el camino inverso."""
import sys, os, zlib, struct
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))
from font_yellow import FONT7
ORDER = ["ABCDEFGHIJKLM", "NOPQRSTUVWXYZ", "0123456789", "-.!?+:/'"]
CW, CH, COLS = 8, 9, 13
BG, FG = (0, 0, 0), (231, 220, 68)
def main(out):
    h, w = CH*len(ORDER)+1, CW*COLS+1
    img = [[BG]*w for _ in range(h)]
    for r, row in enumerate(ORDER):
        for c, ch in enumerate(row):
            for y, line in enumerate(FONT7[ch]):
                for x, v in enumerate(line):
                    if v == '#': img[1+r*CH+y][1+c*CW+x] = FG
    raw = b"".join(b"\x00"+b"".join(bytes(p) for p in row) for row in img)
    def chunk(t, d): return struct.pack(">I", len(d))+t+d+struct.pack(">I", zlib.crc32(t+d) & 0xffffffff)
    open(out, "wb").write(b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))+chunk(b"IDAT", zlib.compress(raw))+chunk(b"IEND", b""))
    print(out, f"{w}x{h}")
main(sys.argv[1] if len(sys.argv) > 1 else "font_yellow_sheet.png")
