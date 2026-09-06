# Catálogo: añadir y editar enlaces — Plan de implementación (#1, #2, #4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir editar enlaces existentes, añadir varias URLs pegadas de una vez, y detectar/ignorar URLs duplicadas en el catálogo.

**Architecture:** Un helper puro (`gestor_catalogo.gd`) aloja `dominio()` y `separar()` (detección de duplicados por URL exacta). El diálogo `AgregarEnlace` se vuelve multi-modo (Individual / Varias / Editar) y emite `guardado`/`lote_guardado`/`editado`. La fila `ListItem` reemplaza sus botones por un menú contextual (clic derecho) con Editar/Volver a comprobar/Copiar URL/Eliminar. `main.gd` compone el flujo: altas únicas con duplicados ignorados y reportados, lote con conteo final, y edición con remapeo de estado/borrados si cambia la URL.

**Tech Stack:** Godot 4.7 (GDScript, SceneTree), tests con harness `extends SceneTree`.

**Spec:** `docs/superpowers/specs/2026-09-06-catalogo-anadir-editar-design.md`

## Global Constraints

- Ejecutar cada test con: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" -s tests/<archivo>.gd`
- Harness SceneTree: `print("  OK: %s")` / `push_error("FALLO: %s")` / `TESTS OK` + `quit(0)` o `TESTS FALLIDOS: N` + `quit(1)`.
- Sin `class_name` nuevo: usar `const XScript := preload("res://scripts/x.gd")`. No tocar el `class_name EstadoStore` existente.
- Textos de UI en español; sin comentarios en código; `.tscn` a columna 0.
- Duplicado = URL exacta tras `strip_edges()` (mayúsculas y barra final importan); los duplicados se ignoran y se reportan al final.
- En lote, `nombre = gestor_catalogo.dominio(url)`, `desc = ""`, `img = ""`; líneas vacías se ignoran; líneas no-http(s) se cuentan y reportan.
- La URL se puede editar solo si no colisiona (excluyendo la propia); si cambia se remapea estado/borrados (disco y memoria).
- No escribir en `user://enlaces.json` / `res://data/data.json` reales durante tests: usar el seam `_persistir` de `main` y un `_FakeStore`.
- Batería completa verde al final (todas las suites).

---

### Task 1: gestor_catalogo — helpers puros `dominio` y `separar`

**Files:**
- Create: `scripts/gestor_catalogo.gd`
- Test: `tests/test_gestor_catalogo.gd`

**Interfaces:**
- Produces: `gestor_catalogo.dominio(url: String) -> String` (host sin esquema/ruta/query/fragmento, sin `www.` inicial, conservando puerto).
- Produces: `gestor_catalogo.separar(urls: Array, existentes: Array) -> Dictionary` con claves `"nuevas": Array` (URLs a añadir, primera ocurrencia de cada una, sin vacías) y `"repetidas": Array` (una entrada por colisión contra `existentes` o contra URLs ya vistas del mismo lote). Comparación por `strip_edges()` exacto.

- [ ] **Step 1: Write the failing test** `tests/test_gestor_catalogo.gd`

```gdscript
extends SceneTree

const GestorCatalogo := preload("res://scripts/gestor_catalogo.gd")

var _fallos := 0


func _initialize() -> void:
	_check(GestorCatalogo.dominio("https://www.ejemplo.com/ao") == "ejemplo.com", "dominio quita esquema, www. y ruta")
	_check(GestorCatalogo.dominio("http://ejemplo.com") == "ejemplo.com", "dominio con http")
	_check(GestorCatalogo.dominio("https://ejemplo.com/path?q=1") == "ejemplo.com", "dominio ignora ruta y query")
	_check(GestorCatalogo.dominio("ejemplo.com") == "ejemplo.com", "dominio sin esquema")
	_check(GestorCatalogo.dominio("https://sub.ejemplo.com:8080/x") == "sub.ejemplo.com:8080", "dominio conserva el puerto")
	_check(GestorCatalogo.dominio("") == "", "dominio de URL vacía es vacío")

	var sep := GestorCatalogo.separar([], [])
	_check(sep.get("nuevas", []) == [] and sep.get("repetidas", []) == [], "separar con listas vacías")
	sep = GestorCatalogo.separar(["https://a.com"], ["https://a.com", "https://b.com"])
	_check(sep.get("nuevas") == [] and sep.get("repetidas") == ["https://a.com"], "separar detecta colisión con existentes")
	sep = GestorCatalogo.separar(["  https://a.com  "], ["https://a.com"])
	_check(sep.get("nuevas") == [] and sep.get("repetidas") == ["https://a.com"], "separar recorta espacios antes de comparar")
	sep = GestorCatalogo.separar(["HTTPS://A.COM"], ["https://a.com"])
	_check(sep.get("nuevas") == ["HTTPS://A.COM"] and sep.get("repetidas") == [], "separar distingue mayúsculas")
	sep = GestorCatalogo.separar(["https://a.com", "https://b.com", "https://a.com"], [])
	_check(sep.get("nuevas") == ["https://a.com", "https://b.com"] and sep.get("repetidas") == ["https://a.com"], "separar conserva la primera y marca las repetidas del lote")
	sep = GestorCatalogo.separar(["https://a.com", "https://b.com"], ["https://c.com"])
	_check(sep.get("nuevas") == ["https://a.com", "https://b.com"] and sep.get("repetidas") == [], "separar sin duplicados")
	sep = GestorCatalogo.separar(["", " "], [])
	_check(sep.get("nuevas") == [] and sep.get("repetidas") == [], "separar descarta líneas vacías")

	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)
```

Son 13 checks.

- [ ] **Step 2: Run test to verify it fails**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" -s tests/test_gestor_catalogo.gd`
Expected: RED — `Cannot preload ... gestor_catalogo.gd` (no existe).

- [ ] **Step 3: Write minimal implementation** `scripts/gestor_catalogo.gd`

```gdscript
extends RefCounted


static func dominio(url: String) -> String:
	var sin_esquema := url.strip_edges()
	if "://" in sin_esquema:
		sin_esquema = sin_esquema.get_slice("://", 1)
	var host := sin_esquema.get_slice("/", 0)
	host = host.get_slice("?", 0)
	host = host.get_slice("#", 0)
	if host.begins_with("www."):
		host = host.substr(4)
	return host


static func separar(urls: Array, existentes: Array) -> Dictionary:
	var vistos := {}
	for u in existentes:
		if typeof(u) == TYPE_STRING:
			vistos[u.strip_edges()] = true
	var nuevas: Array = []
	var repetidas: Array = []
	for u in urls:
		var nu := u.strip_edges() if typeof(u) == TYPE_STRING else ""
		if nu.is_empty():
			continue
		if vistos.has(nu):
			repetidas.append(nu)
		else:
			vistos[nu] = true
			nuevas.append(nu)
	return {"nuevas": nuevas, "repetidas": repetidas}
```

- [ ] **Step 4: Run test to verify it passes**

Run: mismo comando del Step 2.
Expected: GREEN — `TESTS OK` con 15 `  OK:`.

- [ ] **Step 5: Commit**

```bash
git add scripts/gestor_catalogo.gd tests/test_gestor_catalogo.gd
git commit -m "feat: helpers de catálogo (dominio, separar)"
```

---

