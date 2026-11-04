# LimoneroIntros

Salvapantallas / intro para MSX en **screen 3** (estilo ttfx de Omarchy), como ROM de 16 KB para MSX1 o superior.

- Texto personalizable: línea 1 amarilla (≤8 car.), línea 2 blanca (≤16 car.).
- Fuentes propias: amarilla 7 px de alto, blanca 3×5.
- Ensamblado con [N80](https://github.com/Konamiman/Nestor80) (`tools/n80/N80`, no incluido: descarga la release autocontenida).

## Uso

    ./build.sh "LIMONERO|PRODUCTIONS"     # genera build/saver.rom
    python3 patch_text.py ROM "L1|L2"     # cambia el texto de una ROM ya hecha

`dist/LIMONERO_PRODUCTIONS.rom` es la ROM lista para usar. Cualquier tecla sale.
