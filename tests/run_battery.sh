#!/usr/bin/env bash
# Batería de tests headless de GestorAO.
#
# Uso: GODOT_BIN=/ruta/a/godot bash tests/run_battery.sh
#
# Variables opcionales:
#   GODOT_BIN     binario de Godot (por defecto "godot")
#   TIMEOUT_SUITE segundos por suite antes de darla por colgada (por defecto 180)
#   PATRON        glob de suites a correr (por defecto "tests/test_*.gd")
#
# Una suite que no compila nunca llega a llamar a quit() y se queda colgada
# para siempre en vez de fallar, así que cada suite va con timeout propio: sin
# él, un Parse Error tumba la CI entera tras las horas por defecto del job y
# sin decir qué suite fue.
set -uo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TIMEOUT_SUITE="${TIMEOUT_SUITE:-180}"
PATRON="${PATRON:-tests/test_*.gd}"

# timeout(1) no está en todas partes: macOS usa gtimeout, y algún Windows
# minimalista no lo trae. Sin él seguimos corriendo, pero avisamos de que una
# suite colgada cuelga el proceso entero. Un array (y no una cadena) para que la
# lista quede vacía de verdad cuando no hay timeout y el comando no se desplace.
TIMEOUT=()
if command -v timeout >/dev/null 2>&1; then
	TIMEOUT=(timeout -k 10)
elif command -v gtimeout >/dev/null 2>&1; then
	TIMEOUT=(gtimeout -k 10)
else
	echo "AVISO: no hay timeout(1); una suite colgada colgara el proceso." >&2
fi

FALLOS=0
TOTAL=0
COLGADAS=0

for ruta in "$PROJECT_DIR"/$PATRON; do
	[ -f "$ruta" ] || continue
	nombre="$(basename "$ruta")"
	estado=0
	salida="$(
		${TIMEOUT[@]+"${TIMEOUT[@]}"} "$TIMEOUT_SUITE" "$GODOT_BIN" --headless --path "$PROJECT_DIR" \
			--script "res://tests/$nombre" 2>&1
	)" || estado=$?

	# 124 = timeout(1) agotado; 137 = muerto a la fuerza tras el periodo extra.
	if [ "$estado" -eq 124 ] || [ "$estado" -eq 137 ]; then
		echo "COLGADA: $nombre (sin terminar en ${TIMEOUT_SUITE}s, exit=$estado)"
		printf '%s\n' "$salida" | tail -20
		COLGADAS=$((COLGADAS + 1))
		FALLOS=$((FALLOS + 1))
	elif [ "$estado" -ne 0 ] || ! printf '%s' "$salida" | grep -q "TESTS OK"; then
		echo "FALLO: $nombre (exit=$estado)"
		printf '%s\n' "$salida" | tail -20
		FALLOS=$((FALLOS + 1))
	else
		echo "OK: $nombre"
		TOTAL=$((TOTAL + 1))
	fi
done

if [ "$FALLOS" -ne 0 ]; then
	echo "BATERIA FALLIDA: $FALLOS suite(s) fallaron, $TOTAL pasaron${COLGADAS:+, $COLGADAS se colgaron}."
	exit 1
fi
echo "BATERIA OK: $TOTAL suites pasaron."
