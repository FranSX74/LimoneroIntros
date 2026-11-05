#!/usr/bin/env python3
"""Version de dos limones y dos tonos: genera src/tree2.inc desde tree2_sheet.png.
Como gen_tree.py, pero con el amarillo 10 y el amarillo claro 11 (230,206,128).
Cae primero el limon MAS BAJO (debe ser color 11) y pinta LIMONERO de su color; justo despues cae el SEGUNDO mas bajo
(color 10) y lo repinta con el suyo, que es el definitivo.
Uso: python3 src/gen_tree2.py [--make-sheet]   (--make-sheet crea tree2_sheet.png a partir de tree_sheet.png)"""
import os, random, sys
import gen_tree as g

g.PAL[11] = (230, 206, 128)
here, root = g.here, g.root

def lemons2(px):
    out = []
    for col in (10, 11):
        only = {p: (10 if c == col else 0) for p, c in px.items()}      # reutiliza la deteccion por color
        out += [(x, y, col) for x, y in g.lemons({p: c for p, c in only.items() if c})]
    return out

def make_sheet():
    px = g.load(os.path.join(root, 'tree_sheet.png'))
    ls = sorted(g.lemons(px), key=lambda p: (p[1], p[0]))
    low = sorted(ls, key=lambda p: (-p[1], p[0]))
    a, b = low[0], low[1]
    for i, (x, y) in enumerate(sorted(ls)):
        col = 11 if i % 2 == 0 else 10
        if (x, y) == a: col = 11
        if (x, y) == b: col = 10
        for dx, dy in ((0,-1),(-1,0),(0,0),(1,0),(0,1)): px[(x+dx, y+dy)] = col
    g.write_sheet(os.path.join(root, 'tree2_sheet.png'), px)

def main():
    if '--make-sheet' in sys.argv: make_sheet()
    px = g.load(os.path.join(root, 'tree2_sheet.png'))
    ls = lemons2(px)
    low = sorted(ls, key=lambda l: (-l[1], l[0]))
    A, B = low[0], low[1]
    if A[2] != 11: print("aviso: el limon mas bajo", A[:2], "deberia ser de color 11")
    if B[2] != 10: print("aviso: el segundo limon mas bajo", B[:2], "deberia ser de color 10")
    rnd = random.Random(1983)
    ents = sorted(((x+rnd.randint(0,5), x, y, c) for (x, y), c in px.items()), key=lambda e: (e[0], e[2], e[1]))
    def lem(name, l, pre):
        x, y, c = l
        fall = 30 - y
        assert fall > 0, "limon demasiado abajo"
        d = 0
        while (d*d) >> g.DIVSHIFT < fall: d += 1
        under = px.get((x-1, y-1), 2)
        first = max(0, (y-1) >> 3)
        mask = (0x0F >> first) << first                       # franjas desde la de su fila hasta la 3 (fila 31)
        return ["%s: db %d,%d,%d,%d,%d,%d,%d   ; x, y, filas que cae, ticks colgado, color de la copa, color, franjas" % (name, x, y, fall, pre, under, c, mask),
                "%sLEN   equ %d" % (name, pre+d)], d
    la, da = lem("LEMA", A, 10)
    lb, db = lem("LEMB", B, 2)
    out = ["; generado por gen_tree2.py desde tree2_sheet.png: clave, x, y, color  (%d pixeles, %d limones)" % (len(ents), len(ls)), "TREE:"]
    out += ["        db %d,%d,%d,%d" % e for e in ents]
    out += ["TREEEND: db 255", "TREELEN equ %d" % (ents[-1][0]+1)] + la + lb
    out += ["LEMACOL equ %d              ; color con el que el primer limon pinta LIMONERO" % A[2],
            "LEMBCOL equ %d              ; el segundo lo repinta con este (el definitivo)" % B[2]]
    open(os.path.join(here, 'tree2.inc'), 'w').write("\n".join(out) + "\n")
    print(len(ents), "pixeles;", len(ls), "limones; caen (%d,%d) color %d en %d ticks y (%d,%d) color %d en %d ticks" % (A[0], A[1], A[2], da, B[0], B[1], B[2], db))
if __name__ == '__main__':
    main()