### Task 2: estado_store — método `renombrar`

**Files:**
- Modify: `scripts/estado_store.gd` (añadir método al final, antes de `_ruta`)
- Test: `tests/test_estado_store.gd`

**Interfaces:**
- Consumes: nada de Task 1.
- Produces: `EstadoStore.renombrar(url_antigua: String, url_nueva: String) -> bool`: traslada la clave de `estados` (si existe) y reemplaza la URL en `borrados` (si aparece), persistiendo ambos archivos. `false` solo si falla escritura.

- [ ] **Step 1: Extend the test suite** en `tests/test_estado_store.gd`

Añadir tras la línea `_check(codigo_por_defecto(), ...)`:

```gdscript
	_check(renombrar_mueve_estado(), "renombrar() traslada el estado a la nueva URL")
	_check(renombrar_actualiza_borrados(), "renombrar() reemplaza la URL en los borrados")
	_check(renombrar_sin_clave(), "renombrar() sin clave previa no falla")
```

Y añadir los helpers antes de `func _check(`:

```gdscript
func renombrar_mueve_estado() -> bool:
	var store := EstadoStore.new(BASE)
	store.guardar_estado("https://vieja.com", true, "OK (200)", 200)
	if not store.renombrar("https://vieja.com", "https://nueva.com"):
		return false
	var datos := store.cargar()
	return datos["estados"].has("https://nueva.com") \
		and not datos["estados"].has("https://vieja.com") \
		and int(datos["estados"]["https://nueva.com"].get("codigo", -1)) == 200


func renombrar_actualiza_borrados() -> bool:
	var store := EstadoStore.new(BASE)
	store.marcar_borrado("https://borrada.com")
	if not store.renombrar("https://borrada.com", "https://borrada2.com"):
		return false
	return store.cargar()["borrados"] == ["https://borrada2.com"]


func renombrar_sin_clave() -> bool:
	var store := EstadoStore.new(BASE)
	return store.renombrar("https://fantasma.com", "https://otra.com")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" -s tests/test_estado_store.gd`
Expected: RED — `Invalid call. Nonexistent function 'renombrar'` + `TESTS FALLIDOS: 3`.

- [ ] **Step 3: Implement `renombrar`** añadir al final de `scripts/estado_store.gd` (tras `borrar_estado`):

```gdscript
func renombrar(url_antigua: String, url_nueva: String) -> bool:
	var estados := _leer_estados()
	if estados.has(url_antigua):
		estados[url_nueva] = estados[url_antigua]
		estados.erase(url_antigua)
	var borrados := _leer_borrados()
	for i in range(borrados.size() - 1, -1, -1):
		if str(borrados[i]) == url_antigua:
			borrados[i] = url_nueva
	return _escribir_json(_ruta("estados.json"), estados) \
		and _escribir_json(_ruta("borrados.json"), borrados)
```

- [ ] **Step 4: Run test to verify it passes**

Run: mismo comando del Step 2.
Expected: GREEN — `TESTS OK` (11 checks).

- [ ] **Step 5: Commit**

```bash
git add scripts/estado_store.gd tests/test_estado_store.gd
git commit -m "feat: estado_store.renombrar"
```

---

### Task 3: ListItem — menú contextual en lugar de botones

**Files:**
- Modify: `scenes/ListItem.tscn` (quitar `%BtnCopiar`, `Acciones`/`%BtnRecomprobar`/`%BtnEliminar`, `%TemporizadorCopiar`; añadir `%MenuContexto`)
- Modify: `scripts/list_item.gd` (new completo)
- Modify: `scripts/main.gd:193` (quitar `item.mostrar_acciones(false)`; usar `if not estado.is_empty()`)
- Modify: `scripts/main.gd:303-306` (`_on_copiar_pedido` añade label de progreso)
- Test: `tests/test_list_item.gd` (new completo)

**Interfaces:**
- Consumes: nada.
- Produces: señal nueva `editar_pedido` (sin args); `%MenuContexto` (PopupMenu con ítems id 0=Editar…, 1=Volver a comprobar, 2=Copiar URL, 3=Eliminar) que emite las señales `editar_pedido`/`recomprobar_pedido`/`copiar_pedido(url)`/`eliminar_pedido`. Desaparece `mostrar_acciones` y toda referencia a `%Acciones`/`%BtnCopiar`/`%TemporizadorCopiar`/`%BtnRecomprobar`/`%BtnEliminar` (también en `main`).

- [ ] **Step 1: Rewrite `scripts/list_item.gd` (archivo completo)**

```gdscript
extends Button

signal verificacion_terminada
signal eliminar_pedido
signal recomprobar_pedido
signal copiar_pedido(url: String)
signal editar_pedido

var mensaje: String = ""
var codigo := 0
var fecha := 0

const LinkCheckerScript := preload("res://scripts/link_checker.gd")

var url: String = ""
var estado: String = "pendiente"
var valido: Variant = null

var _checker: Node = null
var _timeout := 10.0


func _ready() -> void:
	var menu: PopupMenu = %MenuContexto
	menu.add_item("Editar…", 0)
	menu.add_item("Volver a comprobar", 1)
	menu.add_item("Copiar URL", 2)
	menu.add_item("Eliminar", 3)
	menu.id_pressed.connect(_on_menu)
	gui_input.connect(_on_gui_input)


func setup(nombre: String, descripcion: String, enlace: String, imagen := "") -> void:
	url = enlace
	text = ""
	_actualizar_tooltip()
	%NombreLabel.text = nombre
	%DescripcionLabel.text = descripcion
	_pintar_estado("Sin comprobar", Color(0.55, 0.55, 0.55, 1))
	if imagen != "" and FileAccess.file_exists(imagen):
		var img := Image.load_from_file(imagen)
		if img != null and not img.is_empty():
			%Imagen.texture = ImageTexture.create_from_image(img)


func aplicar_estado(ok: Variant, texto: String, codigo_nuevo := 0, fecha_nueva := 0) -> void:
	valido = ok
	mensaje = texto
	codigo = codigo_nuevo
	fecha = fecha_nueva
	if ok == true:
		estado = "ok"
		_pintar_estado(texto, Color(0.35, 0.85, 0.45, 1))
	elif ok == false:
		estado = "caido"
		_pintar_estado(texto, Color(0.95, 0.35, 0.35, 1))
	else:
		estado = "pendiente"
		_pintar_estado("Sin comprobar", Color(0.55, 0.55, 0.55, 1))
	_actualizar_tooltip()


static func formatear_fecha(unix: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix)
	return "%02d/%02d/%04d %02d:%02d" % [d.day, d.month, d.year, d.hour, d.minute]


func _actualizar_tooltip() -> void:
	if valido == null:
		tooltip_text = url + "\nSin comprobar"
		return
	var lineas := PackedStringArray([url])
	lineas.append("Código: %s" % ("—" if codigo == 0 else str(codigo)))
	if fecha > 0:
		lineas.append("Comprobado: %s" % formatear_fecha(fecha))
	lineas.append(mensaje)
	tooltip_text = "\n".join(lineas)


func configurar_timeout(segundos: float) -> void:
	_timeout = segundos


func verificar() -> void:
	if _checker != null:
		return

	if url.is_empty() or not (url.begins_with("http://") or url.begins_with("https://")):
		valido = false
		estado = "invalido"
		mensaje = "URL inválida"
		_pintar_estado("URL inválida", Color(0.95, 0.55, 0.2, 1))
		_actualizar_tooltip()
		verificacion_terminada.emit()
		return

	estado = "comprobando"
	_pintar_estado("Comprobando…", Color(0.85, 0.75, 0.25, 1))
	_checker = LinkCheckerScript.new()
	add_child(_checker)
	_checker.terminado.connect(_on_check_terminado)
	_checker.timeout_s = _timeout
	_checker.comprobar(url)


func _on_check_terminado(ok: bool, texto: String) -> void:
	codigo = _checker.codigo
	fecha = int(Time.get_unix_time_from_system())
	_checker = null
	valido = ok
	estado = "ok" if ok else "caido"
	mensaje = texto
	_pintar_estado(texto, Color(0.35, 0.85, 0.45, 1) if ok else Color(0.95, 0.35, 0.35, 1))
	_actualizar_tooltip()
	verificacion_terminada.emit()


func _pintar_estado(texto: String, color: Color) -> void:
	%EstadoLabel.text = texto
	%EstadoLabel.add_theme_color_override("font_color", color)
	%Indicador.color = color


func _pressed() -> void:
	if url.is_empty():
		return
	OS.shell_open(url)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		%MenuContexto.popup(Rect2i(Vector2i(event.global_position), Vector2i.ZERO))


func _on_menu(id: int) -> void:
	match id:
		0:
			editar_pedido.emit()
		1:
			recomprobar_pedido.emit()
		2:
			copiar_pedido.emit(url)
		3:
			eliminar_pedido.emit()
```

