#!/bin/bash
# Uso: ./build.sh ["TEXTO"]   ->  build/saver.rom
# Sin argumento usa src/text.txt (por defecto MSX). Hasta 8 caracteres por línea; '|' separa líneas.
set -e
cd "$(dirname "$0")"
mkdir -p build
python3 src/gen_data.py "$@"
tools/n80/N80 src/saver.asm build/saver.rom | grep -E "ERROR|written"
