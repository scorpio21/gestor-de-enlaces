#!/usr/bin/env bash
# Comprobacion estatica de los scripts de GestorAO.
#
# Uso: GODOT_BIN=/ruta/a/godot bash tests/run_estatico.sh
#
# Una suite con un Parse Error no compila, no imprime TESTS OK y se cuelga (no
# llega a llamar a quit()). La bateria lo detecta por timeout, pero eso cuesta
# minutos por suite: aqui se comprueba antes y en un segundo por fichero, y el
# codigo de salida de --check-only es de fiar (distinto de 0 si hay error).
#
# --check-only solo analiza: no carga escenas ni ejecuta codigo, asi que un
# fallo aqui es siempre un fallo real y no ruido de importacion.
set -uo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TIMEOUT_FICHERO="${TIMEOUT_FICHERO:-60}"

# Un array, no una cadena: con TIMEOUT="" la expansion sin comillas se
# convierte en un argumento vacio y desplaza el resto de la linea de comando.
TIMEOUT=()
if command -v timeout >/dev/null 2>&1; then
	TIMEOUT=(timeout -k 10)
elif command -v gtimeout >/dev/null 2>&1; then
	TIMEOUT=(gtimeout -k 10)
fi

ERRORES=0
REVISADOS=0

for ruta in "$PROJECT_DIR"/scripts/*.gd "$PROJECT_DIR"/tests/*.gd; do
	[ -f "$ruta" ] || continue
	relativo="${ruta#"$PROJECT_DIR"/}"
	estado=0
	salida="$(
		${TIMEOUT[@]+"${TIMEOUT[@]}"} "$TIMEOUT_FICHERO" "$GODOT_BIN" --headless --path "$PROJECT_DIR" \
			--check-only --script "res://$relativo" 2>&1
	)" || estado=$?
	REVISADOS=$((REVISADOS + 1))
	if [ "$estado" -ne 0 ]; then
		ERRORES=$((ERRORES + 1))
		echo "ERROR: $relativo (exit=$estado)"
		printf '%s\n' "$salida" | grep -E "SCRIPT ERROR|Parse Error|Compile Error|ERROR:" | head -5
	fi
done

if [ "$ERRORES" -ne 0 ]; then
	echo "ESTATICO FALLIDO: $ERRORES de $REVISADOS ficheros con error."
	exit 1
fi
echo "ESTATICO OK: $REVISADOS ficheros analizados."
