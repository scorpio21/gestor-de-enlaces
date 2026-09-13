# Limpiar huérfanas y optimizar capturas (#21 + #22) — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redimensionar a máx. 800 px las capturas al copiarlas (#22) y barrer `Assets/png/` eliminando los `img_*.png` huérfanos tanto al cerrar la app como desde el menú «Limpiar capturas huérfanas…» (#21).

**Architecture:** Toda la I/O de ficheros vive en `gestor_imagenes.gd` (estática): `copiar()` incorpora el downscale y se añade `limpiar_huerfanas(referidas)`. `main.gd` solo orquesta: `_rutas_captura_referidas()` junta las rutas `img` de `data.json`, `user://enlaces.json` y `_entradas`; `_hacer_limpieza_capturas()` ejecuta el barrido; el menú decide barra/diálogo de confirmación (`%ConfirmarLimpieza`) y `_exit_tree()` barre en silencio al cerrar.

**Tech Stack:** Godot 4.7.2 (GDScript), harness de tests `SceneTree` headless.

## Global Constraints

- Sin `class_name` nuevo: `const X := preload("res://scripts/...")`.
- Scripts de producción sin comentarios; los tests pueden llevar comentarios de sección `# Catálogo:` / `# Imágenes:`.
- UI en español; textos de barra y de diálogo verbatim de la spec.
- Harness `tests/*.gd`: `extends SceneTree`, `_check(condicion, etiqueta)`, `TESTS OK`+`quit(0)` / `TESTS FALLIDOS: N`+`quit(1)`.
- Comando de tests (pwsh, raíz `K:\gestor-de-enlaces`):
  `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" -s tests/<archivo>.gd`
- Si Godot 4.7.2 dice "Cannot infer the type", tipar explícito (p. ej. `var linea: String`).
- `Image.create_empty(w, h, mipmaps, format)` para generar imágenes de prueba.
- No tocar untracked protegidos: `data/data.json.bak`, `data/data2.json`, y no modificar otras docs.
- `res://Assets/png` es escribible en modo editor; los tests crean/borran sus propios `img_*.png` y archivos temporales y limpian al final. NUNCA borrar capturas reales preexistentes.
- Contrato `copiar` (spec): retorno `{"ok", "destino", "error"}`; si `origen` vacío → `{"ok": true, "destino": "", "error": ""}`.
- Contrato `borrar` (ya existente, plan 2026-09-13-editar-captura): `{"ok", "error"}`.
- Contrato `limpiar_huerfanas` (nuevo): `{"ok", "borradas", "errores"}` (+ `error` cuando `ok false`).
- Base de trabajo: commit `fe614a4` (spec commiteada). Commits directos a `main`.

---

### Task 1: `gestor_imagenes` — downscale en `copiar()` + nuevo `limpiar_huerfanas()`

**Files:**
- Modify: `scripts/gestor_imagenes.gd:4-19` (sustituir `copiar`, añadir `limpiar_huerfanas`)
- Test: `tests/test_gestor_imagenes.gd` (insertar antes del bloque `if _fallos == 0:`)

**Interfaces:**
- Produces:
  - `static func copiar(origen: String) -> Dictionary` — misma firma; además redimensiona a máx. 800 px de ancho (solo downscale, proporción conservada, sin upscale), guarda PNG.
  - `static func limpiar_huerfanas(referidas: Array) -> Dictionary` — barre `res://Assets/png`, borra los `img_*.png` no presentes en `referidas`, devuelve `{"ok": true, "borradas": N, "errores": M}`; carpeta no abrible → `{"ok": false, "borradas": 0, "errores": 0, "error": "No se pudo abrir la carpeta de imágenes."}`.

- [ ] **Step 1: Write the failing test**

Añadir al final de `func _arrancar()` en `tests/test_gestor_imagenes.gd`, justo antes de `if _fallos == 0:`:

