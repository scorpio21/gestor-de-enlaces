# Implementación: Importar/Exportar JSON, Atajos de teclado y Tests de link_checker

Fecha: 2026-09-14
Issues: #3 (importar/exportar), #14 (atajos de teclado), #31 (tests de link_checker)
Spec: `docs/superpowers/specs/2026-09-14-importar-exportar-atajos-tests-design.md` (commit `47d5834`)

## Goal

1. **#3** — Importar y exportar el catálogo como JSON desde el menú `Archivo`, con saneado y fusión con deduplicación por `clave_unica` (nunca toca `estado_store`).
2. **#14** — Atajos de teclado: `Ctrl+F` (buscar), `Ctrl+N` (agregar), `Ctrl+R` (comprobar), `Esc` (cerrar ventana/popup activa).
3. **#31** — Ampliar `test_link_checker_timeout.gd` de 4 a ~20 comprobaciones sin red (helpers puros + `comprobar()` de URLs inválidas síncronas).

## Architecture Notes

- El importado/exportado vive en un helper estático nuevo `scripts/gestor_archivo.gd` (RefCounted), testeable sin escena, siguiendo el patrón `gestor_*.gd`.
- La UI (#3 y #14) son cambios acotados en `scenes/Main.tscn` + `scripts/main.gd`; no se toca `estado_store.gd`.
- Los atajos se definen en `project.godot` sección `[input]` (acciones `atajo_buscar`, `atajo_agregar`, `atajo_comprobar`); `Esc` usa la acción integrada `ui_cancel`.
- `link_checker.gd` no cambia: el texto de #31 está anticuado (`void_marker`/`ultracheck_status`/`parse_http_code` no existen). Se cubre el código real (helper `MARCAS_MUERTO`, `_parece_muerto`, `_parsear_url`, `_resolver_redirect`, `comprobar` sin red). Quirk conocido de `_resolver_redirect` (relativos sin `/` no expanden barra): se documenta en test, no se corrige.

## Tech Stack

- Godot 4.7.2 headless: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/<archivo>.gd`
- Harness de tests: `extends SceneTree`, `_check(cond, nombre)` + contador `_fallos`, salida `TESTS OK:`/`TESTS FALLIDOS: N` y exit 0/1.
- Rojo: los comandos dependen de `bash` (herramienta del harness). Usar la shell con rutas entre comillas.

## Global Constraints

1. **GDScript repos:** sin `class_name`; `const XScript := preload("res://scripts/x.gd")`; tabs; sin comentarios en producción (los tests pueden tener); nombres en minúscula_con_guion; labels y mensajes de test en español.
2. **Quirk del motor (verificado):** `PackedStringArray("un_solo_string")` es Parse Error en GDScript `.gd`, pero `.tscn` sí lo acepta (genera array de 1 elemento). En `gestor_archivo.gd` (GDScript) usar `PackedStringArray([ "..."] )` o `PackedStringArray()` con push_back; en `Main.tscn` se puede escribir `filters = PackedStringArray("*.json ; Archivo JSON")`.
3. **Quirk del motor (verificado):** `Window` no tiene `resizable`, solo `unresizable`. No tocar `resizable` en `Main.tscn` (no aparece hoy; no añadirlo).
4. **Quirk del motor (verificado):** `popup_centered()` en headless clobberea `Window.size` a (1,1). No afecta a los FileDialog nuevos (su tamaño lo decide el OS); no fijar `min_size` obligatorio.
5. **Archivos protegidos/untracked (nunca commitear):** `data/data.json.bak`, `data/data2.json`, `docs/superpowers/plans/2026-09-05-captura-enlaces.md`.
6. Importar **no persiste** si el resultado es vacío (`entradas.is_empty()` → solo mensaje). Nunca borra; solo fusiona.
7. El import no toca `_estados`, `_borrados` ni `estado_store`: los enlaces importados quedan "sin comprobar".
8. Los `.tscn` se editan a mano con el formato texto; los archivos `.gd.uid` nuevos (generados por Godot al primer parseo) **se commitean**.
9. Commit por tarea con los mensajes indicados; no mezclar cambios de tareas distintas.
10. Batería final = 11 suites (ver Verification); el número de checks por archivo debe cumplirse (gestor_archivo 14, main_barra 81, link_checker_timeout 20).

---

## Task 1 — #3 Importar/Exportar JSON del catálogo

Files:
- Create: `scripts/gestor_archivo.gd`, `tests/test_gestor_archivo.gd` (+ sus `.gd.uid` generados).
- Modify: `scenes/Main.tscn`, `scripts/main.gd`, `tests/test_main_barra.gd`.

Steps (TDD):

### Step 1 — RED: `tests/test_gestor_archivo.gd`

Escribir el test (14 checks). Copiar el esqueleto de `test_estado_store.gd` (var `_fallos`) y usar rutas en `user://__test_gestor_archivo__...`:

```gdscript
extends SceneTree

const GestorArchivoScript := preload("res://scripts/gestor_archivo.gd")
const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
const BASE := "user://__test_gestor_archivo__"
const RUTA := BASE + "/catalogo.json"
const MIXTO := BASE + "/mixto.json"

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	DirAccess.make_dir_recursive_absolute(BASE)

	var entradas := [
		{"nombre": "A", "desc": "Uno", "url": "HTTPS://X.test/", "img": "res://Assets/png/img_a.png", "cat": "Patch"},
		{"nombre": "B", "desc": "Dos", "url": "https://bb.test/x", "img": "", "cat": "otro", "extracampo": 7},
	]

	var re := GestorArchivoScript.exportar(RUTA, entradas)
	_check(re.get("ok", false) and int(re.get("total", -1)) == 2, "exportar escribe el catálogo y cuenta entradas")

	var leido: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA))
	_check(typeof(leido) == TYPE_ARRAY and (leido as Array).size() == 2, "el archivo exportado es un JSON de array")

	var primero: Dictionary = (leido as Array)[0]
	_check(not primero.has("extracampo") and str(primero.get("nombre", "")) == "A", "exportar conserva solo los campos del catálogo")

	var re_err := GestorArchivoScript.exportar(BASE + "/nohay/c.json", [])
	_check(not re_err.get("ok", true) and not str(re_err.get("error", "")).is_empty(), "exportar a una carpeta inexistente falla con error")

	var ri_faltante := GestorArchivoScript.importar(BASE + "/no-existe.json", [])
	_check(not ri_faltante.get("ok", true) and str(ri_faltante.get("error", "")) == "El archivo no es un catálogo válido.", "importar un archivo inexistente falla con el mensaje de catálogo inválido")

	var f_noarr := FileAccess.open(BASE + "/no-array.json", FileAccess.WRITE)
	f_noarr.store_string("{\"a\":1}")
	f_noarr.close()
	var ri_noarr := GestorArchivoScript.importar(BASE + "/no-array.json", [])
	_check(not ri_noarr.get("ok", true) and str(ri_noarr.get("error", "")) == "El archivo no es un catálogo válido.", "importar un JSON que no es array falla con el mismo mensaje")

	var ri_rt := GestorArchivoScript.importar(RUTA, [])
	var entradas_rt: Array = ri_rt.get("entradas", [])
	_check(ri_rt.get("ok", false) and entradas_rt.size() == 2, "importar roundtrip devuelve las entradas saneadas")

	var ent0: Dictionary = entradas_rt[0]
	var ent1: Dictionary = entradas_rt[1]
	_check(str(ent0.get("url", "")) == "https://x.test" and str(ent0.get("cat", "")) == "parche", "importar normaliza url y categoría")
	_check(str(ent0.get("img", "")) == "res://Assets/png/img_a.png", "importar conserva el campo img")
	_check(not ent1.has("extracampo") and str(ent1.get("url", "")) == "https://bb.test/x", "importar conserva solo campos conocidos")

	var mezclado: Array = [
		"texto",
		42,
		{"nombre": "A", "url": "https://x.test"},
		{"nombre": "C", "url": "https://c.test"},
		{"nombre": "C2", "url": "https://C.test"},
		{"nombre": "vacía", "url": ""},
	]
	var f_mixto := FileAccess.open(MIXTO, FileAccess.WRITE)
	f_mixto.store_string(JSON.stringify(mezclado, "\t"))
	f_mixto.close()

	var ri_m := GestorArchivoScript.importar(MIXTO, ["https://x.test"])
	var entradas_m: Array = ri_m.get("entradas", [])
	_check(ri_m.get("ok", false) and entradas_m.size() == 1 and str(entradas_m[0].get("url", "")) == "https://c.test", "importar sanea: omite no-dicts, sin URL, duplicados (externos e internos)")
	_check(int(ri_m.get("omitidas", -1)) == 5, "importar cuenta las omitidas")

	var ri_todo := GestorArchivoScript.importar(MIXTO, ["https://x.test", "https://c.test", "https://C.test", "https://c.test/"])
	_check((ri_todo.get("entradas", []) as Array).is_empty(), "importar con existentes que ya cubren todo no añade nada")

	var re_vacio := GestorArchivoScript.exportar(BASE + "/vacio.json", [])
	_check(re_vacio.get("ok", false) and int(re_vacio.get("total", -1)) == 0 and FileAccess.get_file_as_string(BASE + "/vacio.json") == "[]", "exportar un catálogo vacío produce un JSON vacío")

	var f_solo_vacias := FileAccess.open(BASE + "/solo-vacias.json", FileAccess.WRITE)
	f_solo_vacias.store_string(JSON.stringify([{"nombre": "S", "url": ""}], "\t"))
	f_solo_vacias.close()
	var ri_sv := GestorArchivoScript.importar(BASE + "/solo-vacias.json", [])
	_check(ri_sv.get("ok", false) and (ri_sv.get("entradas", []) as Array).is_empty() and int(ri_sv.get("omitidas", -1)) >= 1, "importar con solo entradas sin URL devuelve ok y entradas vacías")

	_cerrar()


func _check(cond: bool, nombre: String) -> void:
	if cond:
		print("  check OK — ", nombre)
	else:
		_fallos += 1
		printerr("  check FALLIDO — ", nombre)


func _cerrar() -> void:
	if _fallos == 0:
		print("TESTS OK: 14 checks")
	else:
		print("TESTS FALLIDOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)
```

Ejecutar `--script res://tests/test_gestor_archivo.gd` → debe fallar (script `gestor_archivo.gd` aún no existe → parse error). Ese es el RED.

### Step 2 — GREEN: `scripts/gestor_archivo.gd`

```gdscript
extends RefCounted

const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
const CAMPOS := ["nombre", "desc", "url", "img", "cat"]


static func exportar(ruta: String, entradas: Array) -> Dictionary:
	var res: Array = []
	for entrada in entradas:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		var sub := {}
		for campo in CAMPOS:
			sub[campo] = str(entrada.get(campo, ""))
		res.append(sub)

	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		return {"ok": false, "error": "No se pudo escribir el archivo."}
	archivo.store_string(JSON.stringify(res, "\t"))
	archivo.close()
	return {"ok": true, "total": res.size()}


static func importar(ruta: String, existentes: Array) -> Dictionary:
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return {"ok": false, "error": "El archivo no es un catálogo válido."}
	var parseado: Variant = JSON.parse_string(archivo.get_as_text())
	if typeof(parseado) != TYPE_ARRAY:
		return {"ok": false, "error": "El archivo no es un catálogo válido."}

	var vistos := {}
	for u in existentes:
		if typeof(u) == TYPE_STRING:
			var c: String = GestorCatalogoScript.clave_unica(str(u))
			if not c.is_empty():
				vistos[c] = true

	var entradas: Array = []
	var omitidas := 0
	for item in parseado:
		if typeof(item) != TYPE_DICTIONARY:
			omitidas += 1
			continue
		var url := GestorCatalogoScript.normalizar_url(str(item.get("url", "")))
		if url.is_empty():
			omitidas += 1
			continue
		var clave := GestorCatalogoScript.clave_unica(url)
		if vistos.has(clave):
			omitidas += 1
			continue
		vistos[clave] = true
		var sub := {}
		for campo in CAMPOS:
			sub[campo] = str(item.get(campo, ""))
		sub["url"] = url
		sub["cat"] = GestorCatalogoScript.normalizar_categoria(item.get("cat", "otro"))
		entradas.append(sub)

	return {"ok": true, "entradas": entradas, "omitidas": omitidas}
```

Ejecutar el test → `TESTS OK: 14 checks`. Verificar que se generó `scripts/gestor_archivo.gd.uid` (commitearlo).

### Step 3 — RED: tests de integración en `tests/test_main_barra.gd` (+5 checks)

Añadir al final de `_arrancar()` (antes de la sección de reconexiones finales o al cierre, donde ya está `_cerrar()`), un bloque nuevo:

```gdscript
	# Importar/Exportar: menú y flujos (#3)
	main_script._persistir = false
	var diag_imp: FileDialog = main.get_node("%DialogoImportar")
	var diag_exp: FileDialog = main.get_node("%DialogoExportar")
	main_script._on_file_id(1)
	_check(diag_imp.visible, "Archivo > Importar… abre el diálogo de importación")
	diag_imp.hide()
	main_script._on_file_id(2)
	_check(diag_exp.visible, "Archivo > Exportar… abre el diálogo de exportación")
	diag_exp.hide()

	var ruta_imp := "user://__test_import_export__.json"
	var f_imp := FileAccess.open(ruta_imp, FileAccess.WRITE)
	f_imp.store_string(JSON.stringify([
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""},
		{"nombre": "B", "desc": "", "url": "https://bb.test", "img": ""},
		{"nombre": "C", "desc": "", "url": "https://cc.test", "img": ""},
	], "\t"))
	f_imp.close()
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""}]
	main_script._on_importar_elegido(ruta_imp)
	_check(main_script._entradas.size() == 3, "importar fusiona añadiendo solo las nuevas")
	_check(main.get_node("%Progreso").text == "2 importados, 1 omitidos.", "importar informa importados y omitidos")

	var ruta_exp := "user://__test_import_export_export__.json"
	main_script._on_exportar_elegido(ruta_exp)
	_check(FileAccess.file_exists(ruta_exp) and (JSON.parse_string(FileAccess.get_file_as_string(ruta_exp)) as Array).size() == 3, "exportar escribe un JSON con el catálogo")
```

Ejecutar `--script res://tests/test_main_barra.gd` → los 5 checks nuevos fallan (los `%DialogoImportar`/`%DialogoExportar` no existen y faltan los métodos). RED.

### Step 4 — GREEN: `scenes/Main.tscn`

Añadir al final del archivo (tras el nodo `Version`, después de la línea 172) dos FileDialog como hijos de la raíz `Main`:

```
[node name="DialogoImportar" type="FileDialog" parent="."]
unique_name_in_owner = true
title = "Importar catálogo JSON"
file_mode = 0
filters = PackedStringArray("*.json ; Archivo JSON")

[node name="DialogoExportar" type="FileDialog" parent="."]
unique_name_in_owner = true
title = "Exportar catálogo JSON"
file_mode = 4
filters = PackedStringArray("*.json ; Archivo JSON")
```

`file_mode = 0` = OPEN_FILE; `file_mode = 4` = SAVE_FILE. (La entrada `filters` en `.tscn` acepta la forma de string único; ver Constraint 2.)

### Step 5 — GREEN: `scripts/main.gd`

a) Añadir el preload tras la línea 10:

