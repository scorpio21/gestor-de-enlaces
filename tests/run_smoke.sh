#!/usr/bin/env bash
# Smoke test del binario exportado de GestorAO.
#
# Uso: SMOKE_BIN=/ruta/al/binario bash tests/run_smoke.sh
#
# Hay fallos que solo existen dentro del binario y que ninguna suite ve, porque
# el código se ejecuta con el proyecto abierto mientras que el binario corre con
# el pck: un recurso o una escena que no entra en el export, un script que no
# compila en release, un uid roto o una escritura a res:// que en un export es
# de solo lectura. La única forma de cazarlos es arrancar el binario de verdad
# y leer lo que dice, así que el smoke no sustituye a la batería: la segunda.
#
# El binario se lanza con --headless -- --smoke: el runner de GitHub no tiene
# display, y --smoke hace que main.gd ejecute scripts/smoke.gd (escritura en
# user://, recursos declarados, escenas instanciables y stores que cargan) y
# salga con código 0 o 1. Sin --quit-after: el binario decide cuándo termina.
set -uo pipefail

SMOKE_BIN="${SMOKE_BIN:-}"
TIMEOUT_SMOKE="${TIMEOUT_SMOKE:-120}"

if [ -z "$SMOKE_BIN" ]; then
	echo "SMOKE FALLIDO: no se paso SMOKE_BIN." >&2
	exit 1
fi
if [ ! -f "$SMOKE_BIN" ]; then
	echo "SMOKE FALLIDO: no encuentro el binario exportado ($SMOKE_BIN)." >&2
	exit 1
fi

# timeout(1) no está en todas partes: macOS usa gtimeout, y algún Windows
# minimalista no lo trae. Un array para que la lista quede vacía de verdad.
TIMEOUT=()
if command -v timeout >/dev/null 2>&1; then
	TIMEOUT=(timeout -k 10)
elif command -v gtimeout >/dev/null 2>&1; then
	TIMEOUT=(gtimeout -k 10)
fi

estado=0
salida="$(
	${TIMEOUT[@]+"${TIMEOUT[@]}"} "$TIMEOUT_SMOKE" "$SMOKE_BIN" --headless -- --smoke 2>&1
)" || estado=$?

if [ "$estado" -eq 124 ] || [ "$estado" -eq 137 ]; then
	echo "SMOKE COLGADO: $SMOKE_BIN no terminó en ${TIMEOUT_SMOKE}s (exit=$estado)"
	printf '%s\n' "$salida" | tail -20
	exit 1
fi

# El código de salida no basta: Godot puede imprimir un SCRIPT ERROR y aun así
# salir con 0, que es justo el caso que se quiere cazar.
if printf '%s' "$salida" | grep -qE "SCRIPT ERROR|Failed to load|Cannot open file|ERROR: Condition"; then
	echo "SMOKE FALLIDO: el binario arranca pero se queja (exit=$estado)"
	printf '%s\n' "$salida" | grep -E "SCRIPT ERROR|Failed to load|Cannot open file|ERROR: Condition" | head -10
	exit 1
fi

if [ "$estado" -ne 0 ]; then
	echo "SMOKE FALLIDO: el binario sale con codigo $estado"
	printf '%s\n' "$salida" | tail -20
	exit 1
fi

if ! printf '%s' "$salida" | grep -q "GestorAO smoke OK"; then
	echo "SMOKE FALLIDO: el binario salio con 0 pero no dijo que el smoke pasara"
	printf '%s\n' "$salida" | tail -20
	exit 1
fi

echo "SMOKE OK: $SMOKE_BIN arranca y las comprobaciones internas pasan."
