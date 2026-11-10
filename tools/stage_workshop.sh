#!/usr/bin/env bash
# Monta ~/Zomboid/Workshop/Remanescentes para enviar pela tela "Workshop" do jogo.
# So copia o que o jogo usa (sem testes, docs, ferramentas nem git). Nao envia nada.
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
DST="$HOME/Zomboid/Workshop/Remanescentes"
mkdir -p "$DST/Contents/mods"
cp "$SRC/workshop/preview.png" "$DST/preview.png"
# preserva o id= que o jogo grava no workshop.txt depois do primeiro envio
ID=$(grep -s '^id=' "$DST/workshop.txt" || true)
if [ -n "$ID" ]; then { echo "version=1"; echo "$ID"; grep -v '^version=' "$SRC/workshop/workshop.txt"; } > "$DST/workshop.txt"
else cp "$SRC/workshop/workshop.txt" "$DST/workshop.txt"; fi
rm -rf "$DST/Contents/mods/Remanescentes"
mkdir -p "$DST/Contents/mods/Remanescentes"
cp -r "$SRC/42" "$SRC/common" "$SRC/mod.info" "$SRC/poster.png" "$DST/Contents/mods/Remanescentes/"
echo "pronto: $DST"
