# Persistencia del estado de escaneo + eliminar/re-comprobar enlaces — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Guardar los resultados del escaneo de enlaces en `user://estados.json` (y las URLs eliminadas en `user://borrados.json`) para no re-escanear al abrir el proyecto, y mostrar botones de Eliminar (con confirmación) y Volver a comprobar en los enlaces inválidos.

**Architecture:** Un módulo `RefCounted` (`estado_store.gd`) encapsula toda la persistencia en `user://` (leer/escribir estados y borrados) con base inyectable para testear. `list_item.gd` + `ListItem.tscn` muestran dos botones de acción visibles solo en enlaces inválidos y emiten señales. `main.gd` coordina: carga de estados/borrados al abrir, guardado incremental al terminar cada verificación, diálogo de confirmación de borrado y re-verificación individual.

**Tech Stack:** Godot 4.7 (GDScript, HTTPClient), JSON en `user://`.

## Global Constraints

- Godot 4.7+: binario de pruebas `K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe`.
- **`data/data.json` no se modifica nunca** (ni al borrar, ni al guardar estado).
- `data/data.json.bak`, `data/data2.json` y `data/servidores.json` NO se versionan ni se tocan.
- Formato exacto `user://estados.json`: `{ "<url>": { "valido": bool, "mensaje": String, "fecha": int } }`. Formato exacto `user://borrados.json`: `[ "<url>", ... ]`.
- Guardado incremental: cada enlace verificado persiste su resultado al instante.
- Textos de UI en español, siguiendo el estilo del código existente (comentarios/strings en español).
- Scripts `.gd` sin clase ni autoload nuevos salvo `class_name EstadoStore` en `estado_store.gd`.
- No se usa GUT; tests con `SceneTree` en headless (`--script`) + smoke test de la escena.

---

### Task 1: Módulo `EstadoStore` con tests headless (TDD)

**Files:**
- Create: `scripts/estado_store.gd`
- Create: `tests/test_estado_store.gd`

**Interfaces:**
- Produces: `class_name EstadoStore extends RefCounted`, construible con `EstadoStore.new(base := "user://")`. API usada por las tasks 2 y 3:
  - `cargar() -> Dictionary` → `{ "estados": {...}, "borrados": [...] }`
  - `guardar_estado(url: String, valido: bool, mensaje: String) -> bool`
  - `marcar_borrado(url: String) -> bool`
  - `borrar_estado(url: String) -> void`

- [ ] **Step 1: Escribir el test que falla** — crear `tests/test_estado_store.gd`:

```gdscript
extends SceneTree

const EstadoStore := preload("res://scripts/estado_store.gd")
const BASE := "user://__test_gestor__"

var _fallos := 0


func _initialize() -> void:
	_limpiar()
	_check(cargar_vacio(), "cargar() vacío devuelve estados vacíos y borrados vacíos")
	_check(guardar_y_recuperar(), "guardar_estado() persiste y cargar() lo recupera")
	_check(actualizar_entrada(), "guardar_estado() actualiza una entrada existente")
	_check(borrados_sin_duplicados(), "marcar_borrado() no añade duplicados")
	_check(borrar_estado_limpia(), "borrar_estado() elimina la entrada")
	_check(json_roto_no_rompe(), "JSON roto no rompe cargar()")
	_limpiar()
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func cargar_vacio() -> bool:
	var datos := EstadoStore.new(BASE).cargar()
	return datos.has("estados") and datos.has("borrados") \
		and datos["estados"] == {} and datos["borrados"] == []


func guardar_y_recuperar() -> bool:
	var store := EstadoStore.new(BASE)
	if not store.guardar_estado("https://ejemplo.com/a", true, "OK (200)"):
		return false
	var datos := store.cargar()
	var e: Dictionary = datos["estados"].get("https://ejemplo.com/a", {})
	return e.get("valido") == true and e.get("mensaje") == "OK (200)" and int(e.get("fecha", 0)) > 0


func actualizar_entrada() -> bool:
	var store := EstadoStore.new(BASE)
	store.guardar_estado("https://ejemplo.com/a", true, "OK (200)")
	store.guardar_estado("https://ejemplo.com/a", false, "No existe (404)")
	var e: Dictionary = store.cargar()["estados"].get("https://ejemplo.com/a", {})
	return e.get("valido") == false and e.get("mensaje") == "No existe (404)"


func borrados_sin_duplicados() -> bool:
	var store := EstadoStore.new(BASE)
	store.marcar_borrado("https://muerto.com/x")
	store.marcar_borrado("https://muerto.com/x")
	return store.cargar()["borrados"] == ["https://muerto.com/x"]


func borrar_estado_limpia() -> bool:
	var store := EstadoStore.new(BASE)
	store.guardar_estado("https://ejemplo.com/a", true, "OK (200)")
	store.borrar_estado("https://ejemplo.com/a")
	return store.cargar()["estados"] == {}


func json_roto_no_rompe() -> bool:
	FileAccess.open(BASE + "/estados.json", FileAccess.WRITE).store_string("{no es json")
	FileAccess.open(BASE + "/borrados.json", FileAccess.WRITE).store_string("burro")
	var datos := EstadoStore.new(BASE).cargar()
	return datos["estados"] == {} and datos["borrados"] == []


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)


func _limpiar() -> void:
	DirAccess.remove_absolute(BASE + "/estados.json")
	DirAccess.remove_absolute(BASE + "/borrados.json")
```