```gdscript
const GestorArchivoScript := preload("res://scripts/gestor_archivo.gd")
```

b) En `_ready()`, tras la línea 68 (`preferencias.aplicado.connect(...)`), conectar los diálogos:

```gdscript
	%DialogoImportar.file_selected.connect(_on_importar_elegido)
	%DialogoExportar.file_selected.connect(_on_exportar_elegido)
```

c) `_configurar_menus()` (líneas 74–78) pasa a:

```gdscript
func _configurar_menus() -> void:
	var menu_file: PopupMenu = %File
	menu_file.clear()
	menu_file.add_item("Importar…", 1)
	menu_file.add_item("Exportar…", 2)
	menu_file.add_separator()
	menu_file.add_item("Salir", 3)
	menu_file.id_pressed.connect(_on_file_id)
```

d) `_on_file_id` (líneas 88–90) pasa a:

```gdscript
func _on_file_id(id: int) -> void:
	match id:
		1:
			%DialogoImportar.popup_centered()
		2:
			%DialogoExportar.popup_centered()
		3:
			get_tree().quit()
```

e) Añadir los dos handlers tras `_on_file_id`:

```gdscript
func _on_importar_elegido(ruta: String) -> void:
	var res: Dictionary = GestorArchivoScript.importar(ruta, _urls_existentes())
	if not res.get("ok", false):
		progreso.text = str(res.get("error", "No se pudo importar el catálogo."))
		return
	var entradas: Array = res.get("entradas", [])
	var omitidas := int(res.get("omitidas", 0))
	if entradas.is_empty():
		progreso.text = "%d omitidos (ya existían o sin URL válida)." % omitidas
		return
	var importados := entradas.size()
	for entrada in entradas:
		_entradas.append(entrada)
	if not _guardar_datos():
		_cargar_datos()
		_refrescar_vista()
		progreso.text = "No se pudo guardar el catálogo."
		return
	_refrescar_vista()
	_actualizar_status()
	progreso.text = "%d importados, %d omitidos." % [importados, omitidas]


func _on_exportar_elegido(ruta: String) -> void:
	var res: Dictionary = GestorArchivoScript.exportar(ruta, _entradas)
	if not res.get("ok", false):
		progreso.text = str(res.get("error", "No se pudo exportar el catálogo."))
		return
	progreso.text = "Catálogo exportado (%d enlaces)." % int(res.get("total", 0))
```

