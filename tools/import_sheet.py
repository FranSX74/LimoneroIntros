#!/usr/bin/env python3
"""Lee la hoja PNG editada (ver export_sheet.py) y reescribe la tabla FONT7 de src/font_yellow.py.
Píxel encendido = cualquiera que no sea (casi) negro. Ancho de cada glifo = última columna encendida + 1."""
import sys, os, re
here = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(here, "..")); sys.path.insert(0, os.path.join(here, "..", "src"))
from tools.pngdec import decode
from font_yellow import FONT7
ORDER = ["ABCDEFGHIJKLM", "NOPQRSTUVWXYZ", "0123456789", "-.!?+:/'"]
CW, CH = 8, 9
def main(path):
    w, h, pix = decode(path)
    print("imagen", w, "x", h)
    new = {}
    for r, row in enumerate(ORDER):
        for c, ch in enumerate(row):
            rows = []
            for y in range(7):
                line = ""
                for x in range(CW-1):
                    px = pix(1+c*CW+x, 1+r*CH+y)
                    lit = px[3] > 0 and (px[0]+px[1]+px[2]) > 60
                    line += '#' if lit else '.'
                rows.append(line)
            width = max((l.rfind('#')+1 for l in rows), default=0)
            if width == 0: new[ch] = FONT7[ch]; continue
            new[ch] = [l[:width] for l in rows]
    changed = [ch for ch in new if new[ch] != FONT7[ch]]
    print("glifos cambiados:", " ".join(changed) or "ninguno")
    for ch in changed:
        print(f"-- {ch!r}  (antes | ahora)")
        old = FONT7[ch]
        for i in range(7):
            print("  ", old[i].ljust(7), "|", new[ch][i])
    wide = [ch for ch in new if len(new[ch][0]) > 6]
    if wide: print("¡ATENCIÓN! más de 6 de ancho:", wide)
    out = ['"""Fuente amarilla 7 de alto (editada desde la hoja PNG). Ancho variable, 1 px de separación."""', "", "FONT7 = {"]
    for ch in FONT7:
        g = new.get(ch, FONT7[ch])
        out.append(f" {ch!r}: {g!r},")
    out += ["}", "for k, v in FONT7.items():", "    assert len(v) == 7 and len({len(r) for r in v}) == 1, k", ""]
    open(os.path.join(here, "..", "src", "font_yellow.py"), "w").write("\n".join(out))
main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "font_yellow_sheet.png"))