- [ ] **Step 2: Ejecutar el test y verificar que falla**

Run:

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_estado_store.gd 2>&1 | Select-String -Pattern "FALLO|Parse Error|Cannot open|does not exist"
```

Expected: error de "Cannot open file" / "Parse Error" por `estado_store.gd` aún no existente, o "FALLO".

- [ ] **Step 3: Implementar `scripts/estado_store.gd`**

```gdscript
class_name EstadoStore
extends RefCounted

var _base: String


func _init(base := "user://") -> void:
	_base = base


func cargar() -> Dictionary:
	return {
		"estados": _leer_estados(),
		"borrados": _leer_borrados(),
	}


func guardar_estado(url: String, valido: bool, mensaje: String) -> bool:
	var estados := _leer_estados()
	estados[url] = {
		"valido": valido,
		"mensaje": mensaje,
		"fecha": int(Time.get_unix_time_from_system()),
	}
	return _escribir_json(_ruta("estados.json"), estados)


func marcar_borrado(url: String) -> bool:
	var borrados := _leer_borrados()
	if not borrados.has(url):
		borrados.append(url)
	return _escribir_json(_ruta("borrados.json"), borrados)


func borrar_estado(url: String) -> void:
	var estados := _leer_estados()
	if estados.erase(url):
		_escribir_json(_ruta("estados.json"), estados)


func _leer_estados() -> Dictionary:
	var v := _leer_json(_ruta("estados.json"))
	return v if typeof(v) == TYPE_DICTIONARY else {}


func _leer_borrados() -> Array:
	var v := _leer_json(_ruta("borrados.json"))
	return v if typeof(v) == TYPE_ARRAY else []


func _leer_json(ruta: String) -> Variant:
	if not FileAccess.file_exists(ruta):
		return null
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return null
	return JSON.parse_string(archivo.get_as_text())


func _escribir_json(ruta: String, dato: Variant) -> bool:
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		return false
	archivo.store_string(JSON.stringify(dato, "\t"))
	archivo.close()
	return true


func _ruta(nombre: String) -> String:
	if _base.ends_with("://"):
		return _base + nombre
	return _base + "/" + nombre
```

- [ ] **Step 4: Ejecutar el test y verificar que pasa**

Run:

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_estado_store.gd 2>&1 | Select-Object -Last 20
```

Expected: todas las líneas `OK:` y una línea `TESTS OK`.

- [ ] **Step 5: Commit**

```bash
git add scripts/estado_store.gd tests/test_estado_store.gd
git commit -m "feat: EstadoStore con persistencia de estados y borrados en user://"
```

---

### Task 2: `ListItem` — botones Eliminar / Volver a comprobar

**Files:**
- Modify: `scenes/ListItem.tscn` (añadir contenedor de acciones tras `EstadoLabel`)
- Modify: `scripts/list_item.gd`

**Interfaces:**
- Produces: señales `eliminar_pedido` y `recomprobar_pedido` del item; métodos `aplicar_estado(valido: Variant, mensaje: String)`, `mostrar_acciones(visible: bool)`; var pública `mensaje: String`. Usado por la Task 3.
- Consumes: `EstadoStore` (solo indirectamente, vía main).
- `valido` (Variant), `url` (String), señales `verificación_terminada` ya existentes.

- [ ] **Step 1: Añadir los botones a `scenes/ListItem.tscn`**

Insertar al final del archivo (después del nodo `EstadoLabel`), como hijo de `Margen/Fila`:

