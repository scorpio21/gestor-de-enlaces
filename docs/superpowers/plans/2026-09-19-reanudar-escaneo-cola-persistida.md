# #13 Reanudar escaneo interrumpido (cola persistida) — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persistir la cola de verificación pendiente en `user://colas.json` y ofrecer reanudarla por diálogo al abrir la app, sin perder el progreso tras una interrupción.

**Architecture:** Nuevo store `scripts/cola_store.gd` (RefCounted, patrón de `estado_store.gd`) que guarda `{ "urls": [...], "fecha": N }`. ««main.gd»» integra: guarda la cola al iniciar el escaneo y tras cada enlace, la limpia al terminar, y ofrece reanudar vía un `ConfirmationDialog` cuando hay pendientes al abrir. Se guardan URLs (claves estables), no índices.

**Tech Stack:** GDScript (Godot 4.7). Tests SceneTree headless con `TESTS OK`/`quit(0)`. JSON con `FileAccess` (tal como `estado_store.gd`).

## Global Constraints

- Convenciones: tabs, sin comentarios, UI en español, preload-const para tipos nuevos.
- `cola_store.gd` no conoce UI ni main; solo paths y JSON. Separación store/UI del resto del proyecto.
- Reanudación con diálogo de confirmación; escribir tras cada enlace; guardar URLs y filtrar al reanudar.
- `_reanudar_escaneo()` **re-lee `cargar()`** al confirmar (no confía en la captura del popup).
- Batería: `bash tests/run_battery.sh` con `GODOT_BIN="K:/Godot_v4.6.1/Godot_v4.7.2-stable_win64_console.exe"` (17 suites → 18 con la nueva).
- Tests headless: el diálogo solo se dispara en build con UI; en tests se invoca `_reanudar_escaneo()` directamente.
- `_reanudar_escaneo` usa `str(entrada.get("url",""))` y `pendientes.has(hijo.url)` como base para emparejar: si una URL persistida no da match con `hijo.url` literal se descarta (los tests usan URLs literales simplemente).

---
### Task 1: `scripts/cola_store.gd` + suite `test_cola_store.gd` (TDD)

**Files:**
- Create: `scripts/cola_store.gd`
- Create: `tests/test_cola_store.gd`
- Test: `tests/test_cola_store.gd`

**Interfaces:**
- Produces: `class_name ColaStore extends RefCounted`, `_init(base := "user://")`, `cargar() -> Dictionary`, `guardar(urls: Array) -> bool`, `limpiar() -> bool`. Consumidas por Tasks 2-4.

- [ ] **Step 1: Escribir el test**

`tests/test_cola_store.gd` (mismo esqueleto que `test_estado_store.gd` si existiera; si no, el de `test_link_checker_timeout.gd`):

```gdscript
extends SceneTree

const ColaStore := preload("res://scripts/cola_store.gd")
const BASE := "user://__test_cola__"

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	var store := ColaStore.new(BASE)

	var vacio: Dictionary = store.cargar()
	_check(vacio.get("urls", null) is Array and (vacio.get("urls", []) as Array).is_empty(), "cargar sin fichero devuelve urls vacío")
	_check(int(vacio.get("fecha", -1)) == 0, "cargar sin fichero devuelve fecha 0")

	_check(store.guardar(["a", "b"]), "guardar devuelve true")
	var con_datos: Dictionary = store.cargar()
	_check((con_datos.get("urls", []) as Array) == ["a", "b"] and int(con_datos.get("fecha", 0)) > 0, "cargar recupera las urls y una fecha > 0")

	_check(store.guardar([]), "guardar([]) devuelve true")
	var vaciado: Dictionary = store.cargar()
	_check((vaciado.get("urls", []) as Array).is_empty() and int(vaciado.get("fecha", 0)) > 0, "guardar([]) conserva el intento con fecha")

	_check(store.limpiar(), "limpiar devuelve true")
	var limpio: Dictionary = store.cargar()
	_check((limpio.get("urls", []) as Array).is_empty() and int(limpio.get("fecha", 0)) == 0, "tras limpiar, cargar vuelve a estar vacío")

	var a := ColaStore.new(BASE)
	_check(a.guardar(["x"]), "store A guarda")
	var b := ColaStore.new(BASE)
	_check((b.cargar().get("urls", []) as Array) == ["x"], "store B (nueva instancia) recupera lo guardado por A")

	DirAccess.remove_absolute(BASE)
	_cerrar()


func _check(cond: bool, nombre: String) -> void:
	if cond:
		print("  OK: %s" % nombre)
	else:
		_fallos += 1
		printerr("  check FALLIDO — ", nombre)


func _cerrar() -> void:
	if _fallos == 0:
		print("TESTS OK")
	else:
		print("TESTS FALLIDOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)
```

