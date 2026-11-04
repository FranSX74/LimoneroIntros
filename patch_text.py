#!/usr/bin/env python3
"""Cambia el texto (y los colores) de una ROM ya construida sin reensamblar.
Uso: patch_text.py ROM_ENTRADA "LINEA1|LINEA2" [ROM_SALIDA] [--c1 N] [--c2 N]
  LINEA1: hasta 8 caracteres en amarillo (7 px, ancho variable)   LINEA2: hasta 16 en blanco (3x5)
  --c1/--c2: color MSX (0-15) de la línea 1 y 2 (por defecto 10 = amarillo y 5 = azul claro)
Zona patcheable: desplazamiento 0x10, 24 bytes de texto (8 + 16, ASCII, relleno con espacios)
y 2 bytes de color en 0x28 y 0x29. Se puede hacer igual con un editor hexadecimal."""
import sys
a = sys.argv[1:]
opts = {}
for k in ("--c1", "--c2"):
    if k in a:
        i = a.index(k); opts[k] = int(a[i+1]); del a[i:i+2]
if len(a) < 2: sys.exit(__doc__)
src, text = a[0], a[1]
dst = a[2] if len(a) > 2 else src
parts = text.upper().split("|")
l1 = parts[0]; l2 = parts[1] if len(parts) > 1 else ""
if len(parts) > 2 or len(l1) > 8 or len(l2) > 16: sys.exit("máximo: línea 1 = 8 caracteres, línea 2 = 16")
data = bytearray(open(src, "rb").read())
if data[:2] != b"AB": sys.exit("no parece una ROM de MSX (falta la cabecera AB)")
data[0x10:0x28] = (l1.ljust(8) + l2.ljust(16)).encode("ascii")
if "--c1" in opts: data[0x28] = opts["--c1"]
if "--c2" in opts: data[0x29] = opts["--c2"]
open(dst, "wb").write(data)
print(f"{dst}: línea 1 = {l1!r}, línea 2 = {l2!r}, colores {data[0x28]},{data[0x29]}")