Repetir `--script res://tests/test_main_barra.gd` → todos los checks (71 + 5 nuevos) OK.

### Step 6 — Commit

```
feat: importar y exportar el catálogo desde el menú Archivo (#3)
```
Commitear `scripts/gestor_archivo.gd`, `scripts/gestor_archivo.gd.uid`, `tests/test_gestor_archivo.gd`, `tests/test_gestor_archivo.gd.uid`, `scenes/Main.tscn`, `tests/test_main_barra.gd`, y el `scenes/Main.tscn.uid` si cambió.

---

## Task 2 — #14 Atajos de teclado

Files:
- Modify: `project.godot`, `scripts/main.gd`, `tests/test_main_barra.gd`.

Steps (TDD):

### Step 1 — RED: tests en `tests/test_main_barra.gd` (+5 checks)

Añadir después del bloque de importar/exportar (Task 1) otro bloque:

```gdscript
	# Atajos de teclado (#14)
	_check(
		InputMap.has_action("atajo_buscar") and InputMap.has_action("atajo_agregar") and InputMap.has_action("atajo_comprobar"),
		"las acciones de los atajos están definidas"
	)

	var ev_f := InputEventKey.new()
	ev_f.keycode = KEY_F
	ev_f.physical_keycode = KEY_F
	ev_f.ctrl_pressed = true
	ev_f.pressed = true
	main_script._unhandled_input(ev_f)
	_check(main.get_viewport().gui_get_focus_owner() == main.get_node("%Busqueda") or main.get_node("%Busqueda").has_focus(), "Ctrl+F enfoca el buscador")

	var ev_n := InputEventKey.new()
	ev_n.keycode = KEY_N
	ev_n.physical_keycode = KEY_N
	ev_n.ctrl_pressed = true
	ev_n.pressed = true
	main_script._unhandled_input(ev_n)
	_check(main.get_node("%VentanaAgregar").visible, "Ctrl+N abre la ventana Agregar enlace")

	main_script._entradas = []
	main_script._refrescar_vista()
	var ev_r := InputEventKey.new()
	ev_r.keycode = KEY_R
	ev_r.physical_keycode = KEY_R
	ev_r.ctrl_pressed = true
	ev_r.pressed = true
	main_script._unhandled_input(ev_r)
	_check(main.get_node("%Progreso").text == "Nada que comprobar", "Ctrl+R dispara la comprobación")

	var ev_esc := InputEventKey.new()
	ev_esc.keycode = KEY_ESCAPE
	ev_esc.physical_keycode = KEY_ESCAPE
	ev_esc.pressed = true
	main_script._unhandled_input(ev_esc)
	_check(not main.get_node("%VentanaAgregar").visible, "Esc cierra la ventana Agregar enlace")
```