```
[node name="Acciones" type="HBoxContainer" parent="Margen/Fila"]
unique_name_in_owner = true
layout_mode = 2
mouse_filter = 2
theme_override_constants/separation = 6

[node name="BtnRecomprobar" type="Button" parent="Margen/Fila/Acciones"]
unique_name_in_owner = true
layout_mode = 2
text = "Volver a comprobar"

[node name="BtnEliminar" type="Button" parent="Margen/Fila/Acciones"]
unique_name_in_owner = true
layout_mode = 2
text = "Eliminar"
```

Mantener `mouse_filter = 2` (IGNORE) solo en el contenedor `Acciones`; los botones quedan con su `STOP` por defecto (así consumen el clic y NO abren la URL del `Button` raíz).

- [ ] **Step 2: Ampliar `scripts/list_item.gd`**

Añadir al principio (tras las señales existentes):

```gdscript
signal eliminar_pedido
signal recomprobar_pedido

var mensaje: String = ""
```

Añadir `_ready()` para conectar los botones:

```gdscript
func _ready() -> void:
	%BtnRecomprobar.pressed.connect(recomprobar_pedido.emit)
	%BtnEliminar.pressed.connect(eliminar_pedido.emit)
	mostrar_acciones(false)
```

Añadir los métodos nuevos y ajustar el flujo existente:

```gdscript
func aplicar_estado(ok: Variant, texto: String) -> void:
	valido = ok
	mensaje = texto
	if ok == true:
		estado = "ok"
		_pintar_estado(texto, Color(0.35, 0.85, 0.45, 1))
	elif ok == false:
		estado = "caido"
		_pintar_estado(texto, Color(0.95, 0.35, 0.35, 1))
	else:
		estado = "pendiente"
		_pintar_estado("Sin comprobar", Color(0.55, 0.55, 0.55, 1))
	mostrar_acciones(ok == false)


func mostrar_acciones(visible_acciones: bool) -> void:
	%Acciones.visible = visible_acciones
```

En `verificar()`, en el arranque ocultar acciones (está comprobando):

```gdscript
	estado = "comprobando"
	mostrar_acciones(false)
	_pintar_estado("Comprobando…", Color(0.85, 0.75, 0.25, 1))
```

En la rama de URL inválida de `verificar()`, fijar el mensaje:

```gdscript
	if url.is_empty() or not (url.begins_with("http://") or url.begins_with("https://")):
		valido = false
		estado = "invalido"
		mensaje = "URL inválida"
		_pintar_estado("URL inválida", Color(0.95, 0.55, 0.2, 1))
		verificacion_terminada.emit()
		return
```

En `_on_check_terminado`, guardar el mensaje y mostrar acciones si quedó inválido:

```gdscript
func _on_check_terminado(ok: bool, texto: String) -> void:
	_checker = null
	valido = ok
	estado = "ok" if ok else "caido"
	mensaje = texto
	_pintar_estado(texto, Color(0.35, 0.85, 0.45, 1) if ok else Color(0.95, 0.35, 0.35, 1))
	mostrar_acciones(not ok)
	verificacion_terminada.emit()
```

- [ ] **Step 3: Verificar sintaxis**

Run:

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://scripts/list_item.gd --check-only 2>&1
```

Expected: sin salida de error (o solo "parse OK"). No debe contener `Parse Error` ni `SCRIPT ERROR`.

- [ ] **Step 4: Smoke test de la escena**

Run:

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" res://scenes/ListItem.tscn --quit-after 30 2>&1 | Select-String -Pattern "Parse Error|SCRIPT ERROR|ERROR"
```

Expected: sin coincidencias de `Parse Error` ni `SCRIPT ERROR`.

- [ ] **Step 5: Re-ejecutar tests de Task 1 (regresión)**

