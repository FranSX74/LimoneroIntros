#!/usr/bin/env python3
"""Genera src/tree.inc (el limonero en screen 3, 64x48) y una vista previa PNG.
Uso: python3 src/gen_tree.py [preview.png]
Formato de TREE: 4 bytes por pixel (clave de aparicion, x, y, color) ordenados por clave; 255 = fin.
La clave es x + un pequeno desorden fijo, asi el arbol sale de izquierda a derecha."""
import random, sys, zlib, struct, os

GREEN, LEMON, TRUNK = 2, 10, 6           # colores MSX1: verde medio, amarillo de BASIC, rojo oscuro (marron)

# copa: por fila, lista de tramos (x0, x1)
CANOPY = {
 0:[(0,19)], 1:[(0,20)], 2:[(0,22)], 3:[(0,24)], 4:[(0,26)], 5:[(0,27)], 6:[(0,28)], 7:[(0,28)],
 8:[(0,29)], 9:[(0,29)], 10:[(0,30)], 11:[(0,31)], 12:[(1,32)], 13:[(1,33)],
 14:[(2,12),(16,33)], 15:[(3,12),(16,33)], 16:[(4,12),(16,33)], 17:[(6,11),(16,33)],
 18:[(16,33)], 19:[(16,31)], 20:[(16,28)], 21:[(16,28)], 22:[(17,27)], 23:[(18,26)],
}
# limones: centro de la cruz 010/111/010 (el limon que cae, en (24,20), no esta aqui)
LEMONS = [(4,3),(11,2),(17,2),(19,6),(4,8),(11,7),(17,9),(24,7),(22,11),(7,12),(14,12),
          (26,12),(19,14),(24,15),(31,17)]
FALL = (24,20)
# tronco: contorno, polilineas (x,y)
TRUNK_L = [(5,18),(5,19),(4,21),(4,23),(4,27),(4,32),(4,36),(3,40),(2,43),(1,45),(0,47)]
TRUNK_R = [(11,18),(11,21),(10,24),(10,28),(10,32),(9,36),(9,39),(10,42),(11,44),(13,46),(14,47)]

def line(a, b):
    (x0,y0),(x1,y1) = a,b
    n = max(abs(x1-x0), abs(y1-y0), 1)
    return [(round(x0+(x1-x0)*i/n), round(y0+(y1-y0)*i/n)) for i in range(n+1)]

def build():
    px = {}
    for y,segs in CANOPY.items():
        for x0,x1 in segs:
            for x in range(x0,x1+1): px[(x,y)] = GREEN
    for cx,cy in LEMONS + [FALL]:
        for dx in (-1,0,1):
            for dy in (-1,0,1):
                assert (cx+dx,cy+dy) in px, ("limon fuera de la copa", cx, cy)
    for cx,cy in LEMONS:
        for dx,dy in ((0,-1),(-1,0),(0,0),(1,0),(0,1)): px[(cx+dx,cy+dy)] = LEMON
    for poly in (TRUNK_L, TRUNK_R):
        for a,b in zip(poly, poly[1:]):
            for p in line(a,b): px[p] = TRUNK
    return px

def write_png(path, px, scale=10):
    pal = {0:(0,0,0),2:(33,200,66),10:(204,195,94),6:(185,94,81),5:(84,85,237),15:(255,255,255)}
    W,H = 64,48
    rows=[]
    for y in range(H*scale):
        r=bytearray(b'\x00')
        for x in range(W*scale):
            r += bytes(pal[px.get((x//scale,y//scale),0)])
        rows.append(bytes(r))
    def ch(t,d): c=struct.pack('>I',len(d))+t+d; return c+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
    open(path,'wb').write(b'\x89PNG\r\n\x1a\n'+ch(b'IHDR',struct.pack('>IIBBBBB',W*scale,H*scale,8,2,0,0,0))+ch(b'IDAT',zlib.compress(b''.join(rows)))+ch(b'IEND',b''))

def main():
    px = build()
    rnd = random.Random(1983)
    ents = sorted(((x+rnd.randint(0,5), x, y, c) for (x,y),c in px.items()), key=lambda e:(e[0],e[2],e[1]))
    out = ["; generado por gen_tree.py: clave, x, y, color  (%d pixeles)" % len(ents), "TREE:"]
    for k,x,y,c in ents: out.append("        db %d,%d,%d,%d" % (k,x,y,c))
    out += ["TREEEND: db 255", "TREELEN equ %d" % (ents[-1][0]+1)]
    open(os.path.join(os.path.dirname(os.path.abspath(__file__)),"tree.inc"),"w").write("\n".join(out)+"\n")
    print(len(ents),"pixeles; TREELEN",ents[-1][0]+1)
    if len(sys.argv)>1: write_png(sys.argv[1], px)
main()