- [ ] **Step 2: Rewrite `scenes/ListItem.tscn` (archivo completo)**

```text
[gd_scene load_steps=3 format=3 uid="uid://bgestoritem001"]

[ext_resource type="Script" path="res://scripts/list_item.gd" id="1_item"]
[ext_resource type="Texture2D" path="res://Assets/png/no-disponible.png" id="2_placeholder"]

[node name="ListItem" type="Button"]
custom_minimum_size = Vector2(0, 56)
size_flags_horizontal = 3
alignment = 0
script = ExtResource("1_item")

[node name="Margen" type="MarginContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
theme_override_constants/margin_left = 12
theme_override_constants/margin_top = 8
theme_override_constants/margin_right = 12
theme_override_constants/margin_bottom = 8

[node name="Fila" type="HBoxContainer" parent="Margen"]
layout_mode = 2
mouse_filter = 2
theme_override_constants/separation = 10

[node name="Imagen" type="TextureRect" parent="Margen/Fila"]
unique_name_in_owner = true
custom_minimum_size = Vector2(56, 56)
layout_mode = 2
mouse_filter = 2
expand_mode = 1
stretch_mode = 5
texture = ExtResource("2_placeholder")

[node name="Indicador" type="ColorRect" parent="Margen/Fila"]
unique_name_in_owner = true
custom_minimum_size = Vector2(8, 0)
layout_mode = 2
mouse_filter = 2
color = Color(0.55, 0.55, 0.55, 1)

[node name="Textos" type="VBoxContainer" parent="Margen/Fila"]
layout_mode = 2
size_flags_horizontal = 3
mouse_filter = 2
theme_override_constants/separation = 2

[node name="NombreLabel" type="Label" parent="Margen/Fila/Textos"]
unique_name_in_owner = true
layout_mode = 2
mouse_filter = 2
theme_override_font_sizes/font_size = 16
text = "Nombre"

[node name="DescripcionLabel" type="Label" parent="Margen/Fila/Textos"]
unique_name_in_owner = true
layout_mode = 2
mouse_filter = 2
theme_override_colors/font_color = Color(0.75, 0.75, 0.75, 1)
theme_override_font_sizes/font_size = 13
text = "Descripción"
autowrap_mode = 3

[node name="EstadoLabel" type="Label" parent="Margen/Fila"]
unique_name_in_owner = true
custom_minimum_size = Vector2(160, 0)
layout_mode = 2
mouse_filter = 2
horizontal_alignment = 2
text = "Sin comprobar"
autowrap_mode = 3

[node name="MenuContexto" type="PopupMenu" parent="."]
unique_name_in_owner = true
```

- [ ] **Step 3: Adaptar `scripts/main.gd`**

Reemplazar el bloque en `_mostrar_lista` (línea 193):

```gdscript
			if estado.is_empty():
				item.mostrar_acciones(false)
			else:
				item.aplicar_estado(
```
por:

```gdscript
			if not estado.is_empty():
				item.aplicar_estado(
```

Y reemplazar `_on_copiar_pedido` completo (líneas 303-306):

```gdscript
func _on_copiar_pedido(item: Button) -> void:
	if not is_instance_valid(item):
		return
	DisplayServer.clipboard_set(item.url)
	progreso.text = "URL copiada: %s" % item.url
```

- [ ] **Step 4: Run existing suite to verify RED**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" -s tests/test_list_item.gd`
Expected: RED — referencias a `%BtnCopiar`, `%TemporizadorCopiar`, `%Acciones` que ya no existen.

- [ ] **Step 5: Rewrite `tests/test_list_item.gd` (archivo completo)**