```gdscript
	var origen_grande := BASE + "/grande.png"
	var img_g := Image.create_empty(1200, 600, false, Image.FORMAT_RGBA8)
	img_g.fill(Color.CYAN)
	img_g.save_png(origen_grande)
	var rg := GestorImagenesScript.copiar(origen_grande)
	var leida_g: Image = Image.load_from_file(str(rg.get("destino", "")))
	_check(rg.get("ok", false) and not leida_g.is_empty() and leida_g.get_width() <= 800 and leida_g.get_width() > 0, "copiar reduce la imagen a máximo 800 px de ancho")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(str(rg.get("destino", ""))))

	var rs := GestorImagenesScript.copiar(BASE + "/origen.png")
	var leida_s: Image = Image.load_from_file(str(rs.get("destino", "")))
	_check(rs.get("ok", false) and leida_s.get_width() == 4, "copiar conserva el tamaño de imágenes pequeñas")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(str(rs.get("destino", ""))))

	var img_t := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	img_t.fill(Color.ORANGE)
	var lt1 := "res://Assets/png/img_test_lt1.png"
	var lt2 := "res://Assets/png/img_test_lt2.png"
	img_t.save_png(ProjectSettings.globalize_path(lt1))
	img_t.save_png(ProjectSettings.globalize_path(lt2))
	var rl := GestorImagenesScript.limpiar_huerfanas([lt1])
	_check(rl.get("ok", false) and int(rl.get("borradas", -1)) == 1 and int(rl.get("errores", -1)) == 0 and not FileAccess.file_exists(ProjectSettings.globalize_path(lt2)) and FileAccess.file_exists(ProjectSettings.globalize_path(lt1)), "limpiar_huerfanas borra solo las no referidas")
	img_t.save_png(ProjectSettings.globalize_path(lt2))
	var rl2 := GestorImagenesScript.limpiar_huerfanas([lt1, lt2])
	_check(rl2.get("ok", false) and int(rl2.get("borradas", -1)) == 0 and FileAccess.file_exists(ProjectSettings.globalize_path(lt1)) and FileAccess.file_exists(ProjectSettings.globalize_path(lt2)), "limpiar_huerfanas conserva las referidas")
	var txt := ProjectSettings.globalize_path("res://Assets/png/nota_limpieza.txt")
	var f := FileAccess.open(txt, FileAccess.WRITE)
	if f:
		f.store_string("x")
		f.close()
	var rl3 := GestorImagenesScript.limpiar_huerfanas([lt1, lt2])
	_check(rl3.get("ok", false) and FileAccess.file_exists(txt) and int(rl3.get("borradas", -1)) == 0 and int(rl3.get("errores", -1)) == 0, "limpiar_huerfanas ignora no-img_ y reporta contadores enteros")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(lt1))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(lt2))
	DirAccess.remove_absolute(txt)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" -s tests/test_gestor_imagenes.gd`
Expected: parse error (Static function `limpiar_huerfanas()` not found) y/o `FALLO: copiar reduce la imagen a máximo 800 px de ancho`, `TESTS FALLIDOS: N`.

- [ ] **Step 3: Write minimal implementation**

Sustituir TODO el `static func copiar(...)` actual de `scripts/gestor_imagenes.gd` y añadir `limpiar_huerfanas` al final del archivo:

```gdscript
static func copiar(origen: String) -> Dictionary:
	if origen.is_empty():
		return {"ok": true, "destino": "", "error": ""}

	var carpeta := ProjectSettings.globalize_path("res://Assets/png")
	var err := DirAccess.make_dir_recursive_absolute(carpeta)
	if err != OK:
		return {"ok": false, "destino": "", "error": "No se pudo crear la carpeta de imágenes."}

	var destino := "res://Assets/png/img_%d.png" % int(Time.get_unix_time_from_system())
	var img: Image = Image.load_from_file(origen)
	if img == null or img.is_empty():
		return {"ok": false, "destino": "", "error": "No se pudo copiar la imagen."}
	const ANCHO_MAX := 800
	if img.get_width() > ANCHO_MAX:
		var alto := maxi(1, int(float(img.get_height()) * ANCHO_MAX / float(img.get_width())))
		img.resize(ANCHO_MAX, alto, Image.INTERPOLATE_CUBIC)
	if img.save_png(ProjectSettings.globalize_path(destino)) != OK:
		return {"ok": false, "destino": "", "error": "No se pudo copiar la imagen."}
	return {"ok": true, "destino": destino, "error": ""}


static func limpiar_huerfanas(referidas: Array) -> Dictionary:
	var carpeta := DirAccess.open("res://Assets/png")
	if carpeta == null:
		return {"ok": false, "borradas": 0, "errores": 0, "error": "No se pudo abrir la carpeta de imágenes."}
	var referidas_str: Array = []
	for r in referidas:
		referidas_str.append(str(r))
	var borradas := 0
	var errores := 0
	for f in carpeta.get_files():
		if not (f.begins_with("img_") and f.ends_with(".png")):
			continue
		var ruta := "res://Assets/png/%s" % f
		if ruta in referidas_str:
			continue
		if borrar(ruta).get("ok", false):
			borradas += 1
		else:
			errores += 1
	return {"ok": true, "borradas": borradas, "errores": errores}
```

- [ ] **Step 4: Run test to verify it passes**

Run igual que Step 2.
Expected: 13 líneas `  OK:` (8 previas + 5 nuevas) y `TESTS OK`.

- [ ] **Step 5: Commit**

```bash
git add scripts/gestor_imagenes.gd tests/test_gestor_imagenes.gd
git commit -m "feat: copiar redimensiona a 800px y limpiar_huerfanas barre Assets/png (#21 #22)"
```

---

### Task 2: `main` — menú, confirmación y barrido al cerrar

**Files:**
- Modify: `scripts/main.gd` (`_ready`, `_configurar_menus`, `_on_utilidades_id`, miembros, funciones nuevas + `_exit_tree`)
- Modify: `scenes/Main.tscn` (añadir `%ConfirmarLimpieza` tras `ConfirmarBorrado`)
- Test: `tests/test_main_barra.gd` (helpers existentes + bloque de limpieza)

**Interfaces:**
- Consumes: `GestorImagenesScript.limpiar_huerfanas(referidas) -> Dictionary` (Task 1); `_leer_array(path)` de `main.gd` (ya existe); `%ConfirmarLimpieza` (nuevo, `ConfirmationDialog`).
- Produces:
  - `func _rutas_captura_referidas() -> Array`
  - `func _hacer_limpieza_capturas() -> Dictionary`
  - `func _solicitar_limpieza_capturas() -> void`
  - `func _confirmar_limpieza() -> void`
  - `func _exit_tree() -> void`

- [ ] **Step 1: Write the failing test**

a) En `tests/test_main_barra.gd`, añadir tras el bloque `# Catálogo: capturas ...` (justo antes de `_limpiar_capturas()` que cierra ese bloque y del bloque `# Catálogo: copiar URL desde la fila...` un bloque nuevo):

```gdscript
	# Catálogo: limpieza de capturas huérfanas
	var sin_huerfana := _crear_captura("img_test_ok.png")
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": sin_huerfana}]
	main_script._on_utilidades_id(2)
	_check(main.get_node("%Progreso").text == "No hay capturas huérfanas.", "limpieza sin huérfanas informa en la barra")

	var huerfana := _crear_captura("img_test_huerfana.png")
	main_script._on_utilidades_id(2)
	var confirma: AcceptDialog = main.get_node("%ConfirmarLimpieza")
	_check(confirma.visible and confirma.dialog_text.contains("1"), "limpieza con huérfana pide confirmación")
	confirma.confirmed.emit()
	_check(not FileAccess.file_exists(ProjectSettings.globalize_path(huerfana)), "confirmar limpieza borra la huérfana")
	_check(main.get_node("%Progreso").text == "Capturas huérfanas eliminadas: 1", "confirmar limpieza informa en la barra")

	var ref_huerfana := _crear_captura("img_test_ref.png")
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": ref_huerfana}]
	main_script._on_utilidades_id(2)
	_check(FileAccess.file_exists(ProjectSettings.globalize_path(ref_huerfana)), "limpieza conserva la captura referenciada")

	var huerfana_exit := _crear_captura("img_test_exit.png")
	main_script._exit_tree()
	_check(not FileAccess.file_exists(ProjectSettings.globalize_path(huerfana_exit)), "al cerrar la app se barre lo huérfano")
```