Run:

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_estado_store.gd 2>&1 | Select-Object -Last 3
```

Expected: `TESTS OK`.

- [ ] **Step 6: Commit**

```bash
git add scenes/ListItem.tscn scripts/list_item.gd
git commit -m "feat: botones de eliminar y volver a comprobar en enlaces inválidos"
```

---

### Task 3: Integración en `Main` — persistencia, re-comprobar y eliminar

**Files:**
- Modify: `scenes/Main.tscn` (añadir `ConfirmationDialog`)
- Modify: `scripts/main.gd`

**Interfaces:**
- Consumes: `EstadoStore.cargar()/guardar_estado()/marcar_borrado()/borrar_estado()` (Task 1); `item.aplicar_estado()/mostrar_acciones()`, señales `eliminar_pedido`/`recomprobar_pedido`, vars `url`/`valido`/`mensaje` del item (Task 2).
- Produces: nada nuevo para otras tasks (última task).

- [ ] **Step 1: Añadir el diálogo de confirmación a `scenes/Main.tscn`**

Añadir al final del archivo (hijo de la raíz `Main`):

```
[node name="ConfirmarBorrado" type="ConfirmationDialog" parent="."]
unique_name_in_owner = true
title = "Eliminar enlace"
ok_button_text = "Eliminar"
```

- [ ] **Step 2: Modificar `scripts/main.gd`**

2a. Constante y estado nuevo (tras las const existentes):

```gdscript
const EstadoStoreScript := preload("res://scripts/estado_store.gd")
```

```gdscript
var _estado_store: RefCounted
var _estados := {}
var _borrados := {}
var _item_pendiente_borrar: Button = null
```

2b. En `_ready()`, conectar la confirmación:

```gdscript
	%ConfirmarBorrado.confirmed.connect(_confirmar_borrado)
```

2c. Sustituir `_cargar_datos()` para inicializar el store, filtrar borrados y cargar estados:

```gdscript
func _cargar_datos() -> void:
	var base := _leer_array(DATA_RES)
	var usuario := _leer_array(DATA_USER)
	_entradas = base
	if not usuario.is_empty():
		var urls := {}
		for entrada in _entradas:
			if typeof(entrada) == TYPE_DICTIONARY:
				urls[str(entrada.get("url", ""))] = true
		for entrada in usuario:
			if typeof(entrada) != TYPE_DICTIONARY:
				continue
			var url := str(entrada.get("url", ""))
			if url.is_empty() or urls.has(url):
				continue
			_entradas.append(entrada)
			urls[url] = true

	_estado_store = EstadoStoreScript.new()
	var datos: Dictionary = _estado_store.cargar()
	_estados = datos.get("estados", {})
	_borrados = datos.get("borrados", {})
	_entradas = _entradas.filter(
		func(entrada: Variant) -> bool:
			return typeof(entrada) != TYPE_DICTIONARY \
				or not _borrados.has(str(entrada.get("url", "")))
	)
```

2d. En `_mostrar_lista()`, tras `item.setup(...)`, aplicar estado guardado, conectar acciones y preparar acciones:

```gdscript
		var url_item := str(entrada.get("url", ""))
		var estado: Dictionary = _estados.get(url_item, {})
		if estado.is_empty():
			item.mostrar_acciones(false)
		else:
			item.aplicar_estado(estado.get("valido"), str(estado.get("mensaje", "")))
		item.eliminar_pedido.connect(_on_eliminar_pedido.bind(item))
		item.recomprobar_pedido.connect(_on_recomprobar_pedido.bind(item))
```

2e. Cambiar la conexión one-shot en `_lanzar_siguiente()` para pasar el item y guardar al terminar:

```gdscript
		item.verificacion_terminada.connect(_on_item_terminado.bind(item), CONNECT_ONE_SHOT)
		item.verificar()
```

Y reescribir `_on_item_terminado(item: Button)` para persistir cada resultado:

```gdscript
func _on_item_terminado(item: Button) -> void:
	_en_vuelo = maxi(_en_vuelo - 1, 0)
	_hechos += 1
	progreso.text = "Comprobando %d/%d…" % [_hechos, _total]
	if is_instance_valid(item):
		_estado_store.guardar_estado(item.url, item.valido == true, item.mensaje)
	_aplicar_filtro()
	if not _cola.is_empty() or _en_vuelo > 0:
		_lanzar_siguiente()
		return

	%BotonComprobar.disabled = false
	var caidos := 0
	for hijo in lista.get_children():
		if is_instance_valid(hijo) and hijo.valido == false:
			caidos += 1
	progreso.text = "Listo: %d caídos de %d" % [caidos, _total]
```

> Ojo: reindexar items ya comprobados. El bucle final ya cuenta `hijo.valido == false`; se añade `is_instance_valid` para tolerar un posible item eliminado a mitad de escaneo.

2f. Re-comprobar individual:

```gdscript
func _on_recomprobar_pedido(item: Button) -> void:
	if not is_instance_valid(item):
		return
	if item.estado == "comprobando":
		return
	progreso.text = "Re-comprobando %s…" % item.url
	item.verificacion_terminada.connect(_persistir_recompra.bind(item), CONNECT_ONE_SHOT)
	item.verificar()


