#!/bin/bash
# Uso: ./build_tree2.sh ["LINEA1|LINEA2"]  ->  build/tree2.rom   (dos limones, dos tonos de amarillo)
set -e
cd "$(dirname "$0")"
mkdir -p build
python3 src/gen_data.py "$@" >/dev/null
(cd src && python3 gen_tree2.py)
tools/n80/N80 src/tree2.asm build/tree2.rom | grep -E "ERROR|written"