b) `_exit_tree()` se ejecuta también cuando el harness libera el nodo Main al hacer `quit()`; es inofensivo (segunda pasada con 0 huérfanas).

- [ ] **Step 2: Run test to verify it fails**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" -s tests/test_main_barra.gd`
Expected: parse error (`_rutas_captura_referidas`/`_limpiar_...`/`_exit_tree` no existen o `%ConfirmarLimpieza` no está) y/o `FALLO:` varios, `TESTS FALLIDOS: N`. Pueden quedar `img_test_*` a mitad de la corrida roja (se limpian en la verde; si molestan, borrar manualmente antes de la corrida GREEN).

- [ ] **Step 3: Write minimal implementation**

a) En `scenes/Main.tscn`, tras el bloque `[node name="ConfirmarBorrado" ...]`:

```
[node name="ConfirmarLimpieza" type="ConfirmationDialog" parent="."]
unique_name_in_owner = true
title = "Limpiar capturas huérfanas"
ok_button_text = "Limpiar"
```

b) En `scripts/main.gd`:

- `_ready` (tras `%ConfirmarBorrado.confirmed.connect(_confirmar_borrado)`):

```gdscript
	%ConfirmarLimpieza.confirmed.connect(_confirmar_limpieza)
```

- Miembro nuevo (junto a `var _persistir := true`):

```gdscript
	var _limpieza_resultado: Dictionary = {}
```

- En `_configurar_menus`, dentro del bloque de `menu_util`:

```gdscript
	menu_util.add_item("Limpiar capturas huérfanas…", 2)
```

- En `_on_utilidades_id`, tras el `elif id == 1:`:

```gdscript
	elif id == 2:
		_solicitar_limpieza_capturas()
```

- Funciones nuevas (añadir tras `_on_utilidades_id`):

```gdscript
func _rutas_captura_referidas() -> Array:
	var rutas := {}
	for lista in [_leer_array(DATA_RES), _leer_array(DATA_USER), _entradas]:
		for entrada in lista:
			if typeof(entrada) != TYPE_DICTIONARY:
				continue
			var ruta := str(entrada.get("img", ""))
			if not ruta.is_empty():
				rutas[ruta] = true
	return rutas.keys()


func _hacer_limpieza_capturas() -> Dictionary:
	return GestorImagenesScript.limpiar_huerfanas(_rutas_captura_referidas())


func _solicitar_limpieza_capturas() -> void:
	var res := _hacer_limpieza_capturas()
	_limpieza_resultado = res
	if not res.get("ok", false):
		progreso.text = str(res.get("error", "No se pudo limpiar las capturas."))
		return
	var borradas := int(res.get("borradas", 0))
	if borradas == 0:
		progreso.text = "No hay capturas huérfanas."
		return
	%ConfirmarLimpieza.dialog_text = "¿Borrar %d capturas huérfanas?" % borradas
	%ConfirmarLimpieza.popup_centered()


func _confirmar_limpieza() -> void:
	var res := _limpieza_resultado
	_limpieza_resultado = {}
	var borradas := int(res.get("borradas", 0))
	var errores := int(res.get("errores", 0))
	var texto := "Capturas huérfanas eliminadas: %d" % borradas
	if errores > 0:
		texto += " (%d errores)" % errores
	progreso.text = texto


func _exit_tree() -> void:
	_hacer_limpieza_capturas()
```

- Preload ya existente: `const GestorImagenesScript := preload("res://scripts/gestor_imagenes.gd")` en `scripts/main.gd:10` (no añadir otra línea).

- [ ] **Step 4: Run test to verify it passes**

Run igual que Step 2.
Expected: 52 líneas `  OK:` (47 previas + 5 nuevas) y `TESTS OK`.

- [ ] **Step 5: Batería completa (regresión)**

Run (en paralelo desde pwsh):

