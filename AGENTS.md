# GestorAO — Guía del repo

Proyecto Godot 4.7.2 (GDScript). Motor local: `K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe`.

## Batería de tests (headless)

Cada suite: `tests/test_<area>.gd` (extends SceneTree; imprime `TESTS OK` y `quit(0)`).

Pwsh (Windows):

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_<area>.gd
```

Suites completas (Windows, con Git Bash):

```bash
& "C:\Program Files\Git\bin\bash.exe" -c 'cd /k/gestor-de-enlaces && GODOT_BIN="K:/Godot_v4.6.1/Godot_v4.7.2-stable_win64_console.exe" bash tests/run_battery.sh'
```

Cada suite lleva timeout propio (`TIMEOUT_SUITE`, 180 s por defecto): una suite con un `Parse Error` nunca llega a `quit()` y, sin ese corte, se cuelga para siempre en vez de fallar. Para una sola suite: `PATRON=tests/test_agregar_enlace.gd`.

Comprobación estática de parseo, antes de la batería (un segundo por fichero, sin cargar escenas):

```bash
GODOT_BIN=/ruta/a/godot bash tests/run_estatico.sh
```

## Smoke test del binario exportado

Exporta y arranca el binario de verdad. Caza lo que solo existe dentro del pck: un recurso o una escena que no entra, un script que no compila en release, un `user://` que no se puede escribir.

```bash
godot --headless --path . --export-release "Windows" build/gestor.exe
SMOKE_BIN=build/gestor.console.exe bash tests/run_smoke.sh
```

El binario se lanza con `--headless -- --smoke`, y ese `--smoke` hace que `main.gd` ejecute `scripts/smoke.gd` y salga con código 0 o 1. `SMOKE_BIN` tiene que ser el `.console.exe` en Windows (el otro no escribe en la consola). El script no se conforma con el código de salida: exige la marca `GestorAO smoke OK` y que no haya ni un `SCRIPT ERROR`, porque Godot puede imprimir un error y salir con 0.

Añadir una escena a `scenes/` obliga a meterla en `SmokeScript.ESCENAS`: `test_smoke.gd` comprueba que todas las de la lista existen de verdad, y no al revés.

## Regenerar export_presets.cfg

1. Abre el proyecto en el editor Godot (`godot --path . -e`).
2. Proyecto → Exportar… → reconfigura los 3 presets (Windows, Linux/X11, macOS).
3. cierra el editor; `export_presets.cfg` se reescribe. Comitea el cambio.
   Nota: el editor reescribe el fichero a su formato; los cambios manuales se pierden.

## Generar iconos

```bash
godot --headless --path . --script res://scripts/generar_iconos.gd
```

Regenera `Assets/icon/*` (svg/png/ico/icns) desde el SVG incrustado en el script.

## Convenciones

- Sin comentarios; tabs; UI en español; preload-const en lugar de class_name (nuevo código).
- `main.gd` es el punto de integración; los stores viven en `scripts/` con test propio.
- Los tests usan bases `user://__test_*__` y se limpian.
- Al terminar un issue o varios, cerrar el/los issue(s) en GitHub al final del trabajo (`gh issue close N --repo scorpio21/gestor-de-enlaces --comment "resumen + commits"`).