```gdscript
extends SceneTree

const LIST_ITEM := preload("res://scenes/ListItem.tscn")
const ListItemScript := preload("res://scripts/list_item.gd")
const PLACEHOLDER := "res://Assets/png/no-disponible.png"
const BASE := "user://__test_list_item__"

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	var caido := _crear_item()
	caido.aplicar_estado(false, "No existe (404)")
	var valido := _crear_item()
	valido.aplicar_estado(true, "OK (200)")
	var fresco := _crear_item()

	root.add_child(caido)
	root.add_child(valido)
	root.add_child(fresco)
	await process_frame
	_check(_menu_completo(caido), "la fila construye el menú con 4 opciones")
	_check(_menu_completo(valido), "la fila válida también construye el menú")

	var con_imagen := _crear_item()
	con_imagen.setup("Nom", "Desc", "https://ejemplo.com/v", _generar_png_temporal())
	var sin_imagen := _crear_item()
	sin_imagen.setup("Nom", "Desc", "https://ejemplo.com/w", "")
	var inexistente := _crear_item()
	inexistente.setup("Nom", "Desc", "https://ejemplo.com/u", BASE + "/no-existe.png")

	root.add_child(con_imagen)
	root.add_child(sin_imagen)
	root.add_child(inexistente)

	await process_frame
	_check(_miniatura_es(con_imagen, false), "miniatura muestra la imagen elegida")
	_check(_miniatura_es(sin_imagen, true), "sin imagen muestra el placeholder")
	_check(_miniatura_es(inexistente, true), "imagen inexistente muestra el placeholder")

	var con_detalle := _crear_item()
	con_detalle.setup("Nom", "Desc", "https://ejemplo.com/d")
	con_detalle.aplicar_estado(true, "OK (200)", 200, 1000000000)
	root.add_child(con_detalle)
	await process_frame
	_check(con_detalle.codigo == 200, "aplicar_estado() guarda el código")
	_check(con_detalle.fecha == 1000000000, "aplicar_estado() guarda la fecha")

	var unix := 1000000000
	var esperado := ListItemScript.formatear_fecha(unix)
	_check(esperado.length() == 16, "formatear_fecha devuelve 'dd/mm/aaaa hh:mm'")
	var d_fecha := Time.get_datetime_dict_from_unix_time(unix)
	_check(esperado == "%02d/%02d/%04d %02d:%02d" % [d_fecha.day, d_fecha.month, d_fecha.year, d_fecha.hour, d_fecha.minute], "formatear_fecha compone día/mes/año y hora")
	var detallado := _crear_item()
	detallado.setup("Nom", "Desc", "https://ejemplo.com/t")
	detallado.aplicar_estado(false, "No existe (404)", 404, unix)
	root.add_child(detallado)
	await process_frame
	_check(detallado.tooltip_text == "https://ejemplo.com/t\nCódigo: 404\nComprobado: %s\nNo existe (404)" % esperado, "tooltip con estado muestra URL, código, fecha y mensaje")
	var sin_codigo := _crear_item()
	sin_codigo.setup("Nom", "Desc", "https://ejemplo.com/s")
	sin_codigo.aplicar_estado(true, "OK (200)")
	root.add_child(sin_codigo)
	await process_frame
	_check(sin_codigo.tooltip_text == "https://ejemplo.com/s\nCódigo: —\nOK (200)", "tooltip sin código muestra 'Código: —'")
	var sin_estado := _crear_item()
	sin_estado.setup("Nom", "Desc", "https://ejemplo.com/p")
	_check(sin_estado.tooltip_text == "https://ejemplo.com/p\nSin comprobar", "fila sin comprobar muestra URL y 'Sin comprobar'")

	var item := _crear_item()
	item.setup("Nom", "Desc", "https://ejemplo.com/menu")
	var emitido: Array = []
	item.editar_pedido.connect(func() -> void: emitido.append("editar"))
	item.recomprobar_pedido.connect(func() -> void: emitido.append("recomprobar"))
	item.copiar_pedido.connect(func(u: String) -> void: emitido.append(["copiar", u]))
	item.eliminar_pedido.connect(func() -> void: emitido.append("eliminar"))
	root.add_child(item)
	await process_frame

	var clic_derecho := InputEventMouseButton.new()
	clic_derecho.button_index = MOUSE_BUTTON_RIGHT
	clic_derecho.pressed = true
	item.gui_input.emit(clic_derecho)
	await process_frame
	_check(item.get_node("%MenuContexto").visible, "el clic derecho abre el menú contextual")

	item.get_node("%MenuContexto").id_pressed.emit(0)
	_check(emitido == ["editar"], "la opción Editar emite editar_pedido")
	item.get_node("%MenuContexto").id_pressed.emit(1)
	_check(emitido == ["editar", "recomprobar"], "la opción Volver a comprobar emite recomprobar_pedido")
	item.get_node("%MenuContexto").id_pressed.emit(2)
	_check(emitido == ["editar", "recomprobar", ["copiar", "https://ejemplo.com/menu"]], "la opción Copiar URL emite copiar_pedido con la URL")
	item.get_node("%MenuContexto").id_pressed.emit(3)
	_check(emitido == ["editar", "recomprobar", ["copiar", "https://ejemplo.com/menu"], "eliminar"], "la opción Eliminar emite eliminar_pedido")

	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _crear_item() -> Control:
	var item: Control = LIST_ITEM.instantiate()
	item.setup("Nombre de prueba", "Descripción", "https://ejemplo.com/x")
	return item


func _menu_completo(item: Control) -> bool:
	var menu: PopupMenu = item.get_node("%MenuContexto")
	return menu != null and menu.get_item_count() == 4


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)


func _generar_png_temporal() -> String:
	DirAccess.make_dir_recursive_absolute(BASE)
	var ruta := BASE + "/prueba.png"
	var img := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	img.save_png(ruta)
	return ruta


func _miniatura_es(item: Control, placeholder_esperado: bool) -> bool:
	if not item.has_node("%Imagen"):
		return false
	var textura: Texture2D = item.get_node("%Imagen").texture
	if textura == null:
		return false
	var es_placeholder := textura.resource_path == PLACEHOLDER
	return es_placeholder == placeholder_esperado
```

Son 17 checks (2 menú + 3 imagen + 2 código/fecha + 2 fecha + 3 tooltip + 1 clic derecho + 4 ítems).

- [ ] **Step 6: Run test to verify it passes**

Run: mismo comando del Step 4.
Expected: GREEN — `TESTS OK`.

- [ ] **Step 7: Regression: ejecutar `test_main_barra`**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" -s tests/test_main_barra.gd`
Expected: GREEN — `TESTS OK` (18 checks, no depende de `mostrar_acciones`).

- [ ] **Step 8: Commit**

```bash
git add scenes/ListItem.tscn scripts/list_item.gd scripts/main.gd tests/test_list_item.gd
git commit -m "feat: menú contextual en fila de enlace"
```

---

### Task 4: AgregarEnlace — diálogo multi-modo (Individual / Varias / Editar)

**Files:**
- Modify: `scenes/AgregarEnlace.tscn` (archivo completo)
- Modify: `scripts/agregar_enlace.gd` (archivo completo)
- Test: `tests/test_agregar_enlace.gd` (nuevo)

**Interfaces:**
- Consumes: nada de tareas previas.
- Produces: `abrir()` (modo Individual, resetea); `abrir_edicion(datos: Dictionary, url_original: String)` (forma precargada, oculta selector de modo); señales `guardado(datos)` (alta individual), `lote_guardado(urls: Array)` (líneas crudas no vacías), `editado(datos, url_original)`. Nodos `%FilaModo`, `%Modo` (OptionButton Individual=0/Varias=1), `%CajaVarias`, `%ListaUrls` (TextEdit), y `unique_name_in_owner` añadido a `%EtiquetaNombre`, `%EtiquetaDesc`, `%EtiquetaUrl`, `%FilaImagen`.

- [ ] **Step 1: Rewrite `scenes/AgregarEnlace.tscn` (archivo completo)**