Nota: el evento sintético se construye con `keycode`, `physical_keycode`, `pressed` y `ctrl_pressed` para que `is_action_pressed()` haga match contra el `InputMap` (headless no simula teclado). Ejecutar → los 5 checks nuevos fallan (sin acciones y sin `_unhandled_input`). RED.

### Step 2 — GREEN: `project.godot`

Añadir al final del archivo la sección `[input]` con las tres acciones (`KEY_F=70`, `KEY_N=78`, `KEY_R=82`). El bloque es exactamente:

```
[input]

atajo_buscar={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":true,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":70,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
atajo_agregar={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":true,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":78,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
atajo_comprobar={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":true,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":82,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

### Step 3 — GREEN: `scripts/main.gd`

Añadir tras `_on_utilidades_id` (línea 99):

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("atajo_buscar"):
		_on_atajo("atajo_buscar")
	elif event.is_action_pressed("atajo_agregar"):
		_on_atajo("atajo_agregar")
	elif event.is_action_pressed("atajo_comprobar"):
		_on_atajo("atajo_comprobar")
	elif event.is_action_pressed("ui_cancel"):
		_on_atajo("ui_cancel")


func _on_atajo(accion: String) -> void:
	match accion:
		"atajo_buscar":
			busqueda.grab_focus()
		"atajo_agregar":
			ventana_agregar.abrir()
		"atajo_comprobar":
			_comprobar_visibles()
		"ui_cancel":
			if ventana_agregar.visible:
				ventana_agregar.hide()
			elif preferencias.visible:
				preferencias.hide()
```

