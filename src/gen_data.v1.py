#!/usr/bin/env python3
"""Genera data.inc (fuente, tonos, tablas) y text.inc (texto inicial en la ROM).
Las partículas se generan en el propio MSX al arrancar (GENTEXT en saver.asm).
El texto vive en 16 bytes fijos de la ROM (desplazamiento 0x10): se puede parchear.

Uso:  gen_data.py ["TEXTO"]        (sin argumento lee src/text.txt; por defecto MSX)
  - Hasta 8 caracteres por línea; las líneas se separan con '|' (p. ej. "RETRO|MSX").
  - Caracteres: A-Z 0-9 espacio y  - . ! ? + : / '   (minúsculas -> mayúsculas)
  - El tamaño de letra (1x, 2x, 3x) se elige solo para que el texto quepa en 64x48.
"""
import math, os, random, sys

G = {
 'A': "01110 10001 10001 11111 10001 10001 10001",
 'B': "11110 10001 10001 11110 10001 10001 11110",
 'C': "01110 10001 10000 10000 10000 10001 01110",
 'D': "11110 10001 10001 10001 10001 10001 11110",
 'E': "11111 10000 10000 11110 10000 10000 11111",
 'F': "11111 10000 10000 11110 10000 10000 10000",
 'G': "01110 10001 10000 10111 10001 10001 01111",
 'H': "10001 10001 10001 11111 10001 10001 10001",
 'I': "01110 00100 00100 00100 00100 00100 01110",
 'J': "00111 00010 00010 00010 00010 10010 01100",
 'K': "10001 10010 10100 11000 10100 10010 10001",
 'L': "10000 10000 10000 10000 10000 10000 11111",
 'M': "10001 11011 10101 10101 10001 10001 10001",
 'N': "10001 11001 10101 10011 10001 10001 10001",
 'O': "01110 10001 10001 10001 10001 10001 01110",
 'P': "11110 10001 10001 11110 10000 10000 10000",
 'Q': "01110 10001 10001 10001 10101 10010 01101",
 'R': "11110 10001 10001 11110 10100 10010 10001",
 'S': "01111 10000 10000 01110 00001 00001 11110",
 'T': "11111 00100 00100 00100 00100 00100 00100",
 'U': "10001 10001 10001 10001 10001 10001 01110",
 'V': "10001 10001 10001 10001 10001 01010 00100",
 'W': "10001 10001 10001 10101 10101 11011 10001",
 'X': "10001 10001 01010 00100 01010 10001 10001",
 'Y': "10001 10001 01010 00100 00100 00100 00100",
 'Z': "11111 00001 00010 00100 01000 10000 11111",
 '0': "01110 10001 10011 10101 11001 10001 01110",
 '1': "00100 01100 00100 00100 00100 00100 01110",
 '2': "01110 10001 00001 00010 00100 01000 11111",
 '3': "11110 00001 00001 01110 00001 00001 11110",
 '4': "00010 00110 01010 10010 11111 00010 00010",
 '5': "11111 10000 11110 00001 00001 10001 01110",
 '6': "00110 01000 10000 11110 10001 10001 01110",
 '7': "11111 00001 00010 00100 01000 01000 01000",
 '8': "01110 10001 10001 01110 10001 10001 01110",
 '9': "01110 10001 10001 01111 00001 00010 01100",
 ' ': "00000 00000 00000 00000 00000 00000 00000",
 '-': "00000 00000 00000 11111 00000 00000 00000",
 '.': "00000 00000 00000 00000 00000 01100 01100",
 '!': "00100 00100 00100 00100 00100 00000 00100",
 '?': "01110 10001 00001 00010 00100 00000 00100",
 '+': "00000 00100 00100 11111 00100 00100 00000",
 ':': "00000 01100 01100 00000 01100 01100 00000",
 '/': "00001 00001 00010 00100 01000 10000 10000",
 "'": "00100 00100 01000 00000 00000 00000 00000",
}
FONT = {k: v.split() for k, v in G.items()}
# un tono (degradado vertical, de arriba abajo) por letra, rotando
TONES = [
 [11,11,10,9,9,8,8],     # amarillo -> rojo
 [7,7,5,5,4,4,4],        # cian -> azul
 [3,3,12,12,12,12,12],   # verde
 [13,13,13,6,6,6,6],     # magenta -> rojo oscuro
 [15,15,14,14,14,14,14], # blanco -> gris
 [10,10,10,9,9,8,8],     # naranja
]

def text_arg():
    if len(sys.argv) > 1:
        return " ".join(sys.argv[1:])
    p = os.path.join(os.path.dirname(__file__), "text.txt")
    return open(p).read().strip("\n") if os.path.exists(p) else "MSX"

def main():
    lines = [l.strip() for l in text_arg().upper().split("|") if l.strip()]
    if not lines or len(lines) > 2: sys.exit("el texto debe tener 1 o 2 líneas (separadas por '|')")
    for l in lines:
        if len(l) > 8: sys.exit(f"línea demasiado larga ({len(l)} > 8): {l!r}")
        bad = [c for c in l if c not in G]
        if bad: sys.exit(f"caracteres no soportados: {bad}")
    here = os.path.dirname(__file__)
    order = [c for c in G if c != ' ']          # A-Z 0-9 - . ! ? + : / '
    # orden de CHARS: A-Z, 0-9, espacio, resto  (el espacio es el índice 36)
    chars = [c for c in G if c.isalnum()] + [' '] + [c for c in G if not c.isalnum() and c != ' ']
    assert len(chars) == 45 and chars[36] == ' '
    out = ["; generado por gen_data.py - no editar", "CHARS:",
           " db " + ",".join(str(ord(c)) for c in chars), "FONT:"]
    for c in chars:
        out.append(" db " + ",".join(str(int(r, 2)) for r in FONT[c]) + f"   ; {c!r}")
    out.append("TONES:")
    for t in TONES: out.append(" db " + ",".join(map(str, t)))
    out.append("SINT:")
    out.append(" db " + ",".join(str(round(60*math.sin(2*math.pi*i/64)) & 255) for i in range(64)))
    out.append("QUAD:")
    out.append(" db " + ",".join(str(min(200, i*i//10)) for i in range(64)))
    open(os.path.join(here, "data.inc"), "w").write("\n".join(out)+"\n")
    txt = [l.ljust(8) for l in lines] + [" "*8]*(2-len(lines))
    open(os.path.join(here, "text.inc"), "w").write("\n".join(
        " db " + ",".join(str(ord(c)) for c in l) + f"   ; {l!r}" for l in txt) + "\n")
    print(f"texto inicial: {' | '.join(lines)!r}")

main()