```text
[gd_scene format=3 uid="uid://hthjcyt02ca3"]

[ext_resource type="Script" path="res://scripts/agregar_enlace.gd" id="1_agregar"]
[ext_resource type="Texture2D" path="res://Assets/png/no-disponible.png" id="2_placeholder"]

[node name="VentanaAgregar" type="Window"]
title = "Agregar enlace"
initial_position = 2
size = Vector2i(540, 470)
unresizable = true
exclusive = true
visible = false
script = ExtResource("1_agregar")

[node name="Fondo" type="ColorRect" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
color = Color(0.12, 0.12, 0.12, 1)

[node name="Margen" type="MarginContainer" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/margin_left = 16
theme_override_constants/margin_top = 16
theme_override_constants/margin_right = 16
theme_override_constants/margin_bottom = 16

[node name="Columna" type="VBoxContainer" parent="Margen"]
layout_mode = 2
theme_override_constants/separation = 10

[node name="FilaModo" type="HBoxContainer" parent="Margen/Columna"]
layout_mode = 2
theme_override_constants/separation = 8

[node name="Modo" type="OptionButton" parent="Margen/Columna/FilaModo"]
unique_name_in_owner = true
layout_mode = 2
item_count = 2
popup/item_0/text = "Individual"
popup/item_0/id = 0
popup/item_1/text = "Varias"
popup/item_1/id = 1

[node name="EtiquetaNombre" type="Label" parent="Margen/Columna"]
unique_name_in_owner = true
layout_mode = 2
text = "Nombre"

[node name="Nombre" type="LineEdit" parent="Margen/Columna"]
unique_name_in_owner = true
layout_mode = 2
placeholder_text = "Ej. Mi servidor AO"

[node name="EtiquetaDesc" type="Label" parent="Margen/Columna"]
unique_name_in_owner = true
layout_mode = 2
text = "Descripción"

[node name="Descripcion" type="LineEdit" parent="Margen/Columna"]
unique_name_in_owner = true
layout_mode = 2
placeholder_text = "Ej. (Cliente + códigos)"

[node name="EtiquetaUrl" type="Label" parent="Margen/Columna"]
unique_name_in_owner = true
layout_mode = 2
text = "URL"

[node name="Url" type="LineEdit" parent="Margen/Columna"]
unique_name_in_owner = true
layout_mode = 2
placeholder_text = "https://..."

[node name="VistaPrevia" type="TextureRect" parent="Margen/Columna"]
unique_name_in_owner = true
layout_mode = 2
custom_minimum_size = Vector2(120, 120)
mouse_filter = 2
expand_mode = 1
stretch_mode = 5
texture = ExtResource("2_placeholder")

[node name="FilaImagen" type="HBoxContainer" parent="Margen/Columna"]
unique_name_in_owner = true
layout_mode = 2
theme_override_constants/separation = 8

[node name="BotonElegir" type="Button" parent="Margen/Columna/FilaImagen"]
unique_name_in_owner = true
layout_mode = 2
text = "Elegir imagen…"

[node name="BotonQuitar" type="Button" parent="Margen/Columna/FilaImagen"]
unique_name_in_owner = true
layout_mode = 2
text = "Quitar imagen"

[node name="CajaVarias" type="VBoxContainer" parent="Margen/Columna"]
unique_name_in_owner = true
layout_mode = 2
visible = false
theme_override_constants/separation = 8

[node name="EtiquetaVarias" type="Label" parent="Margen/Columna/CajaVarias"]
layout_mode = 2
text = "Una URL por línea"

[node name="ListaUrls" type="TextEdit" parent="Margen/Columna/CajaVarias"]
unique_name_in_owner = true
layout_mode = 2
custom_minimum_size = Vector2(0, 200)
placeholder_text = "https://servidor1.com\nhttps://servidor2.com"

[node name="Error" type="Label" parent="Margen/Columna"]
unique_name_in_owner = true
layout_mode = 2
theme_override_colors/font_color = Color(0.95, 0.4, 0.4, 1)
text = ""

[node name="Botones" type="HBoxContainer" parent="Margen/Columna"]
layout_mode = 2
alignment = 2
theme_override_constants/separation = 8

[node name="BotonCancelar" type="Button" parent="Margen/Columna/Botones"]
unique_name_in_owner = true
layout_mode = 2
text = "Cancelar"

[node name="BotonGuardar" type="Button" parent="Margen/Columna/Botones"]
unique_name_in_owner = true
layout_mode = 2
text = "Guardar"

[node name="DialogoImagen" type="FileDialog" parent="."]
unique_name_in_owner = true
title = "Elegir imagen"
size = Vector2i(600, 400)
access = 0
filters = PackedStringArray("*.png", "*.jpg ; *.jpeg", "*.webp")
```

- [ ] **Step 2: Rewrite `scripts/agregar_enlace.gd` (archivo completo)**

```gdscript
extends Window

signal guardado(datos: Dictionary)
signal editado(datos: Dictionary, url_original: String)
signal lote_guardado(urls: Array)

const PLACEHOLDER := preload("res://Assets/png/no-disponible.png")
const GestorImagenesScript := preload("res://scripts/gestor_imagenes.gd")

@onready var nombre: LineEdit = %Nombre
@onready var descripcion: LineEdit = %Descripcion
@onready var url: LineEdit = %Url
@onready var error_label: Label = %Error
@onready var vista_previa: TextureRect = %VistaPrevia
@onready var dialogo_imagen: FileDialog = %DialogoImagen
@onready var fila_modo: HBoxContainer = %FilaModo
@onready var caja_varias: VBoxContainer = %CajaVarias

var _imagen_ruta: String = ""
var _imagen_original: String = ""
var _quitar_imagen := false
var _url_original: String = ""
var _modo: String = "individual"


func _ready() -> void:
	close_requested.connect(hide)
	%BotonCancelar.pressed.connect(hide)
	%BotonGuardar.pressed.connect(_on_guardar)
	%BotonElegir.pressed.connect(func() -> void: dialogo_imagen.popup_centered())
	%BotonQuitar.pressed.connect(_on_quitar_imagen)
	dialogo_imagen.file_selected.connect(_on_imagen_picked)
	nombre.text_submitted.connect(func(_t: String) -> void: descripcion.grab_focus())
	descripcion.text_submitted.connect(func(_t: String) -> void: url.grab_focus())
	url.text_submitted.connect(func(_t: String) -> void: _on_guardar())
	%Modo.item_selected.connect(_cambiar_modo)


func abrir() -> void:
	_modo = "individual"
	%Modo.select(0)
	_cambiar_modo(0)
	_url_original = ""
	_imagen_original = ""
	_quitar_imagen = false
	_imagen_ruta = ""
	vista_previa.texture = PLACEHOLDER
	nombre.text = ""
	descripcion.text = ""
	url.text = ""
	error_label.text = ""
	popup_centered()
	nombre.grab_focus()


func abrir_edicion(datos: Dictionary, url_original: String) -> void:
	_modo = "editar"
	fila_modo.visible = false
	caja_varias.visible = false
	nombre.text = str(datos.get("nombre", ""))
	descripcion.text = str(datos.get("desc", ""))
	url.text = str(datos.get("url", ""))
	error_label.text = ""
	_url_original = url_original
	_imagen_original = str(datos.get("img", ""))
	_fijar_imagen(_imagen_original)
	title = "Editar enlace"
	%BotonGuardar.text = "Guardar cambios"
	popup_centered()
	nombre.grab_focus()


func _cambiar_modo(id: int) -> void:
	_modo = "varias" if id == 1 else "individual"
	fila_modo.visible = true
	_mostrar_individual(_modo == "individual")
	if _modo == "varias":
		%ListaUrls.text = ""
		error_label.text = ""
		title = "Agregar varias URLs"
		%BotonGuardar.text = "Agregar"
		%ListaUrls.grab_focus()
	else:
		title = "Agregar enlace"
		%BotonGuardar.text = "Guardar"
		nombre.grab_focus()


func _mostrar_individual(individual: bool) -> void:
	%EtiquetaNombre.visible = individual
	%Nombre.visible = individual
	%EtiquetaDesc.visible = individual
	%Descripcion.visible = individual
	%EtiquetaUrl.visible = individual
	%Url.visible = individual
	%VistaPrevia.visible = individual
	%FilaImagen.visible = individual
	caja_varias.visible = not individual


func _fijar_imagen(ruta: String) -> void:
	_imagen_ruta = ""
	_quitar_imagen = false
	if ruta != "" and FileAccess.file_exists(ruta):
		var img := Image.load_from_file(ruta)
		vista_previa.texture = ImageTexture.create_from_image(img) if img != null and not img.is_empty() else PLACEHOLDER
	else:
		vista_previa.texture = PLACEHOLDER


func _on_imagen_picked(ruta: String) -> void:
	_imagen_ruta = ruta
	_quitar_imagen = false
	var img := Image.load_from_file(ruta)
	vista_previa.texture = ImageTexture.create_from_image(img) if img != null else PLACEHOLDER


func _on_quitar_imagen() -> void:
	_imagen_ruta = ""
	_quitar_imagen = true
	vista_previa.texture = PLACEHOLDER


func _on_guardar() -> void:
	if _modo == "varias":
		_on_guardar_lote()
		return
	var n := nombre.text.strip_edges()
	var d := descripcion.text.strip_edges()
	var u := url.text.strip_edges()

	if n.is_empty():
		error_label.text = "El nombre no puede estar vacío."
		nombre.grab_focus()
		return
	if u.is_empty():
		error_label.text = "La URL no puede estar vacía."
		url.grab_focus()
		return
	if not (u.begins_with("http://") or u.begins_with("https://")):
		error_label.text = "La URL debe empezar por http:// o https://."
		url.grab_focus()
		return

	var img_final := _imagen_original
	if _quitar_imagen:
		img_final = ""
	elif _imagen_ruta != "":
		var resultado := GestorImagenesScript.copiar(_imagen_ruta)
		if not resultado.get("ok", false):
			error_label.text = str(resultado.get("error", "No se pudo copiar la imagen."))
			return
		img_final = str(resultado.get("destino", ""))

	var datos := {"nombre": n, "desc": d, "url": u, "img": img_final}
	if _modo == "editar":
		editado.emit(datos, _url_original)
	else:
		guardado.emit(datos)
	hide()


func _on_guardar_lote() -> void:
	var lineas: Array = []
	for parte in %ListaUrls.text.split("\n"):
		var linea := (parte if typeof(parte) == TYPE_STRING else str(parte)).strip_edges()
		if not linea.is_empty():
			lineas.append(linea)
	if lineas.is_empty():
		error_label.text = "Pega al menos una URL."
		%ListaUrls.grab_focus()
		return
	lote_guardado.emit(lineas)
	hide()
```