func _persistir_recompra(item: Button) -> void:
	if not is_instance_valid(item):
		return
	_estado_store.guardar_estado(item.url, item.valido == true, item.mensaje)
	_aplicar_filtro()
```

2g. Eliminar con confirmación:

```gdscript
func _on_eliminar_pedido(item: Button) -> void:
	_item_pendiente_borrar = item
	%ConfirmarBorrado.dialog_text = "¿Eliminar «%s» para siempre?" % item.get_node("Margen/Fila/Textos/NombreLabel").text
	%ConfirmarBorrado.popup_centered()


func _confirmar_borrado() -> void:
	var item := _item_pendiente_borrar
	_item_pendiente_borrar = null
	if not is_instance_valid(item):
		return

	_estado_store.marcar_borrado(item.url)
	_estado_store.borrar_estado(item.url)
	_estados.erase(item.url)

	for i in range(_entradas.size() - 1, -1, -1):
		if typeof(_entradas[i]) == TYPE_DICTIONARY and str(_entradas[i].get("url", "")) == item.url:
			_entradas.remove_at(i)

	item.queue_free()
	progreso.text = "Enlace eliminado"
	_aplicar_filtro()
```

- [ ] **Step 3: Verificar sintaxis**

Run:

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://scripts/main.gd --check-only 2>&1
```

Expected: sin `Parse Error` ni `SCRIPT ERROR`.

- [ ] **Step 4: Smoke test de la escena principal**

Run:

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" res://scenes/Main.tscn --quit-after 60 2>&1 | Select-String -Pattern "Parse Error|SCRIPT ERROR|ERROR"
```

Expected: sin coincidencias (la escena carga e instancia sin errores de script).

- [ ] **Step 5: Re-ejecutar tests de Task 1 (regresión)**

Run:

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_estado_store.gd 2>&1 | Select-Object -Last 3
```

Expected: `TESTS OK`.

- [ ] **Step 6: Prueba funcional manual (opcional, con el MCP godot)**

- `godot_organizer_godot_run` → la app abre.
- Pulsar **Comprobar**: al terminar el escaneo, `user://estados.json` existe con entradas por URL (`valido`, `mensaje`, `fecha`).
- Cerrar y reabrir: los colores/mensajes del último escaneo se restauran sin red.
- Filtrar por **Caídos / no existen**: cada fila inválida muestra **Volver a comprobar** y **Eliminar**; clic en ellos NO abre el navegador.
- **Volver a comprobar**: cambia el estado de esa fila y actualiza `user://estados.json` para esa URL.
- **Eliminar**: aparece el diálogo; al confirmar, la fila desaparece y la URL queda en `user://borrados.json`; no reaparece al reiniciar.
- Verificar que `data/data.json` no cambia.

- [ ] **Step 7: Commit**

```bash
git add scenes/Main.tscn scripts/main.gd
git commit -m "feat: estado de escaneo persistente, eliminar enlaces caídos y re-comprobación individual"
```

---

## Criterios de aceptación (desde la spec)

1. `user://estados.json` se crea al escanear/re-comprobar y se restaura al abrir (sin red).
2. `user://borrados.json` guarda las URLs eliminadas; esas filas no aparecen al abrir.
3. Los enlaces inválidos muestran Eliminar (con confirmación) y Volver a comprobar.
4. `data/data.json` no se modifica en ningún flujo.
5. El escaneo global sobrescribe el estado guardado.
6. Tests headless (`test_estado_store.gd`) pasan y smoke tests de escenas sin errores.

## Self-Review

- Cobertura de spec: estado en `user://` (Task 1), store separado (Task 1), acciones solo en inválidos (Task 2), confirmación/borrado/borrados (Task 3), grabado incremental al terminar cada item (Task 3), re-comprobar individual (Task 3), filtros intactos (sin tocar `_aplicar_filtro`), `data.json` intacto (no se llama a `_guardar_datos` en borrado).
- Sin placeholders: todos los pasos con código concreto y comandos exactos.
- Tipos consistentes: `guardar_estado(url, valido: bool, mensaje: String)`, `aplicar_estado(valido: Variant, texto: String)`, señales `eliminar_pedido`/`recomprobar_pedido` sin argumentos (bind del item en main), `_on_item_terminado(item: Button)` — consistente en Task 2 y Task 3.