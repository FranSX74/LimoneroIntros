#!/usr/bin/env python3
"""Genera data.inc (fuentes y tablas) y text.inc (texto inicial en la ROM) para saver.asm.

Uso:  gen_data.py ["LINEA1|LINEA2"]     (sin argumento lee src/text.txt; por defecto MSX)
  - LINEA1: hasta 8 caracteres en amarillo (fuente de 7 px, ancho variable).
  - LINEA2: hasta 16 caracteres en blanco (fuente 3x5).
  - Caracteres: A-Z 0-9 espacio y  - . ! ? + : / '   (minúsculas -> mayúsculas)
  - Una sola línea sale en amarillo; para solo blanco: "|TEXTO".
Las partículas se generan en el propio MSX al arrancar (GENTEXT en saver.asm).
El texto vive en 26 bytes fijos de la ROM (desplazamiento 0x10): 8 + 16 de texto,
y 2 colores (línea 1 y 2, por defecto 10 y 5); se puede parchear sin reensamblar."""
import math, os, sys
here = os.path.dirname(__file__)
sys.path.insert(0, here)
from font_yellow import FONT7
from font_white import FONT5

CHARS = [c for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"] + [' '] + list("-.!?+:/'")
assert len(CHARS) == 45 and CHARS[36] == ' '
COL1, COL2 = 10, 5      # amarillo oscuro (color 10 de BASIC, el amarillo MSX1) y azul claro

def text_arg():
    if len(sys.argv) > 1: return " ".join(sys.argv[1:])
    p = os.path.join(here, "text.txt")
    return open(p).read().strip("\n") if os.path.exists(p) else "MSX"

def bits(row, width):    # fila de '#' y '.' -> byte con el pixel izquierdo en el bit 7
    return sum(1 << (7-i) for i, c in enumerate(row) if c == '#')

def main():
    parts = text_arg().upper().split("|")
    if len(parts) > 2: sys.exit("como mucho 2 líneas (separadas por '|')")
    l1 = parts[0].strip(); l2 = parts[1].strip() if len(parts) > 1 else ""
    if len(l1) > 8: sys.exit(f"línea 1 (amarilla) demasiado larga: {len(l1)} > 8")
    if len(l2) > 16: sys.exit(f"línea 2 (blanca) demasiado larga: {len(l2)} > 16")
    for c in l1 + l2:
        if c not in CHARS: sys.exit(f"carácter no soportado: {c!r}")
    out = ["; generado por gen_data.py - no editar", "CHARS:",
           " db " + ",".join(str(ord(c)) for c in CHARS), "FONTY:   ; ancho + 7 filas por carácter"]
    for c in CHARS:
        g = FONT7[c]
        out.append(f" db {len(g[0])}," + ",".join(str(bits(r, len(r))) for r in g) + f"   ; {c!r}")
    out.append("FONTW:   ; 5 filas por carácter (3 de ancho)")
    for c in CHARS:
        out.append(" db " + ",".join(str(bits(r, 3)) for r in FONT5[c]) + f"   ; {c!r}")
    out.append("SINT:")
    out.append(" db " + ",".join(str(round(60*math.sin(2*math.pi*i/64)) & 255) for i in range(64)))
    out.append("QUAD:")
    out.append(" db " + ",".join(str(min(200, i*i//10)) for i in range(64)))
    open(os.path.join(here, "data.inc"), "w").write("\n".join(out)+"\n")
    t = l1.ljust(8) + l2.ljust(16)
    open(os.path.join(here, "text.inc"), "w").write(
        f" db {','.join(str(ord(c)) for c in l1.ljust(8))}   ; linea 1 (amarillo): {l1!r}\n"
        f" db {','.join(str(ord(c)) for c in l2.ljust(16))}   ; linea 2 (blanco): {l2!r}\n"
        f" db {COL1},{COL2}   ; colores linea 1 y 2\n")
    print(f"texto inicial: {l1!r} | {l2!r}")

main()