Notas de comportamiento (por diseño):
- Los popups (ConfirmarBorrado, ConfirmarLimpieza, menús) consumen `ui_cancel` primero; si uno está abierto, `_unhandled_input` de `Main` NO recibe el Esc. La precedencia `ventana_agregar → preferencias` solo se aplica cuando ningún popup capturó el evento.
- `atajo_agregar` llama `abrir()`; si la ventana ya está visible, `abrir()` decide (reutiliza el flujo existente de menú Utilidades).

Repetir `--script res://tests/test_main_barra.gd` → 71 + 5 + 5 = 81 checks OK.

### Step 4 — Commit

```
feat: atajos de teclado Ctrl+F, Ctrl+N, Ctrl+R y Esc (#14)
```
Commitear `project.godot`, `scripts/main.gd`, `tests/test_main_barra.gd`.

---

## Task 3 — #31 Tests de `link_checker` (sin red)

Files:
- Modify: `tests/test_link_checker_timeout.gd`.

No se toca `scripts/link_checker.gd` (los helpers ya existen; el texto de #31 es anticuado). Steps (TDD):

### Step 1 — RED: reescribir `tests/test_link_checker_timeout.gd` (4 → 20 checks)

Reemplazar el cuerpo con el archivo completo siguiente (mantener `extends SceneTree`, `_fallos`, `_initialize`, `_check`, `_cerrar`). Cada caso crea su propia instancia de `LinkChecker`:

```gdscript
extends SceneTree

const LinkChecker := preload("res://scripts/link_checker.gd")

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	# Defaults
	var checker := LinkChecker.new()
	_check(is_equal_approx(checker.timeout_s, 10.0), "timeout_s tiene default 10.0")
	checker.timeout_s = 25.0
	_check(is_equal_approx(checker.timeout_s, 25.0), "timeout_s es asignable")
	_check(checker.codigo == 0, "codigo tiene default 0")
	checker.codigo = 404
	_check(checker.codigo == 404, "codigo es asignable")
	checker.free()

	# Marcadores de página muerta (#31)
	var marcas: PackedStringArray = LinkChecker.MARCAS_MUERTO
	_check(marcas.size() > 0, "MARCAS_MUERTO no está vacío")
	var todas_ok := true
	for m in marcas:
		if String(m).strip_edges().is_empty():
			todas_ok = false
	_check(todas_ok, "ninguna marca está vacía")

	var cpm := LinkChecker.new()
	_check(cpm._parece_muerto(404, "") == true, "_parece_muerto: 404 siempre muerto")
	_check(cpm._parece_muerto(410, "<html>hola</html>") == true, "_parece_muerto: 410 siempre muerto")
	_check(cpm._parece_muerto(200, "") == false, "_parece_muerto: 200 sin html no es muerto")
	_check(cpm._parece_muerto(200, "page not found") == true, "_parece_muerto: 200 con marcador es muerto")
	_check(cpm._parece_muerto(200, "<html>normal</html>") == false, "_parece_muerto: 200 sin marcador no es muerto")
	cpm.free()

	# Parseo de URL (#31)
	var cp := LinkChecker.new()
	var p1 := cp._parsear_url("https://example.com")
	_check(str(p1.get("host", "")) == "example.com" and int(p1.get("port", 0)) == 443 and str(p1.get("path", "")) == "/" and p1.get("tls", false) == true, "_parsear_url: https estándar")
	var p2 := cp._parsear_url("http://ej.com:8080/x")
	_check(str(p2.get("host", "")) == "ej.com" and int(p2.get("port", 0)) == 8080 and str(p2.get("path", "")) == "/x" and p2.get("tls", false) == false, "_parsear_url: http con puerto y path")
	_check(cp._parsear_url("ftp://x.com").is_empty(), "_parsear_url: esquema no http(s) es inválido")
	_check(cp._parsear_url("ejemplo.com/ruta").is_empty(), "_parsear_url: sin esquema es inválido")
	var p6 := cp._parsear_url("https://[::1]/")
	_check(str(p6.get("host", "")) == "[::1]" and int(p6.get("port", 0)) == 443, "_parsear_url: IPv6 en corchetes conserva host")
	cp.free()

	# Resolución de redirecciones (#31)
	var cr := LinkChecker.new()
	_check(cr._resolver_redirect("https://a.test/origen", "http://otro.test/x") == "http://otro.test/x", "_resolver_redirect: destino absoluto intacto")
	_check(cr._resolver_redirect("https://a.test/origen", "/nuevo") == "https://a.test:443/nuevo", "_resolver_redirect: destino relativo usa host y puerto")
	cr.free()

	# comprobar sin red: URLs inválidas emiten terminado síncrono (#31)
	var c1 := LinkChecker.new()
	var emitido_1 := false
	var valido_1 := true
	var mensaje_1 := ""
	c1.terminado.connect(func(v: bool, m: String) -> void:
		emitido_1 = true
		valido_1 = v
		mensaje_1 = m)
	c1.comprobar("")
	_check(emitido_1 and not valido_1 and mensaje_1 == "URL inválida" and not c1._activo, "comprobar('') emite terminado(false, 'URL inválida') sin red")

	var c2 := LinkChecker.new()
	var emitido_2 := false
	c2.terminado.connect(func(v: bool, _m: String) -> void:
		emitido_2 = true)
	c2.comprobar("gopher://x")
	_check(emitido_2 and not c2._activo, "comprobar('gopher://x') emite terminado sin red")

	_cerrar()


func _check(cond: bool, nombre: String) -> void:
	if cond:
		print("  check OK — ", nombre)
	else:
		_fallos += 1
		printerr("  check FALLIDO — ", nombre)


func _cerrar() -> void:
	if _fallos == 0:
		print("TESTS OK: 20 checks")
	else:
		print("TESTS FALLIDOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)
```

### Step 2 — Ejecutar, verificar contra el código real

`comprobar("")` y `comprobar("gopher://x")` pasan por `_conectar` → `_parsear_url` devuelve `{}` → `_cerrar("URL inválida", false)` → `terminado.emit`, `_activo=false`, `queue_free()` (síncrono). Las instancias `c1`/`c2` no se liberan a mano (ya quedan `queue_free()`; el test termina al cerrar).

Cuidado con `_process`: `comprobar` llama `set_process(true)`; como `_conectar` cierra síncrono, `_activo` vuelve a `false` y el procesado se apaga (`set_process(false)` en `_cerrar`). No hace falta `await` ningún frame.

Ejecutar `--script res://tests/test_link_checker_timeout.gd` → `TESTS OK: 20 checks` (GREEN directo; los helpers ya existen).

### Step 3 — Commit

```
test: cubre link_checker (marcadores, parseo, redirects y sin red) (#31)
```
Commitear `tests/test_link_checker_timeout.gd` (+ `.gd.uid` si cambió).

---

## Final Integration

1. **Batería completa** — ejecutar los 11 suites. Respuesta esperada: `TESTS OK` en todas, 246 checks:
   - `test_gestor_catalogo` 32
   - `test_main_barra` 81
   - `test_gestor_imagenes` 19
   - `test_agregar_enlace` 30
   - `test_gestor_contadores` 8
   - `test_estado_store` 12
   - `test_list_item` 21
   - `test_preferencias` 4
   - `test_link_checker_timeout` 20
   - `test_config_store` 5
   - `test_gestor_archivo` 14
2. **Smoke headless:** `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" res://scenes/Main.tscn --quit-after 60` → exit 0 sin errores; y `--check-only` → exit 0.
3. Si falla algo en la batería, arreglar según `systematic-debugging` y `verification-before-completion` ANTES de commitear el plan integrado.

## Components

- `scripts/gestor_archivo.gd` (nuevo) — exportar/importar estático con saneado y dedup.
- `tests/test_gestor_archivo.gd` (nuevo) — 14 checks.
- `scenes/Main.tscn` — `%DialogoImportar`, `%DialogoExportar` (FileDialog).
- `scripts/main.gd` — preload, conexiones, `_configurar_menus`, `_on_file_id`, handlers import/export, `_unhandled_input`, `_on_atajo`.
- `project.godot` — `[input]` con `atajo_buscar`/`atajo_agregar`/`atajo_comprobar`.
- `tests/test_main_barra.gd` — +10 checks (5 import/export, 5 atajos).
- `tests/test_link_checker_timeout.gd` — 4 → 20 checks.

## Verification

- Batería 11/11 `TESTS OK` (246 checks).
- Smoke `Main.tscn` exit 0 y `--check-only` exit 0.
- Pruebas manuales (no automatizables en headless): Ctrl+F/N/R y Esc en el editor; menú Archivo → Importar…/Exportar… sobre `data/data.json`.
- Sin cambios en `estado_store`; `link_checker.gd` intacto; sin commits de los archivos protegidos (Constraint 5).
- Al cerrar #31 en GitHub, notar que la cobertura de `gestor_imagenes` ya existía y que la descripción del issue estaba anticuada.