- [ ] **Step 3: Write the failing test** `tests/test_agregar_enlace.gd`

```gdscript
extends SceneTree

const DIALOGO := preload("res://scenes/AgregarEnlace.tscn")

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	var dialogo := DIALOGO.instantiate()
	root.add_child(dialogo)
	await process_frame

	var emitido: Dictionary = {}
	var url_original_emitida := ""
	var lote: Array = []
	dialogo.guardado.connect(func(d: Dictionary) -> void: emitido = d)
	dialogo.editado.connect(func(d: Dictionary, uo: String) -> void:
		emitido = d
		url_original_emitida = uo
	)
	dialogo.lote_guardado.connect(func(urls: Array) -> void: lote = urls)

	dialogo.abrir()
	emitido = {}
	dialogo.get_node("%Nombre").text = "Mi servidor"
	dialogo.get_node("%Descripcion").text = "Con códigos"
	dialogo.get_node("%Url").text = "https://servidor.com"
	dialogo.get_node("%BotonGuardar").pressed.emit()
	_check(emitido.get("url") == "https://servidor.com" and emitido.get("nombre") == "Mi servidor" and emitido.get("desc") == "Con códigos" and emitido.get("img") == "", "el alta individual emite guardado con los campos")
	_check(not dialogo.visible, "el diálogo se oculta tras guardar")

	dialogo.abrir()
	emitido = {}
	dialogo.get_node("%Nombre").text = "Sin url"
	dialogo.get_node("%Url").text = ""
	dialogo.get_node("%BotonGuardar").pressed.emit()
	_check(emitido.is_empty(), "URL vacía no emite guardado")
	_check(dialogo.get_node("%Error").text != "", "URL vacía muestra error en el diálogo")
	_check(dialogo.visible, "con error el diálogo permanece abierto")

	dialogo.abrir()
	emitido = {}
	dialogo.get_node("%Nombre").text = "Mal"
	dialogo.get_node("%Url").text = "no-es-http"
	dialogo.get_node("%BotonGuardar").pressed.emit()
	_check(emitido.is_empty(), "URL no http(s) no emite guardado")

	dialogo.abrir()
	dialogo.get_node("%Modo").select(1)
	dialogo.get_node("%Modo").item_selected.emit(1)
	_check(not dialogo.get_node("%Nombre").visible, "en modo Varias se oculta el formulario")
	_check(dialogo.get_node("%CajaVarias").visible, "en modo Varias se muestra la caja de URLs")
	lote = []
	dialogo.get_node("%ListaUrls").text = "https://a.com\n\n  \nhttps://b.com"
	dialogo.get_node("%BotonGuardar").pressed.emit()
	_check(lote == ["https://a.com", "https://b.com"], "modo Varias emite las URLs no vacías y sin espacios")
	_check(not dialogo.visible, "el diálogo se oculta tras guardar el lote")

	dialogo.abrir()
	dialogo.get_node("%Modo").select(1)
	dialogo.get_node("%Modo").item_selected.emit(1)
	lote = []
	dialogo.get_node("%ListaUrls").text = "   \n "
	dialogo.get_node("%BotonGuardar").pressed.emit()
	_check(lote.is_empty(), "lote sin URL no emite lote_guardado")
	_check(dialogo.get_node("%Error").text != "", "lote vacío muestra error")

	dialogo.abrir_edicion({"nombre": "A", "desc": "D", "url": "https://a.com", "img": ""}, "https://a.com")
	emitido = {}
	url_original_emitida = ""
	_check(dialogo.get_node("%Nombre").text == "A" and dialogo.get_node("%Url").text == "https://a.com", "abrir_edicion precarga los campos")
	_check(not dialogo.get_node("%Modo").visible, "en edición se oculta el selector de modo")
	dialogo.get_node("%Url").text = "https://a2.com"
	dialogo.get_node("%BotonGuardar").pressed.emit()
	_check(not dialogo.visible, "el diálogo se cierra tras editar")
	_check(emitido.get("url") == "https://a2.com" and url_original_emitida == "https://a.com", "editar emite editado con los datos y la URL original")
	_check(emitido.get("nombre") == "A", "editar conserva los campos no modificados")

	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)
```

Son 17 checks.

- [ ] **Step 4: Run test to verify it passes**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" -s tests/test_agregar_enlace.gd`
Expected: GREEN — `TESTS OK`.

- [ ] **Step 5: Commit**

```bash
git add scenes/AgregarEnlace.tscn scripts/agregar_enlace.gd tests/test_agregar_enlace.gd
git commit -m "feat: diálogo AgregarEnlace multi-modo"
```

---

### Task 5: main — alta única con duplicados y lote de URLs

**Files:**
- Modify: `scripts/main.gd` (preload, señales, `_persistir`, `_guardar_datos`, `_on_enlace_guardado`, helpers, `_on_lote_guardado`)
- Test: `tests/test_main_barra.gd`

