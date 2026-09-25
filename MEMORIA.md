# MEMORIA — GestorAO

## Objetivo

Repositorio `K:\gestor-de-enlaces` (Godot 4.7.2, GDScript) — gestor de enlaces para Argentum Online: funcionalidad base + empaquetado (presets + CI + logs + diagnóstico + icono) + catálogo completo (etiquetas, filtros avanzados, grilla, dashboard, i18n, tema, capturas con nombre) **COMMITEADO y pusheado en `main`**. HEAD: `f27e943` (v0.1.9 + fixes de ventana 1440×810 y export .exe). Batería local **33/33 OK**, `git status` limpio, **0 issues abiertos** en GitHub.

## Comandos de verificación

Batería completa (33 suites) vía Git Bash (mismo script que el CI):

```bash
& "C:\Program Files\Git\bin\bash.exe" -c 'cd /k/gestor-de-enlaces && GODOT_BIN="K:/Godot_v4.6.1/Godot_v4.7.2-stable_win64_console.exe" bash tests/run_battery.sh'
```

Suite suelta (Windows pwsh):

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_<area>.gd
```

Linux/CI: `GODOT_BIN=/ruta/a/godot bash tests/run_battery.sh`. Cada suite imprime `TESTS OK` y `quit(0)`; `run_battery.sh` con `set -e` falla en la primera suite roja.

## Estado actual

- ✅ HEAD `f27e943` (v0.1.9 + fixes de ventana y export .exe) pusheado a `origin/main`; battery local **33/33 OK**; `git status` limpio (sin untracked ni modificados).
- ✅ **0 issues abiertos** en GitHub: toda la secuencia #25..#47 cerrada.
- ✅ Ronda de versiones: 0.1.0 (empaquetado #26/#28/#29) → 0.1.9 (capturas con nombre #47). Últimas: etiquetas (#42), filtros avanzados + presets (#44 en 0.1.2/0.1.3), grilla (#43 0.1.4), dashboard (#45 0.1.5), dedup de capturas (#36 0.1.6), tema automático (#46 0.1.7), diálogos nativos (#38 0.1.8), caché reverse-lookup (#40), capturas con nombre (#47 0.1.9).
- ✅ **#41 residuos cerrado** (`c2d9e70`): versionado el addon tercero `addons/godot_ai` (Godot AI v3.2.1, MIT) + bloque `[autoload]/[editor_plugins]` de `project.godot` (el addon retira su autoload MCP de los exports); `export_presets.cfg` regenerado por el editor 4.7; metadatos Godot pendientes (16 `.uid`, 2 `.translation`, 7 `.import`). Eliminados localmente `data/data2.json` (sin uso) y 2 `.import` huérfanos de `Assets/png`. Planes ajenos sin commitear en `.gitignore`.
- ⏳ Backlog: ninguno. El CHANGELOG acumula en `[Sin publicar]` #30 (i18n), #17 (ordenación) y #40 (caché) sin elevar a release todavía.

## Historial de trabajo (Grupo C: después de la base `0a77542`)

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

## Historial reciente (post `2327784` → `c2d9e70`, 62 commits)

- **#27 aviso de versión + #6 orden manual**: comparador de versiones y consulta de `releases/latest` (TDD), aviso 1 vez por versión; menú contextual Subir/Bajar con persistencia y tests.
- **#17 ordenación por columnas**: cabeceras pulsables con criterio persistido en config.
- **#30 i18n ES/EN**: `config_store` valida el idioma, CSV `locale/gestor_es_en.csv` + scanner (`extraer_cadenas.gd`) + test de cobertura (`test_locale.gd`), banderas de idioma en `Assets/banderas`, selector en Preferencias y `tr()` runtime (re-traducción en vivo de estado/tooltip/historial/menús/filtros).
- **Mejoras de base**: filtro de búsqueda también por URL (#35, `filtros.gd`), límite de concurrencia por dominio (#37, `cola_escaneo.gd`), persistencia de filtros entre sesiones (#39), refactor de `main.gd` en bloques `_ui_*`/`_scan_*` y división de `test_main_barra.gd` en 4 suites.
- **Ronda de versiones**: 0.1.1 #42 etiquetas + barra coloreada, 0.1.2 filtros avanzados #44, 0.1.3 presets + filtro días, 0.1.4 grilla #43, 0.1.5 dashboard #45, 0.1.6 dedup capturas #36 (`b9378fb`), 0.1.7 tema auto #46 (`2ef5989`), 0.1.8 diálogos nativos #38 (`47da575`), 0.1.9 capturas con nombre #47 (`a9ef48d`).
- **#40 caché reverse-lookup** (`0d5fcb4`) y **#41 residuos** (`c2d9e70`).
- `2ece4b7` (commit ajeno del usuario): tema completo programático + catálogo con etiquetas y `data/data.json` real.

## Próximos pasos

1. Ningún issue abierto: la siguiente tarea es decisión del usuario (idea nueva o elevar `[Sin publicar]` de #30/#17/#40 con bump de versión).
2. Si se abre el editor y guarda, `export_presets.cfg` se re-reescribe a su formato; comitear el cambio (AGENTS.md).
3. `MEMORIA.md` y `README.md`/`CHANGELOG.md` se mantienen al día en cada ronda.

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
- El editor Godot 4.7 re-reescribe `export_presets.cfg` a su formato al guardar (`[runnable_presets]`, `export_path="..//"`, knobs nuevos); la CI exporta con rutas explícitas → comitear tal cual (AGENTS.md).
- Si `addons/godot_ai/` estuviera en `.gitignore`, el editor reinstala el plugin en `project.godot` (`[editor_plugins]` + autoload `_mcp_game_helper`) al detectarlo → `project.godot` se re-ensuciaría; por eso el addon se versionó (#41).
- El addon `godot_ai` incluye un `EditorExportPlugin` (`export/mcp_export_plugin.gd`) que retira el autoload MCP de los builds exportados: no llega a los juegos finales.
- pwsh corrompe bytes al redirigir la salida de `git` a fichero → para salida byte-safe usar `cmd /c "... > <tmp>"` o redirección dentro de bash.
- `git update-index --cacheinfo "100644,<blob>,project.godot"` (string única) servía para el "blob dance" (index ≠ worktree) al bumpear versión sin versionar el addon; ya no hace falta tras `c2d9e70`.
- UTF-8 sin BOM: `[IO.File]::WriteAllText` produce `C3 AD` válido (la consola puede mostrarlo como "�", pero es correcto). `gh issue close --comment` con `>` u otros caracteres que pwsh parsee: evitarlos.
- El ancho mínimo de la fila de acciones (12 controles, filtros #44) superaba la ventana default de 1152 px (en realidad nunca hubo `viewport_width/height` en project.godot → Godot usa 1152×648): el contenido desbordaba y se cortaba por ambos lados. Arreglado con base 1440×810 (`display/window/size`) y `BarraAcciones` como `FlowContainer` — su mínimo horizontal es el del hijo MÁS ANCHO (no la suma) y hace wrap al encoger, así que nunca vuelve a cortarse.
- Los uids de escena escritos a mano en las cabeceras `.tscn` (`uid://hpreferencias001`, `uid://bhistorial0001`, `uid://bgestoritem001/002`) NO están registrados en `uid_cache.bin`, y `uid://cxtkcrqj7ne7i`/`cup4r7bqx0age` (13 chars) desbordan int64 → uids inválidos. Consecuencias: (1) al exportar, el pack convierte las escenas a `.scn` y las resuelve por uid → `Cannot get class ''` y placeholders en `VentanaAgregar`/`VentanaPreferencias`; (2) **al guardar `Main.tscn` desde el editor, este BORRA silenciosamente los nodos instanciados cuya referencia por ruta apunta a una escena con uid fake en su cabecera** (tras el guardado del editor: `Node not found: "%VentanaAgregar"`). El patrón que sobrevive al guardado es una instancia con `uid=` explícito en la referencia O un destino SIN uid en su cabecera. Arreglo definitivo: escenas SIN uid de cabecera (patrón `Dashboard.tscn`, la única que nunca dio problemas) + referencias solo por ruta en `Main.tscn`. Verificación: `--export-pack "Windows" build/x.pck` + `godot --headless --main-pack x.pck`, y export completo + correr `gestor-de-enlaces.console.exe` (stderr vacío).
- Motor local `Godot_v4.7.2-stable_win64(_console).exe` en `K:\Godot_v4.6.1\` (ruta peculiar; `AGENTS.md`).
- Conv.: tabs, sin comentarios, UI en español, preload-const en vez de class_name en código nuevo, `.gd.uid` versionados, bases `user://__test_*__` limpiadas.