- [ ] **Step 2: Ejecutar y verificar rojo**

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_cola_store.gd
```
Expected: `SCRIPT ERROR: Invalid call. Nonexistent function...` (falla `ColaStore.new`) → se considera el rojo. Usar timeout corto (~30 s) para no quedar colgado tras el crash.

- [ ] **Step 3: Implementar `cola_store.gd`**

```gdscript
class_name ColaStore
extends RefCounted

var _base: String
const _NOMBRE := "colas.json"


func _init(base := "user://") -> void:
	_base = base


func cargar() -> Dictionary:
	return {
		"urls": _leer_urls(),
		"fecha": _leer_fecha(),
	}


func guardar(urls: Array) -> bool:
	var datos := {"urls": urls, "fecha": int(Time.get_unix_time_from_system())}
	return _escribir_json(_ruta(), datos)


func limpiar() -> bool:
	if not FileAccess.file_exists(_ruta()):
		return true
	var err := DirAccess.remove_absolute(_ruta())
	return err == OK


func _leer_urls() -> Array:
	var dato: Variant = _leer_json(_ruta())
	if typeof(dato) != TYPE_DICTIONARY:
		return []
	var u: Variant = (dato as Dictionary).get("urls", [])
	return u if typeof(u) == TYPE_ARRAY else []


func _leer_fecha() -> int:
	var dato: Variant = _leer_json(_ruta())
	if typeof(dato) != TYPE_DICTIONARY:
		return 0
	return int((dato as Dictionary).get("fecha", 0))


func _leer_json(ruta: String) -> Variant:
	if not FileAccess.file_exists(ruta):
		return null
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return null
	var json := JSON.new()
	if json.parse(archivo.get_as_text()) != OK:
		return null
	return json.data


func _escribir_json(ruta: String, dato: Variant) -> bool:
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		return false
	archivo.store_string(JSON.stringify(dato, "\t"))
	archivo.close()
	return true


func _ruta() -> String:
	if _base.ends_with("://"):
		return _base + _NOMBRE
	return _base + "/" + _NOMBRE
```

- [ ] **Step 4: Ejecutar y verificar verde**

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_cola_store.gd
```
Expected: `TESTS OK` y `quit(0)`.

- [ ] **Step 5: Commit**

```bash
git add scripts/cola_store.gd tests/test_cola_store.gd scripts/cola_store.gd.uid
git commit -m "feat(escaneo): store de cola persistida user://colas.json (cargar/guardar/limpiar) con tests"
```

---
### Task 2: Integración en `main.gd` — persistir la cola del escaneo

**Files:**
- Modify: `scripts/main.gd` (const preload ~línea 14, vars ~línea 37, `_ready` wiring, `_comprobar_visibles` ~601, `_on_item_terminado` ~633)

**Interfaces:**
- Consumes: `ColaStore` (Task 1) — `cargar()/guardar()/limpiar()`.
- Produces: `_cola_store`, `_persistir_cola()`. Consumidos por Task 3 y 4.

- [ ] **Step 1: Escribir los checks de integración (rojo)**

En `tests/test_main_barra.gd`, añadir tras el bloque de la barra de progreso (tras la línea ~271 `_comprobar_visibles` oculto):

> `_comprobar_visibles` lanza `item.verificar()` (red, timeout 10s) — no determinista en headless. El test arma `_cola` manualmente y llama a `_persistir_cola()` para que sea unitario y rápido:

```gdscript
	# Cola persistida (#13)
	main_script._cola_store = (load("res://scripts/cola_store.gd") as GDScript).new("user://__test_main__")
	var item_a: Button = LIST_ITEM_SCENE.instantiate()
	item_a.url = "https://a.test"
	main_script._cola.append(item_a)
	var item_c: Button = LIST_ITEM_SCENE.instantiate()
	item_c.url = "https://c.test"
	main_script._cola.append(item_c)
	main_script._persistir_cola()
	var cola_guardada: Array = main_script._cola_store.cargar().get("urls", [])
	_check(cola_guardada.size() == 2 and "https://a.test" in cola_guardada and "https://c.test" in cola_guardada, "persistir cola guarda las urls de los items")
	item_a.free()
	item_c.free()
	main_script._cola.clear()
	main_script._cola_store.limpiar()
	DirAccess.remove_absolute("user://__test_main__")
```