**Interfaces:**
- Consumes: `gestor_catalogo.separar/dominio` (Task 1). Señal `lote_guardado(urls)` del diálogo (Task 4).
- Produces: `main._persistir` (seam bool, `true` por defecto); `_urls_existentes() -> Array`; `_url_existe(url) -> bool`; `_on_lote_guardado(urls: Array)`. Comportamiento: alta única duplicada → no añade + barra "Ya existe: <url>"; lote → añade válidas nuevas con `nombre = dominio(url)`, reporta "Se añadieron X enlaces. Y repetidas ignoradas. Z inválidas ignoradas." (parte presente solo si > 0).

- [ ] **Step 1: Modify `scripts/main.gd` (ediciones puntuales)**

1) Tras `const ConfigStoreScript := ...` añadir:

```gdscript
const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
```

2) Tras `var _item_pendiente_borrar: Button = null` añadir:

```gdscript
var _persistir := true
```

3) En `_ready`, tras `ventana_agregar.guardado.connect(_on_enlace_guardado)` añadir:

```gdscript
	ventana_agregar.lote_guardado.connect(_on_lote_guardado)
```

4) En `_guardar_datos()`, tras la firma añadir:

```gdscript
	if not _persistir:
		return true
```

5) Reemplazar `_on_enlace_guardado` completo:

```gdscript
func _on_enlace_guardado(datos: Dictionary) -> void:
	var url_nueva := str(datos.get("url", ""))
	if _url_existe(url_nueva):
		progreso.text = "Ya existe: %s" % url_nueva
		return
	_entradas.append(datos)
	if not _guardar_datos():
		_entradas.pop_back()
		return
	_refrescar_vista()
	_actualizar_status()
	progreso.text = "Enlace agregado: %s" % datos.get("nombre", "")
```

6) Añadir `_on_lote_guardado` y los helpers tras `_on_enlace_guardado`:

```gdscript
func _on_lote_guardado(urls: Array) -> void:
	var normales: Array = []
	for linea in urls:
		var u := linea.strip_edges() if typeof(linea) == TYPE_STRING else ""
		if not u.is_empty():
			normales.append(u)
	var validas: Array = []
	var invalidas: Array = []
	for u in normales:
		if u.begins_with("http://") or u.begins_with("https://"):
			validas.append(u)
		else:
			invalidas.append(u)
	var res := GestorCatalogoScript.separar(validas, _urls_existentes())
	var nuevas: Array = res.get("nuevas", [])
	var repetidas: Array = res.get("repetidas", [])
	if nuevas.is_empty():
		var partes_vacias: Array = ["No se añadió ningún enlace."]
		if not repetidas.is_empty():
			partes_vacias.append("%d repetidas ignoradas." % repetidas.size())
		if not invalidas.is_empty():
			partes_vacias.append("%d inválidas ignoradas." % invalidas.size())
		progreso.text = " ".join(partes_vacias)
		return
	for u in nuevas:
		_entradas.append({
			"nombre": GestorCatalogoScript.dominio(u),
			"desc": "",
			"url": u,
			"img": "",
		})
	if not _guardar_datos():
		for i in range(nuevas.size()):
			_entradas.pop_back()
		progreso.text = "No se pudo guardar el lote."
		return
	var partes: Array = ["Se añadieron %d enlaces." % nuevas.size()]
	if not repetidas.is_empty():
		partes.append("%d repetidas ignoradas." % repetidas.size())
	if not invalidas.is_empty():
		partes.append("%d inválidas ignoradas." % invalidas.size())
	_refrescar_vista()
	_actualizar_status()
	progreso.text = " ".join(partes)


func _urls_existentes() -> Array:
	var urls: Array = []
	for entrada in _entradas:
		if typeof(entrada) == TYPE_DICTIONARY:
			urls.append(str(entrada.get("url", "")))
	return urls


func _url_existe(url: String) -> bool:
	var res := GestorCatalogoScript.separar([url], _urls_existentes())
	return not (res.get("repetidas", []) as Array).is_empty()
```

- [ ] **Step 2: Write the failing tests** en `tests/test_main_barra.gd`

1) Tras `extends SceneTree` (línea 1), añadir:

```gdscript

class _FakeStore extends RefCounted:
	var ultima_renombrar: Array = []
	func renombrar(url_antigua: String, url_nueva: String) -> bool:
		ultima_renombrar = [url_antigua, url_nueva]
		return true
```

2) Tras la línea `		item.free()` del bloque `_persistir_recompra` (línea 48), insertar el bloque de catálogo:

```gdscript
	# Catálogo: alta única con duplicados
	main_script._persistir = false
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""}]
	main_script._on_enlace_guardado({"nombre": "B", "desc": "", "url": "https://a.test", "img": ""})
	_check(main_script._entradas.size() == 1, "alta con URL existente no añade")
	_check(main.get_node("%Progreso").text == "Ya existe: https://a.test", "alta duplicada informa en la barra")

	# Catálogo: lote de URLs
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""}]
	main_script._on_lote_guardado(["https://a.test", "https://bb.test", "https://a.test", "no-es-url", ""])
	_check(main_script._entradas.size() == 2, "el lote añade solo las válidas nuevas")
	_check(main_script._entradas[1].get("nombre") == "bb.test", "el lote deriva el nombre del dominio")
	_check(main.get_node("%Progreso").text == "Se añadieron 1 enlaces. 2 repetidas ignoradas. 1 inválidas ignoradas.", "el lote reporta repetidas e inválidas")

	# Catálogo: lote todo repetido
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""}]
	main_script._on_lote_guardado(["https://a.test"])
	_check(main_script._entradas.size() == 1, "lote sin nuevas no añade nada")
	_check(main.get_node("%Progreso").text == "No se añadió ningún enlace. 1 repetidas ignoradas.", "lote sin nuevas reporta")
```

- [ ] **Step 3: Run test to verify it fails**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" -s tests/test_main_barra.gd`
Expected: RED — fallan los checks de catálogo (`Invalid call. Nonexistent function '_on_lote_guardado'`, URLs no bloqueadas, mensajes de lote incorrectos).

- [ ] **Step 4: Run tests to verify they pass**

Run: mismo comando del Step 3.
Expected: GREEN — `TESTS OK` (18 + 7 = 25 checks).

- [ ] **Step 5: Regression: `test_gestor_catalogo` sigue verde**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" -s tests/test_gestor_catalogo.gd`
Expected: GREEN — `TESTS OK`.

- [ ] **Step 6: Commit**

```bash
git add scripts/main.gd tests/test_main_barra.gd
git commit -m "feat: lote de URLs y alta única con duplicados"
```

---

### Task 6: main — edición de enlaces con remapeo

**Files:**
- Modify: `scripts/main.gd` (conectar `editado`, `_mostrar_lista` enlaza `editar_pedido`, `_on_editar_pedido`, `_buscar_entrada`, `_cambios_url_validos`, `_on_enlace_editado`)
- Test: `tests/test_main_barra.gd`

**Interfaces:**
- Consumes: `abrir_edicion(datos, url_original)` y señal `editado` del diálogo (Task 4); `EstadoStore.renombrar` (Task 2); `gestor_catalogo.separar` (Task 1).
- Produces: `_on_editar_pedido(item: Button)` (precarga el diálogo); `_on_enlace_editado(datos: Dictionary, url_original: String)` (colisión excluyendo self → mensaje + reabre; si cambia la URL → `renombrar` + memoria; sustituye campos; `_guardar_datos`; refresca). Mensaje de éxito: `"Enlace actualizado: <nombre>"`.

