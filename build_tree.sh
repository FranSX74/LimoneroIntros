#!/bin/bash
# Uso: ./build_tree.sh ["LINEA1|LINEA2"]  ->  build/tree.rom   (version limonero: arbol + logo)
set -e
cd "$(dirname "$0")"
mkdir -p build
python3 src/gen_data.py "$@" >/dev/null
python3 src/gen_tree.py
tools/n80/N80 src/tree.asm build/tree.rom | grep -E "ERROR|written"