> El check de vinculación real (que `_comprobar_visibles` y `_on_item_terminado` llaman a `_persistir_cola`) se verifica de forma unitaria invocando `_persistir_cola()` y por inspección del código; el flujo asíncrono de red no es determinista en headless.

- [ ] **Step 2: Ejecutar y verificar rojo**

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd
```
Expected: `check FALLIDO — persistir cola guarda las urls de los items` (no existe `main_script._persistir_cola`).

- [ ] **Step 3: Implementar en `main.gd`**

En cabecera (tras `const DiagnosticoScript`):
```gdscript
const ColaStoreScript := preload("res://scripts/cola_store.gd")
```

Tras `var _limpieza_resultado: Dictionary = {}`:
```gdscript
var _cola_store: RefCounted = null
```

En `_ready()`, junto a la creación de `_config_store`:
```gdscript
_cola_store = ColaStoreScript.new()
```

Añadir la función (justo antes de `_comprobar_visibles`):
```gdscript
func _persistir_cola() -> void:
	if _cola_store == null:
		return
	var urls: Array = []
	for item in _cola:
		if is_instance_valid(item):
			urls.append(item.url)
	_cola_store.guardar(urls)
```

En `_comprobar_visibles()`, tras armar `_total`/`_hechos`/`_en_vuelo` (antes de `if _total == 0`, ~línea 607):
```gdscript
	_persistir_cola()
```

En `_on_item_terminado()`, dentro de la rama `if not _cola.is_empty() or _en_vuelo > 0:` (tras `_lanzar_siguiente()`), añadir:
```gdscript
		_persistir_cola()
```

Y en la rama final (cuando termina, ~línea 650, antes de `%BotonComprobar.disabled = false`):
```gdscript
	if _cola_store != null:
		_cola_store.limpiar()
```

- [ ] **Step 4: Ejecutar verde**

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd
```
Expected: `TESTS OK`.

- [ ] **Step 5: Commit**

```bash
git add scripts/main.gd tests/test_main_barra.gd
git commit -m "feat(escaneo): persistir la cola pendiente en user://colas.json durante el escaneo"
```

---
### Task 3: Diálogo de reanudación en `Main.tscn` + `_reanudar_escaneo`

**Files:**
- Modify: `scenes/Main.tscn` (nuevo nodo `ConfirmarReanudar` tras `ConfirmarRestaurar`, ~línea 152)
- Modify: `scripts/main.gd` (`_revisar_cola_pendiente`, `_reanudar_escaneo`, `_descartar_cola_pendiente`, wiring en `_ready`)

**Interfaces:**
- Consumes: `_cola_store`, `_persistir_cola`, `_cola`, `_entradas`, `_lanzar_siguiente`, `_actualizar_barra` (Tasks 1-2).
- Produces: nodo `%ConfirmarReanudar` + métodos de resume; conserva el flujo `_comprobar_visibles` intacto para escaneos nuevos.

- [ ] **Step 1: Escribir checks (rojo) en `test_main_barra.gd`**

Añadir tras el bloque de la cola de la Task 2:

```gdscript
	# Reanudación (#13)
	main_script._cola_store = (load("res://scripts/cola_store.gd") as GDScript).new("user://__test_main__")
	main_script._entradas = [
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""},
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": ""},
	]
	main_script._refrescar_vista()
	await process_frame
	_check(main.has_node("%ConfirmarReanudar"), "el diálogo ConfirmarReanudar existe en Main.tscn")
	var diag_reanudar: ConfirmationDialog = main.get_node("%ConfirmarReanudar")
	main_script._cola_store.guardar(["https://b.test"])
	main_script._cola.clear()
	main_script._reanudar_escaneo()
	_check(main_script._cola.size() == 1 and main_script._cola[0].url == "https://b.test", "reanudar reconstruye la cola con solo las urls pendientes")
	_check(main_script._total == 1, "reanudar usa el total de pendientes")
	_check(main_script._cola_store.cargar().get("urls", []) == ["https://b.test"], "reanudar conserva la cola persistida mientras escanea")
	main_script._cola.clear()
	main_script._cola_store.limpiar()

	main_script._cola_store.guardar(["https://nope.test"])
	main_script._cola.clear()
	main_script._reanudar_escaneo()
	_check(main_script._cola.is_empty() and (main_script._cola_store.cargar().get("urls", []) as Array).is_empty(), "reanudar con urls inexistentes descarta y limpia")
	DirAccess.remove_absolute("user://__test_main__")
```