- [ ] **Step 1: Modify `scripts/main.gd` (ediciones puntuales)**

1) En `_ready`, tras `ventana_agregar.lote_guardado.connect(_on_lote_guardado)` añadir:

```gdscript
	ventana_agregar.editado.connect(_on_enlace_editado)
```

2) En `_mostrar_lista`, dentro del bucle, tras `item.copiar_pedido.connect(_on_copiar_pedido.bind(item))` añadir:

```gdscript
		item.editar_pedido.connect(_on_editar_pedido.bind(item))
```

3) Añadir tras `_url_existe` los métodos de edición:

```gdscript
func _on_editar_pedido(item: Button) -> void:
	if not is_instance_valid(item):
		return
	var datos := _buscar_entrada(item.url)
	if datos.is_empty():
		progreso.text = "No se encontró el enlace."
		return
	ventana_agregar.abrir_edicion(datos, item.url)


func _buscar_entrada(url_entrada: String) -> Dictionary:
	for entrada in _entradas:
		if typeof(entrada) == TYPE_DICTIONARY and str(entrada.get("url", "")) == url_entrada:
			return entrada
	return {}


func _cambios_url_validos(url_original: String, url_nueva: String) -> bool:
	var existentes: Array = []
	for entrada in _entradas:
		if typeof(entrada) == TYPE_DICTIONARY and str(entrada.get("url", "")) != url_original:
			existentes.append(str(entrada.get("url", "")))
	var res := GestorCatalogoScript.separar([url_nueva], existentes)
	return (res.get("repetidas", []) as Array).is_empty()


func _on_enlace_editado(datos: Dictionary, url_original: String) -> void:
	var url_nueva := str(datos.get("url", ""))
	var indice := -1
	for i in range(_entradas.size()):
		if typeof(_entradas[i]) == TYPE_DICTIONARY and str(_entradas[i].get("url", "")) == url_original:
			indice = i
			break
	if indice == -1:
		progreso.text = "No se encontró el enlace."
		return
	if url_nueva != url_original and not _cambios_url_validos(url_original, url_nueva):
		progreso.text = "Ya existe: %s" % url_nueva
		ventana_agregar.abrir_edicion(datos, url_original)
		return
	if url_nueva != url_original:
		_estado_store.renombrar(url_original, url_nueva)
		if _estados.has(url_original):
			_estados[url_nueva] = _estados[url_original]
			_estados.erase(url_original)
		for i_b in range(_borrados.size()):
			if str(_borrados[i_b]) == url_original:
				_borrados[i_b] = url_nueva
	var entrada: Dictionary = _entradas[indice]
	entrada["nombre"] = str(datos.get("nombre", ""))
	entrada["desc"] = str(datos.get("desc", ""))
	entrada["url"] = url_nueva
	entrada["img"] = str(datos.get("img", ""))
	if not _guardar_datos():
		_cargar_datos()
		_refrescar_vista()
		progreso.text = "No se pudo guardar el enlace."
		return
	_refrescar_vista()
	_actualizar_status()
	progreso.text = "Enlace actualizado: %s" % str(datos.get("nombre", ""))
```

- [ ] **Step 2: Write the failing tests** en `tests/test_main_barra.gd`, tras el bloque "lote todo repetido" añadir:

```gdscript
	# Catálogo: edición con cambio de URL remapea
	main_script._estado_store = _FakeStore.new()
	main_script._estados = {"https://a.test": {"valido": true, "mensaje": "OK (200)", "codigo": 200, "fecha": 1}}
	main_script._borrados = ["https://a.test"]
	main_script._entradas = [{"nombre": "A", "desc": "D", "url": "https://a.test", "img": ""}]
	main_script._on_enlace_editado({"nombre": "A2", "desc": "D2", "url": "https://a2.test", "img": ""}, "https://a.test")
	_check(main_script._entradas[0].get("url") == "https://a2.test" and main_script._entradas[0].get("nombre") == "A2", "editar sustituye los campos de la entrada")
	_check(main_script._estados.has("https://a2.test") and not main_script._estados.has("https://a.test"), "editar remapea el estado en memoria")
	_check(main_script._borrados == ["https://a2.test"], "editar remapea los borrados en memoria")
	_check(main_script._estado_store.ultima_renombrar == ["https://a.test", "https://a2.test"], "editar pide el remapeo persistido al store")
	_check(main.get_node("%Progreso").text == "Enlace actualizado: A2", "editar confirma en la barra")

	# Catálogo: edición con colisión de URL no modifica
	main_script._estados = {}
	main_script._borrados = []
	main_script._entradas = [
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""},
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": ""},
	]
	main_script._on_enlace_editado({"nombre": "A", "desc": "", "url": "https://c.test", "img": ""}, "https://a.test")
	_check(main_script._entradas[0].get("url") == "https://a.test", "editar con URL que colisiona no modifica")
	_check(main.get_node("%Progreso").text == "Ya existe: https://c.test", "editar con colisión informa en la barra")
	_check(main.get_node("%VentanaAgregar").visible, "editar con colisión reabre el diálogo")
```

- [ ] **Step 3: Run test to verify it fails**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" -s tests/test_main_barra.gd`
Expected: RED — `Invalid call. Nonexistent function '_on_enlace_editado'`, campos sin sustituir, sin remapeo.

- [ ] **Step 4: Run test to verify it passes**

Run: mismo comando del Step 3.
Expected: GREEN — `TESTS OK` (25 + 8 = 33 checks).

- [ ] **Step 5: Commit**

```bash
git add scripts/main.gd tests/test_main_barra.gd
git commit -m "feat: edición de enlaces con remapeo"
```

---

### Task 7: Batería completa, smoke y push

**Files:**
- Docs: `docs/superpowers/plans/2026-09-06-catalogo-anadir-editar.md` (este plan; total 7 tasks)

- [ ] **Step 1: Ejecutar toda la batería**

Run cada suite y confirmar `TESTS OK`:

```text
config_store        -> tests/test_config_store.gd
gestor_contadores   -> tests/test_gestor_contadores.gd
gestor_imagenes     -> tests/test_gestor_imagenes.gd
preferencias        -> tests/test_preferencias.gd
estado_store        -> tests/test_estado_store.gd
link_checker_timeout -> tests/test_link_checker_timeout.gd
list_item           -> tests/test_list_item.gd
main_barra          -> tests/test_main_barra.gd
gestor_catalogo     -> tests/test_gestor_catalogo.gd
agregar_enlace      -> tests/test_agregar_enlace.gd
```

Comando tipo: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" -s tests/<suite>.gd`
Expected: 10/10 suites GREEN.

- [ ] **Step 2: Smoke de arranque**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --check-only`
Expected: sin errores de análisis/escena.

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" res://scenes/Main.tscn --quit-after 5`
Expected: sin errores en consola (escena principal arranca).

- [ ] **Step 3: Verificar que el editor no dejó `.uid` nuevos**

Run: `git status --porcelain`
Expected: archivos limpios salvo los de este plan; si el editor generó `.uid` nuevos, versionarlos y añadirlos al commit.

- [ ] **Step 4: Commit del plan y push**

```bash
git add docs/superpowers/plans/2026-09-06-catalogo-anadir-editar.md
git commit -m "docs: plan catálogo añadir y editar (#1, #2, #4)"
git push
```