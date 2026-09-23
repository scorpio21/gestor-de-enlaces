# GestorAO — Guía del repo

Proyecto Godot 4.7.2 (GDScript). Motor local: `K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe`.

## Batería de tests (headless)

Cada suite: `tests/test_<area>.gd` (extends SceneTree; imprime `TESTS OK` y `quit(0)`).

Pwsh (Windows):

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_<area>.gd
```

Suites completas (Linux/CI):

```bash
GODOT_BIN=/ruta/a/godot bash tests/run_battery.sh
```

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