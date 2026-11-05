# LimoneroIntros

Salvapantallas / intro para MSX en **screen 3** (estilo ttfx de Omarchy), como ROM de 16 KB para MSX1 o superior.

- Texto personalizable: línea 1 amarilla (≤8 car.), línea 2 blanca (≤16 car.).
- Fuentes propias: amarilla 7 px de alto, blanca 3×5.
- Ensamblado con [N80](https://github.com/Konamiman/Nestor80) (`tools/n80/N80`, no incluido: descarga la release autocontenida).

## Uso

    ./build.sh "LIMONERO|PRODUCTIONS"     # genera build/saver.rom
    python3 patch_text.py ROM "L1|L2"     # cambia el texto de una ROM ya hecha

`dist/LIMONERO_PRODUCTIONS.rom` es la ROM lista para usar. Cualquier tecla sale.

## Versión «limonero» (árbol + logo)

`./build_tree.sh` → `build/tree.rom` (`dist/LIMONERO_ARBOL.rom` ya compilada). A la izquierda un limonero (el dibujo es `tree_sheet.png`, 64×48 píxeles reales; `src/gen_tree.py` lo convierte en `src/tree.inc`; el limón más bajo es el que cae) y a la derecha, abajo, el logo. Secuencia: el árbol sale de izquierda a derecha → el logo se imprime en blanco, fila a fila (máquina de escribir) → cae un limón sobre «LIMONERO» y la palabra se pinta de amarillo desde el impacto (después «PRODUCTIONS» en color 5) → destellos → todo se borra de derecha a izquierda y se repite.
