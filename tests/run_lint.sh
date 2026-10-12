#!/usr/bin/env bash
# gdlint con la configuracion tolerante del repo (#78).
#
# Uso:
#   bash tests/run_lint.sh
#   GDLINT_BIN=/ruta/a/gdlint bash tests/run_lint.sh
#
# Si gdlint no esta instalado, avisa y sale con 0 (el lint es opcional fuera
# de CI; alli el workflow instala gdtoolkit antes de llamar a este script).
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

if [ -n "${GDLINT_BIN:-}" ]; then
	if [ ! -x "$GDLINT_BIN" ] && ! command -v "$GDLINT_BIN" >/dev/null 2>&1; then
		echo "GDLINT_BIN='$GDLINT_BIN' no es un ejecutable valido." >&2
		exit 1
	fi
	GDLINT=("$GDLINT_BIN")
elif command -v gdlint >/dev/null 2>&1; then
	GDLINT=(gdlint)
elif python -c "import gdtoolkit" >/dev/null 2>&1; then
	GDLINT=(python -m gdtoolkit.linter)
else
	echo "gdlint no esta instalado; se omite el lint (pip install gdtoolkit==4.5.0)."
	exit 0
fi

echo "gdlint: $("${GDLINT[@]}" --version)"
"${GDLINT[@]}" scripts tests
echo "LINT OK"
