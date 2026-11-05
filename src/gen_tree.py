#!/usr/bin/env python3
"""Genera src/tree.inc a partir de tree_sheet.png (64x48, un pixel de imagen = un pixel de screen 3).
Colores: negro = fondo (no se dibuja); verde (33,200,66) = 2; amarillo (204,195,94) = 10; marron (185,94,81) = 6;
tambien se aceptan (por color mas cercano) 3, 4/5 y 15. Cada limon es una cruz amarilla de 5 pixeles; el MAS BAJO
es el que cae sobre la palabra (aparece colgado desde el principio y al caer se sustituye por el color de la copa).
Formato de TREE: 4 bytes por pixel (clave de aparicion = x + ruido fijo, x, y, color) ordenados por clave; 255 = fin."""
import os, random, sys
here = os.path.dirname(os.path.abspath(__file__))
root = os.path.dirname(here)
sys.path.insert(0, os.path.join(root, 'tools'))
import pngdec

PAL = {2:(33,200,66), 10:(204,195,94), 6:(185,94,81), 3:(94,220,120), 5:(84,85,237), 15:(255,255,255)}
PRE, DIVSHIFT = 10, 5            # el limon cuelga PRE ticks y cae con dy = d*d/32 (0,6 s para 10 filas)

def load(path):
    w, h, pix = pngdec.decode(path)
    assert (w, h) == (64, 48), "la hoja debe ser de 64x48 y es %dx%d" % (w, h)
    px = {}
    for y in range(h):
        for x in range(w):
            r, g, b = pix(x, y)[:3]
            if (r, g, b) == (0, 0, 0): continue
            best = min(PAL, key=lambda k: sum((a-c)**2 for a, c in zip(PAL[k], (r, g, b))))
            if PAL[best] != (r, g, b): print("aviso: (%d,%d) %s -> color %d (aproximado)" % (x, y, (r, g, b), best))
            px[(x, y)] = best
    return px

def lemons(px):
    """cruces amarillas (color 10) de 5 pixeles: devuelve los centros"""
    seen, out = set(), []
    for (x, y), c in sorted(px.items(), key=lambda e: (e[0][1], e[0][0])):
        if c != 10 or (x, y) in seen: continue
        comp, todo = [], [(x, y)]
        while todo:
            p = todo.pop()
            if p in seen or px.get(p) != 10: continue
            seen.add(p); comp.append(p)
            todo += [(p[0]+1, p[1]), (p[0]-1, p[1]), (p[0], p[1]+1), (p[0], p[1]-1)]
        xs, ys = [p[0] for p in comp], [p[1] for p in comp]
        cx, cy = (min(xs)+max(xs))//2, (min(ys)+max(ys))//2
        plus = {(cx, cy), (cx-1, cy), (cx+1, cy), (cx, cy-1), (cx, cy+1)}
        if set(comp) == plus: out.append((cx, cy))
        else: print("aviso: mancha amarilla que no es una cruz de limon en", min(xs), min(ys), "(se dibuja igual)")
    return out

def write_sheet(path, px):
    import zlib, struct
    rgb = dict(PAL); rgb[0] = (0,0,0)
    rows = b''.join(b'\x00' + b''.join(bytes(rgb[px.get((x, y), 0)]) for x in range(64)) for y in range(48))
    def ch(t, d): c = struct.pack('>I', len(d)) + t + d; return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + ch(b'IHDR', struct.pack('>IIBBBBB', 64, 48, 8, 2, 0, 0, 0)) + ch(b'IDAT', zlib.compress(rows)) + ch(b'IEND', b''))

def main():
    px = load(os.path.join(root, 'tree_sheet.png'))
    ls = lemons(px)
    fx, fy = max(ls, key=lambda p: (p[1], -p[0]))             # el mas bajo cae
    under = px.get((fx-1, fy-1), 2)                           # color de la copa alrededor
    fall = 30 - fy                                            # la cruz toca la fila 31; el texto empieza en la 32
    assert fall > 0, "el limon que cae esta demasiado abajo"
    d = 0
    while (d*d) >> DIVSHIFT < fall: d += 1
    rnd = random.Random(1983)
    ents = sorted(((x+rnd.randint(0,5), x, y, c) for (x, y), c in px.items()), key=lambda e: (e[0], e[2], e[1]))
    out = ["; generado por gen_tree.py desde tree_sheet.png: clave, x, y, color  (%d pixeles, %d limones)" % (len(ents), len(ls)), "TREE:"]
    out += ["        db %d,%d,%d,%d" % e for e in ents]
    out += ["TREEEND: db 255", "TREELEN equ %d" % (ents[-1][0]+1),
            "LEMX    equ %d              ; limon que cae: columna y fila de su centro" % fx, "LEMY    equ %d" % fy,
            "LEMBG   equ %d              ; color de la copa que queda al caerse" % under,
            "LEMFALL equ %d              ; filas que cae hasta tocar la palabra" % fall,
            "LEMPRE  equ %d              ; ticks que cuelga antes de caer" % PRE,
            "LEMLEN  equ %d              ; cuelga + cae (d*d/%d = filas)" % (PRE+d, 1 << DIVSHIFT)]
    open(os.path.join(here, 'tree.inc'), 'w').write("\n".join(out) + "\n")
    print(len(ents), "pixeles;", len(ls), "limones; cae el de (%d,%d): %d filas en %d ticks (~%.2f s a 30 ticks/s)" % (fx, fy, fall, d, d/30))
if __name__ == '__main__':
    main()