- [ ] **Step 2: Ejecutar y verificar rojo**

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd
```
Expected: `check FALLIDO — el diálogo ConfirmarReanudar existe` y `check FALLIDO — reanudar reconstruye la cola...` (métodos inexistentes).

- [ ] **Step 3: Añadir el nodo en `Main.tscn`**

Tras `ConfirmarRestaurar` (línea ~152):
```
[node name="ConfirmarReanudar" type="ConfirmationDialog" parent="."]
unique_name_in_owner = true
title = "Reanudar escaneo"
ok_button_text = "Reanudar"
cancel_button_text = "Descartar"
```

- [ ] **Step 4: Implementar los métodos en `main.gd`**

En `_ready()`, tras la línea `_actualizar_status()` y antes de `_rearmar_auto_escaneo()`:
```gdscript
	%ConfirmarReanudar.confirmed.connect(_reanudar_escaneo)
	%ConfirmarReanudar.canceled.connect(_descartar_cola_pendiente)
	_revisar_cola_pendiente()
```

Añadir las funciones (tras `_on_item_terminado`):

```gdscript
func _revisar_cola_pendiente() -> void:
	if _cola_store == null:
		return
	var pendientes: Array = _cola_store.cargar().get("urls", [])
	if pendientes.is_empty():
		return
	var set_catalogo := {}
	for entrada in _entradas:
		if typeof(entrada) == TYPE_DICTIONARY:
			set_catalogo[GestorCatalogoScript.clave_unica(str(entrada.get("url", "")))] = true
	var validas: Array = []
	for url in pendientes:
		if set_catalogo.has(GestorCatalogoScript.clave_unica(str(url))):
			validas.append(str(url))
	if validas.is_empty():
		_cola_store.limpiar()
		return
	%ConfirmarReanudar.dialog_text = "¿Reanudar escaneo de %d enlaces?" % validas.size()
	%ConfirmarReanudar.popup_centered()


func _reanudar_escaneo() -> void:
	if _cola_store == null:
		return
	var pendientes: Array = _cola_store.cargar().get("urls", [])
	if pendientes.is_empty():
		return
	_cola.clear()
	_en_vuelo = 0
	for hijo in lista.get_children():
		if is_instance_valid(hijo) and pendientes.has(hijo.url):
			_cola.append(hijo)
	_total = _cola.size()
	if _total == 0:
		_cola_store.limpiar()
		%BotonComprobar.disabled = false
		return
	_hechos = 0
	%BotonComprobar.disabled = true
	%BarraProgreso.visible = true
	%BarraProgreso.remove_theme_stylebox_override("fill")
	_actualizar_barra(0, _total)
	progreso.text = "Comprobando 0/%d…" % _total
	_lanzar_siguiente()


func _descartar_cola_pendiente() -> void:
	if _cola_store != null:
		_cola_store.limpiar()
```

> Observación: `_reanudar_escaneo` se conecta directo a `confirmed`. Los items reconstruidos son los mismos objetos Button de la lista actual (`lista.get_children()`), así que sus señales de `verificacion_terminada` reutilizan el flujo normal.

- [ ] **Step 5: Verificar verde (test + un smoke de arranque)**

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd
```
Expected: `TESTS OK`.

- [ ] **Step 6: Commit**

```bash
git add scenes/Main.tscn scripts/main.gd tests/test_main_barra.gd
git commit -m "feat(escaneo): reanudar escaneo interrumpido con diálogo de confirmación al abrir"
```

---
### Task 4: Batería completa, push y cierre de #13

- [ ] **Step 1: Batería completa**

```bash
& "C:\Program Files\Git\bin\bash.exe" -c 'cd /k/gestor-de-enlaces && GODOT_BIN="K:/Godot_v4.6.1/Godot_v4.7.2-stable_win64_console.exe" bash tests/run_battery.sh'
```
Expected: 18/18 suites OK (17 anteriores + test_cola_store).

- [ ] **Step 2: Push y cierre de issue**

```bash
git push origin main
gh issue close 13 --repo scorpio21/gestor-de-enlaces --comment "Implementado: cola persistida en user://colas.json con persistencia tras cada enlace, diálogo de reanudación al abrir y filtrado por catálogo. Nuevo store (cola_store.gd) con suite propia + tests de integración en test_main_barra. Batería 18/18 OK."
```