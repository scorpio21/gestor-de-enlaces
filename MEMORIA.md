# MEMORIA — GestorAO

## Objetivo

Repositorio `K:\gestor-de-enlaces` (Godot 4.7.2, GDScript) — gestor de enlaces para Argentum Online. Funcionalidad base + empaquetado (presets + CI + logs + diagnóstico + icono) + escaneo persistido (#13) + informe CSV/HTML (#11) + tema claro/oscuro (#19) **COMMITEADO y pungeado en `main`**. BASE local: `0a77542` → HEAD: `2327784`.

## Comandos de verificación

Batería completa (20 suites) vía Git Bash (mismo script que el CI):

```bash
& "C:\Program Files\Git\bin\bash.exe" -c 'cd /k/gestor-de-enlaces && GODOT_BIN="K:/Godot_v4.6.1/Godot_v4.7.2-stable_win64_console.exe" bash tests/run_battery.sh'
```

Suite suelta (Windows pwsh):

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_<area>.gd
```

Linux/CI: `GODOT_BIN=/ruta/a/godot bash tests/run_battery.sh`. Cada suite imprime `TESTS OK` y `quit(0)`; `run_battery.sh` con `set -e` falla en la primera suite roja.

## Estado actual

- ✅ Grupo C empaquetado COMPLETO (base `0a77542`), CI verde.
- ✅ **#13** cola de escaneo persistida (`user://colas.json`) + reanudación por diálogo — commits `9c610d0`..`bf140b6`.
- ✅ **#11** informe de disponibilidad CSV/HTML (`scripts/informe_store.gd`, menú Archivo id 5 + `%DialogoInforme`) — commits `e917357`..`99de9b2`.
- ✅ **#19** tema claro/oscuro configurable (`scripts/tema_store.gd`, `%Tema` en Preferencias) — commits `f45ff67`..`2327784`.
- ✅ HEAD `2327784` pungeado a `origin/main`; battery local **20/20 OK**.
- ⚠️ Abiertas en GitHub: **#30** (i18n ES/EN), **#27** (auto-actualización), **#17** (ordenación tabla), **#6** (orden manual persistido).
- ⏳ Abierto en local (sin commitear, NO tocar): `Assets/icon/icon.svg.import`, `Assets/icon/icon_256.png.import`, `data/data2.json`, `docs/superpowers/plans/2026-09-05-captura-enlaces.md`, `docs/superpowers/plans/2026-09-19-ampliar-detectores-enlace-caido.md`, `scripts/historial.gd.uid`.

## Historial de trabajo (después de la base `0a77542`)

- `15d7665` feat(escaneo): marcas de enlace caído por host (MEGA/MediaFire/Drive/Sites/Dropbox/WeTransfer) con fallback genérico
- `0e336a4` feat(escaneo): `_parece_muerto` aplica marcas por host actual (unión con genéricas)
- `9c610d0` docs(spec): diseño de #13 — cola de escaneo persistida con reanudación (#13)
- `a050249` feat(escaneo): store de cola persistida `user://colas.json` (cargar/guardar/limpiar) con tests (#13)
- `24b6b25` feat(escaneo): persistir la cola de comprobación en `user://colas.json` en cada avance (#13)
- `bf140b6` feat(escaneo): dialogo y logica de reanudacion de escaneo interrumpido (`ConfirmarReanudar`) (#13)
- `e917357` docs(spec): #11 informe de disponibilidad CSV/HTML (`informe_store.gd`)
- `30c8df8` docs(spec): #11 aclarar manejo de extensión en `_formato_informe`
- `c550fc1` feat(informe): store CSV/HTML con `exportar_csv`/`exportar_html` y tests (TDD) (#11)
- `99de9b2` feat(informe): menu Archivo + FileDialog + `_on_informe_elegido` (CSV/HTML) con checks de integracion (#11)
- `f45ff67` docs(spec): #19 tema claro/oscuro configurable (`tema_store.gd`)
- `b365ceb` feat(tema): store claro/oscuro con paletas, `color_estado` y `aplicar` (TDD) (#19)
- `681dc8b` feat(tema): `config_store.tema` persistido y selector `%Tema` en Preferencias (#19)
- `2327784` feat(tema): aplicacion en `_ready` y preferencias; `list_item` pinta con paleta (#19)

Entregables: `scripts/cola_store.gd`, `scripts/informe_store.gd`, `scripts/tema_store.gd`, `tests/test_cola_store.gd`, `tests/test_informe_store.gd`, `tests/test_tema_store.gd`, specs en `docs/superpowers/specs/`, plans en `docs/superpowers/plans/`; `%DialogoInforme`, `%Tema` en escenas; checks de integración en `tests/test_main_barra.gd`. Batería ahora 20 suites.

## Próximos pasos

1. Siguiente issue sugerida (orden del usuario): **#30** Internacionalización ES/EN — requiere espec+plan antes de implementar (patrón superpowers).
2. Backlog restante: #27 (auto-actualización, por decidir), #17 (vista de tabla), #6 (orden manual persistido).
3. `scripts/historial.gd.uid` y los `.import` de Assets/icon siguen untracked; engánchalos cuando se toquen. `docs/superpowers/specs/` documenta los diseños por grupo; un nuevo grupo hace spec antes de código.

## Gotchas verificados (no repetir investigación)

- CORRECTION: la tpz de export templates **SÍ lleva subcarpeta `templates/` dentro** (`export_presets.cfg`); el contenido debe quedar DIRECTO en `~/.local/share/godot/export_templates/4.7.2.stable/`.
- En checkout fresco (CI) no existe `.godot/`: un `--headless --script` sin importar antes **se cuelga**. Obligatorio `godot --headless --path . --import` (≈5 s) antes de la batería.
- Preset macOS: `binary_format/architecture="universal"`; exige `rendering/textures/vram_compression/import_etc2_astc=true` en **project.godot** + `texture_format/etc2_astc=true` en el preset.
- Red de un test: si el "red" deja el script con error de parseo (firma cambiada), el test **se cuelga** (no llega a `quit()`). En Task 2 de #19 ocurrió con `aplicado` de 4→5 args: matar `Get-Process *Godot*` y capturar salida a fichero (`2>&1 | Tee-Object`) para ver el parse error.
- Godot 4.7 **solo admite ids `int` en `OptionButton`** (`popup/item_N/id`); ids `String` fallan en parse ("Invalid operands int and String"). `%Tema` usa 0/1 y mapea a `"oscuro"/"claro"` en `preferencias.gd:45`.
- `Time.get_datetime_dict_from_unix_time` devuelve **UTC** (no hora local): el check del CSV de #11 usa `2020-09-13 12:26;` en UTC, no hora local.
- Tema oscuro = aspecto actual literal: Main `Fondo` 0.10, diálogos 0.12; en claro 0.95. `tema_store.aplicar()` guarda el color original por `instance_id` para restaurar en oscuro (idempotente, `scripts/tema_store.gd`).
- `OptionButton.get_selected_id()` devuelve `int`; leer color de override con `node.get("theme_override_colors/font_color")` (null si no existe) — verificado empíricamente.
- `test_agregar_enlace` emite `ERROR: Error opening file … __no_existe__.png` A PROPÓSITO; no es fallo.
- Motor local `Godot_v4.7.2-stable_win64(_console).exe` en `K:\Godot_v4.6.1\` (ruta peculiar; `AGENTS.md`).
- Conv.: tabs, sin comentarios, UI en español, preload-const en vez de class_name en código nuevo, `.gd.uid` versionados, bases `user://__test_*__` limpiadas.