```pwsh
$godot = "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path "K:\gestor-de-enlaces" -s tests/test_config_store.gd
& $godot --headless --path "K:\gestor-de-enlaces" -s tests/test_gestor_contadores.gd
& $godot --headless --path "K:\gestor-de-enlaces" -s tests/test_gestor_imagenes.gd
& $godot --headless --path "K:\gestor-de-enlaces" -s tests/test_preferencias.gd
& $godot --headless --path "K:\gestor-de-enlaces" -s tests/test_estado_store.gd
& $godot --headless --path "K:\gestor-de-enlaces" -s tests/test_link_checker_timeout.gd
& $godot --headless --path "K:\gestor-de-enlaces" -s tests/test_list_item.gd
& $godot --headless --path "K:\gestor-de-enlaces" -s tests/test_main_barra.gd
& $godot --headless --path "K:\gestor-de-enlaces" -s tests/test_gestor_catalogo.gd
& $godot --headless --path "K:\gestor-de-enlaces" -s tests/test_agregar_enlace.gd
```

Expected: 10 suites terminan cada una con `TESTS OK` (test_gestor_imagenes con 13, test_main_barra con 52, resto con sus conteos previos). Nota esperada: al liberarse Main, `_exit_tree()` del test_main_barra vuelve a barrer y limpia cualquier `img_*` residual. Smokes opcionales:
`& $godot --headless --path "K:\gestor-de-enlaces" --check-only --quit-after 120` (exit 0) y `& $godot --headless --path "K:\gestor-de-enlaces" res://scenes/Main.tscn --quit-after 5` (exit 0).

- [ ] **Step 6: Commit**

```bash
git add scripts/main.gd scenes/Main.tscn tests/test_main_barra.gd
git commit -m "feat: limpieza de capturas huérfanas desde menú y al cerrar (#21)"
```

---

## Self-Review (plan contra spec)

**Cobertura de la spec:**
- #22 en `copiar()` (800 px, solo downscale, proporción, PNG, contrato intacto) → Task 1. ✓
- `limpiar_huerfanas` (convención `img_*.png`, referidas, `ok/borradas/errores`, carpeta no abrible) → Task 1. ✓
- Referencias union (`data.json` + `user://enlaces.json` + `_entradas`, dedupe por dict) → Task 2 (`_rutas_captura_referidas`). ✓
- Menú `Utilidades` item 2 + `_solicitar_limpieza_capturas` (0 → barra «No hay capturas huérfanas.»; >0 → `%ConfirmarLimpieza` «¿Borrar N capturas huérfanas?») → Task 2. ✓
- `_confirmar_limpieza` con «Capturas huérfanas eliminadas: N» y «(%d errores)» → Task 2. ✓
- `_exit_tree()` barrido silencioso → Task 2. ✓
- Pruebas spec: test_gestor_imagenes 8→13 (los 6 bullets se agrupan en 5 checks: bullet 1→C1, 2→C2, 3→C3, 4→C4, 5+6→C5) → Task 1. test_main_barra 47→52 (5 checks: sin huérfanas, confirmación, confirmar borra, conserva referida, exit barre) → Task 2. ✓
- Casos borde de la tabla (copiar vacío/ilegible, carpeta no abrible, no-`img_*`, errores en barrido, cierre sin diálogo) cubiertos por código o tests. ✓
- Fuera de alcance: `_confirmar_borrado`, esquema de datos (#5), ancho configurable → no tocados. ✓

**Placeholder scan:** sin TBD/TODO; todos los pasos llevan código verbatim y comandos exactos.

**Consistencia de tipos:** `limpiar_huerfanas(referidas: Array) -> Dictionary` y `copiar(origen: String) -> Dictionary` idénticos en Task 1 y Task 2; `_leer_array(path) -> Array` (existente) consumido tal cual; claves `borradas`/`errores` consistentes; nombres `_rutas_captura_referidas`/`_hacer_limpieza_capturas`/`_solicitar_limpieza_capturas`/`_confirmar_limpieza`/`_limpieza_resultado`/`%ConfirmarLimpieza` invariantes en todo el plan. ✓