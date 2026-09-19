# MEMORIA — GestorAO

## Objetivo

Repositorio `K:\gestor-de-enlaces` (Godot 4.7.2, GDScript) — gestor de enlaces para Argentum Online. Grupo C empaquetable (presets + CI + logs + diagnóstico + icono) **COMPLETO y en producción**: 12 commits en `main`, issues #26/#28/#29 cerradas, CI verde.

## Comandos de verificación

Batería completa (17 suites) vía Git Bash (mismo script que el CI):

```bash
& "C:\Program Files\Git\bin\bash.exe" -c 'cd /k/gestor-de-enlaces && GODOT_BIN="K:/Godot_v4.6.1/Godot_v4.7.2-stable_win64_console.exe" bash tests/run_battery.sh'
```

Suite suelta (Windows pwsh):

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_<area>.gd
```

Linux/CI: `GODOT_BIN=/ruta/a/godot bash tests/run_battery.sh`. Cada suite imprime `TESTS OK` y `quit(0)`; `run_battery.sh` con `set -e` falla en la primera suite roja.

## Estado actual

- ✅ Grupo C empaquetado COMPLETO — `main` push en `0a77542`, CI `35418734671` verde (batería 17/17 + export Windows/Linux/macOS + artefacto `gestor-de-enlaces-builds` publicado).
- ✅ Issues **#26** (presets+CI), **#28** (logs+diagnóstico), **#29** (icono/metadatos) cerradas. #27 (auto-actualización) diferida.
- ⚠️ Tareas restantes pendientes del backlog: #6 (orden manual persistido), #11 (exportar CSV/HTML), #12 (más hosts), #13 (cola persistida), #17 (tema claro/oscuro), #19 (ordenación tabla), #30 (i18n).
- ⏳ Abierto en local (sin commitear, NO tocar): `data/data2.json`, `docs/superpowers/plans/2026-09-05-captura-enlaces.md`.

## Historial de trabajo (Grupo C)

- `3033d03` docs(plan): corregir 5 defectos pre-ejecución (logging base, ICNS, CI templates/macOS, contadores)
- `47ce15a` docs(plan): helpers static en generar_iconos y escala SVG (width 256, no viewBox)
- `f3a7f4d` feat(logs): logger rotativo app/scan en `user://logs` (#28)
- `f1a72e3` feat(empaquetado): generador de iconos y metadatos de proyecto 0.1.0 (#29)
- `3065013` feat(diagnostico): exportar ZIP de logs y datos con info.txt (#28)
- `cf7dc41` feat(empaquetado): menú Exportar diagnóstico y logs en main (#28)
- `c8f4ec6` docs(plan): corregir extracción export templates en CI (tpz tiene subcarpeta templates/ dentro)
- `b4b38c1` feat(ci/empaquetado): presets, workflow CI y batería compartida (#26)
- `8c067af` fix(ci): importar assets antes de la batería (checkout fresco sin `.godot/` se cuelga)
- `c5cd581` fix(empaquetado): preset macOS usa arquitectura universal (`godot_macos_release.universal`)
- `272ef4b` fix(empaquetado): preset macOS habilita ETC2 ASTC
- `0a77542` fix(empaquetado): habilitar import ETC2 ASTC en project.godot

Producto: `scripts/logger.gd`, `scripts/diagnostico.gd`, `scripts/generar_iconos.gd`, `Assets/icon/*`, `export_presets.cfg` (3 presets, export_path `build/`), `.github/workflows/ci.yml`, `tests/run_battery.sh`, `tests/test_empaquetado.gd`, `AGENTS.md`.

## Próximos pasos

1. (Opcional, pendiente del usuario) CI: `actions/checkout@v4`/`cache@v4`/`upload-artifact@v4` usan Node 20 (deprecado → se migra a Node 24 solo); `ubuntu-latest` migrará a Ubuntu 26 en oct 2026 — revisar si CI vuelve a fallar con avisos de deprecación.
2. Backlog: #6, #11, #12, #13, #17, #19, #30 (en orden de prioridad del usuario); #27 por decidir.
3. `docs/superpowers/specs/` sigue documentando los diseños del grupo anterior; nuevos grupos deben crear su spec/plan antes de implementar.

## Gotchas verificados (no repetir investigación)

- CORRECTION: la tpz de export templates **SÍ lleva subcarpeta `templates/` dentro**; el contenido debe quedar DIRECTO en `~/.local/share/godot/export_templates/4.7.2.stable/` (la nota anterior del plan decía que no había subcarpeta — falso).
- En checkout fresco (CI) no existe `.godot/` (gitignored): un `--headless --script` sin importar antes **se cuelga indefinidamente**. Obligatorio `godot --headless --path . --import` (≈5 s) antes de la batería (`.github/workflows/ci.yml`).
- Preset macOS: `binary_format/architecture="universal"` — las templates de 4.7 son `godot_macos_release.universal`, NO existe `x86_64` en macOS. Y universal/arm64 exige `rendering/textures/vram_compression/import_etc2_astc=true` en **project.godot** (el check lee de ahí, no del preset) + `texture_format/etc2_astc=true` en el preset (`export_presets.cfg:98` área macOS).
- Verificación de enlaces: `test_agregar_enlace` emite `ERROR: Error opening file … __no_existe__.png` A PROPÓSITO (check del flujo de imagen); no es un fallo.
- Motor local `Godot_v4.7.2-stable_win64(_console).exe` en `K:\Godot_v4.6.1\` (ruta peculiar, así está instalado; `AGENTS.md` la documenta).
- Conv.: tabs, sin comentarios, UI en español, preload-const en vez de class_name en código nuevo, `.gd.uid` versionados, bases `user://__test_*__` limpiadas por los tests.