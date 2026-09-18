#!/usr/bin/env bash
# Batería de tests headless de GestorAO.
# Uso: GODOT_BIN=/ruta/a/godot bash tests/run_battery.sh
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FALLOS=0
TOTAL=0

for suite in "$PROJECT_DIR"/tests/test_*.gd; do
	nombre="$(basename "$suite")"
	salida="$("$GODOT_BIN" --headless --path "$PROJECT_DIR" --script "res://tests/$nombre" 2>&1)"
	estado=$?
	if [ "$estado" -ne 0 ] || ! printf '%s' "$salida" | grep -q "TESTS OK"; then
		echo "FALLO: $nombre (exit=$estado)"
		printf '%s\n' "$salida"
		FALLOS=$((FALLOS + 1))
	else
		echo "OK: $nombre"
		TOTAL=$((TOTAL + 1))
	fi
done

if [ "$FALLOS" -ne 0 ]; then
	echo "BATERÍA FALLIDA: $FALLOS suite(s) fallaron, $TOTAL pasaron."
	exit 1
fi
echo "BATERÍA OK: $TOTAL suites pasaron."