# Lote UI: copiar URL (#16), tooltip de detalle (#18) y barra de progreso (#15) — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Añadir a cada fila del catálogo un botón de copiar URL siempre visible, un tooltip con código HTTP/fecha/mensaje y una barra de progreso que se colorea al terminar el escaneo (aviso sin diálogos).

**Architecture:** El código HTTP fluye de `link_checker` → `list_item` → `estado_store` como nuevo campo `codigo` (junto a `fecha`, que ya se persistía), siempre con parámetros opcionales retrocompatibles. El tooltip se compone en `list_item` a partir de `url` + estado + campos. El botón copiar emite una señal que `main` conecta al portapapeles. La barra vive en `Main.tscn` y `main` solo actualiza valor/color.

**Tech Stack:** Godot 4.7 / GDScript, harness de tests `extends SceneTree`, HTTPClient, `Test-Consumo`: sin red en tests.

## Map of Files

| File | Role |
|---|---|
| `scripts/link_checker.gd` | Modificar: propiedad `codigo` + asignación en `_leer_respuesta` |
| `scripts/estado_store.gd` | Modificar: `guardar_estado(..., codigo := 0)` |
| `scripts/list_item.gd` | Modificar: campos `codigo`/`fecha`, tooltip, botón copiar |
| `scripts/main.gd` | Modificar: persistencia con `codigo`/`fecha`, portapapeles, barra |
| `scenes/ListItem.tscn` | Modificar: `%BtnCopiar`, `%TemporizadorCopiar` |
| `scenes/Main.tscn` | Modificar: `%BarraProgreso` |
| `tests/test_estado_store.gd` | Modificar: +2 checks |
| `tests/test_link_checker_timeout.gd` | Modificar: +2 checks |
| `tests/test_list_item.gd` | Modificar: +10 checks |
| `tests/test_main_barra.gd` | Modificar: +9 checks |

No se crean archivos nuevos → no aplican sidecars `.uid` nuevos (se verifica en la tarea 5).

## Global Constraints

- **Editor-editable:** todo el layout vive en las escenas `.tscn` con nodos estándar y `unique_name_in_owner`; el código solo maneja estado dinámico (valor, texto, color transitorio), nunca construye UI proceduralmente.
- **Textos de UI en español.** `Class_name` proscrito (usar preload). Prohibido cualquier comentario en el código.
- **Escenas `.tscn` a columna 0** (formato de texto del editor). Scripts/tscn que se editen se guardan con la indentación ya existente (tabs, no espacios).
- **Harness SceneTree (patrón fijado del repo):** checks `print("  OK: %s")`, fallos `push_error("FALLO: %s")`, cierre `TESTS OK` + `quit(0)` + `return` o `TESTS FALLIDOS: N` + `quit(1)`. Salida limpia, sin red en ningún test.
- **Motor/binario headless:** `K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe` con `--headless --path "K:\gestor-de-enlaces"`. Todas las tareas corren en PowerShell (workdir `K:\gestor-de-enlaces`).
- **Compatibilidad:** `guardar_estado(url, valido, mensaje, codigo := 0)` y `aplicar_estado(ok, texto, codigo := 0, fecha := 0)` retrocompatibles (parámetros opcionales). Entradas viejas sin `codigo` → `0` → tooltip `Código: —`.
- **Paleta (idéntica a la existente):** verde `Color(0.35, 0.85, 0.45, 1)`, rojo `Color(0.95, 0.35, 0.35, 1)`, gris pendiente `Color(0.55, 0.55, 0.55, 1)`.
- `DisplayServer.clipboard_set` nunca bloquea el flujo (schreib/open fallos ignorados).

---

### Task 1: Campo `codigo` y `fecha` en toda la cadena (#18 base de datos)

**Files:**
- Modify: `scripts/link_checker.gd:5` (propiedad), `scripts/link_checker.gd:99-100` (`_leer_respuesta`)
- Modify: `scripts/estado_store.gd:18-25` (`guardar_estado`)
- Modify: `scripts/list_item.gd:7-16` (campos), `scripts/list_item.gd:38-50` (`aplicar_estado`), `scripts/list_item.gd:83-90` (`_on_check_terminado`)
- Modify: `scripts/main.gd:231-237` (`_on_item_terminado`), `scripts/main.gd:262-268` (`_persistir_recompra`)
- Test: `tests/test_estado_store.gd`, `tests/test_link_checker_timeout.gd`, `tests/test_list_item.gd`, `tests/test_main_barra.gd`

**Interfaces:**
- Consumes: `link_checker` existente (señal `terminado(valido, mensaje)`), `estado_store.guardar_estado` actual, `item.valido`/`item.mensaje` (dynamic access sobre `Button`, ya usado en `main.gd`).
- Produces: `LinkChecker.codigo: int` (default `0`, asignable); `EstadoStore.guardar_estado(url, valido, mensaje, codigo := 0)` que persiste `{"valido", "mensaje", "codigo", "fecha"}`; `ListItem.codigo: int` y `ListItem.fecha: int`; `aplicar_estado(ok, texto, codigo := 0, fecha := 0)`; `_estados[url]` en `main` con `{valido, mensaje, codigo, fecha}`; `_estado_store.guardar_estado(..., item.codigo)`.

- [ ] **Step 1: Escribir los tests que fallan**

**`tests/test_estado_store.gd`** — insertar en `_initialize()` tras el `_check(json_roto_no_rompe(), ...)` y antes de `_limpiar()`:
```gdscript
	_check(guarda_codigo(), "guardar_estado() persiste el código HTTP")
	_check(codigo_por_defecto(), "guardar_estado() sin código persiste 0")
```
Y añadir las funciones después de `json_roto_no_rompe()`:
```gdscript
func guarda_codigo() -> bool:
	var store := EstadoStore.new(BASE)
	store.guardar_estado("https://ejemplo.com/a", true, "OK (200)", 200)
	var e: Dictionary = store.cargar()["estados"].get("https://ejemplo.com/a", {})
	return int(e.get("codigo", -1)) == 200


func codigo_por_defecto() -> bool:
	var store := EstadoStore.new(BASE)
	store.guardar_estado("https://ejemplo.com/a", true, "OK (200)")
	var e: Dictionary = store.cargar()["estados"].get("https://ejemplo.com/a", {})
	return int(e.get("codigo", -1)) == 0
```

**`tests/test_link_checker_timeout.gd`** — en `_arrancar()`, después de `_check(is_equal_approx(checker.timeout_s, 25.0), ...)` y antes de `checker.free()`:
```gdscript
	_check(checker.codigo == 0, "codigo tiene default 0")
	checker.codigo = 404
	_check(checker.codigo == 404, "codigo es asignable")
```

**`tests/test_list_item.gd`** — insertar tras el bloque de miniaturas (después de `_check(_miniatura_es(inexistente, true), ...)`) y antes de `if _fallos == 0:`:
```gdscript
	var con_detalle := _crear_item()
	con_detalle.setup("Nom", "Desc", "https://ejemplo.com/d")
	con_detalle.aplicar_estado(true, "OK (200)", 200, 1000000000)
	root.add_child(con_detalle)
	await process_frame
	_check(con_detalle.codigo == 200, "aplicar_estado() guarda el código")
	_check(con_detalle.fecha == 1000000000, "aplicar_estado() guarda la fecha")
```

**`tests/test_main_barra.gd`** — en el bloque de `_persistir_recompra`, inmediatamente después de `main_script._persistir_recompra(item)`:
```gdscript
		var estado_memoria: Dictionary = main_script._estados.get(item.url, {})
		_check(estado_memoria.has("codigo") and int(estado_memoria.get("codigo", -1)) == 0, "el estado en memoria conserva el código tras re-comprobar")
		_check(int(estado_memoria.get("fecha", 0)) > 0, "el estado en memoria conserva la fecha tras re-comprobar")
```

- [ ] **Step 2: Ejecutar los tests para verificar que fallan**

```powershell
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_estado_store.gd 2>&1 | Select-Object -Last 3
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_link_checker_timeout.gd 2>&1 | Select-Object -Last 3
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_list_item.gd 2>&1 | Select-Object -Last 3
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd 2>&1 | Select-Object -Last 3
```
Expected (estado RED):
- `test_estado_store.gd` y `test_list_item.gd`: `Parse Error`/`'Too many arguments…'` por llamar `guardar_estado`/`aplicar_estado` con 4 argumentos (firma actual 3/2).
- `test_link_checker_timeout.gd`: `Invalid get index 'codigo'…`.
- `test_main_barra.gd`: `TESTS FALLIDOS: 2` (faltan `codigo`/`fecha` en el dict de memoria).

- [ ] **Step 3: Implementación mínima**

**`scripts/link_checker.gd`** — tras `var timeout_s: float = 10.0` añadir:
```gdscript
var codigo := 0
```
En `_leer_respuesta()` (línea 100), cambiar:
```gdscript
	var codigo := _cliente.get_response_code()
```
por:
```gdscript
	codigo = _cliente.get_response_code()
```
(ahora el `codigo` local pasa a ser la propiedad del script; las redirecciones reasignan la propiedad y los cierres sin respuesta la dejan en `0`).

**`scripts/estado_store.gd`** — sustituir `guardar_estado` completa:
```gdscript
func guardar_estado(url: String, valido: bool, mensaje: String, codigo := 0) -> bool:
	var estados := _leer_estados()
	estados[url] = {
		"valido": valido,
		"mensaje": mensaje,
		"codigo": codigo,
		"fecha": int(Time.get_unix_time_from_system()),
	}
	return _escribir_json(_ruta("estados.json"), estados)
```

**`scripts/list_item.gd`** — tras `var mensaje: String = ""` añadir:
```gdscript
var codigo := 0
var fecha := 0
```
Sustituir `aplicar_estado` completa:
```gdscript
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
	mostrar_acciones(ok == false)
```
Sustituir `_on_check_terminado` completa:
```gdscript
func _on_check_terminado(ok: bool, texto: String) -> void:
	codigo = _checker.codigo
	fecha = int(Time.get_unix_time_from_system())
	_checker = null
	valido = ok
	estado = "ok" if ok else "caido"
	mensaje = texto
	_pintar_estado(texto, Color(0.35, 0.85, 0.45, 1) if ok else Color(0.95, 0.35, 0.35, 1))
	mostrar_acciones(not ok)
	verificacion_terminada.emit()
```

**`scripts/main.gd`** — en `_on_item_terminado`, sustituir las líneas 233-237 (se conservan `_hechos += 1` y el texto del label `Comprobando…`):
```gdscript
	_hechos += 1
	progreso.text = "Comprobando %d/%d…" % [_hechos, _total]
	var ahora := int(Time.get_unix_time_from_system())
	if is_instance_valid(item):
		_estado_store.guardar_estado(item.url, item.valido == true, item.mensaje, item.codigo)
		_estados[item.url] = {"valido": item.valido == true, "mensaje": item.mensaje, "codigo": item.codigo, "fecha": ahora}
```
En `_persistir_recompra`, sustituir las líneas 265-266:
```gdscript
	var ahora := int(Time.get_unix_time_from_system())
	_estado_store.guardar_estado(item.url, item.valido == true, item.mensaje, item.codigo)
	_estados[item.url] = {"valido": item.valido == true, "mensaje": item.mensaje, "codigo": item.codigo, "fecha": ahora}
```

- [ ] **Step 4: Ejecutar los tests para verificar que pasan**

```powershell
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_estado_store.gd 2>&1 | Select-Object -Last 3
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_link_checker_timeout.gd 2>&1 | Select-Object -Last 3
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_list_item.gd 2>&1 | Select-Object -Last 3
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd 2>&1 | Select-Object -Last 3
```
Expected: `TESTS OK`, EXIT 0.
- `test_estado_store.gd`: 8 checks.
- `test_link_checker_timeout.gd`: 4 checks.
- `test_list_item.gd`: 8 checks.
- `test_main_barra.gd`: 11 checks.

- [ ] **Step 5: Commit**

```powershell
git add scripts/link_checker.gd scripts/estado_store.gd scripts/list_item.gd scripts/main.gd tests/test_estado_store.gd tests/test_link_checker_timeout.gd tests/test_list_item.gd tests/test_main_barra.gd && git commit -m "feat: código HTTP y fecha en el estado de comprobación (#18)" -q
```

---

### Task 2: Tooltip de detalle (#18)

**Files:**
- Modify: `scripts/list_item.gd:19-35` (`_ready`/`setup`), `scripts/list_item.gd:38-50` (`aplicar_estado`), `scripts/list_item.gd:83-90` (`_on_check_terminado`)
- Modify: `scripts/main.gd:189-195` (`_mostrar_lista` aplica estado persistido)
- Test: `tests/test_list_item.gd`

**Interfaces:**
- Consumes: `ListItem.codigo` / `ListItem.fecha` (Task 1); `main._estados` (Task 1) con `codigo`/`fecha`.
- Produces: `ListItem.formatear_fecha(unix: int) -> String` (estático); `_actualizar_tooltip() -> void` (privado, llama desde `setup`/`aplicar_estado`/`_on_check_terminado`); tooltip compuesto: URL + `Código: N|—` (+ `Comprobado: dd/mm/aaaa hh:mm` si `fecha > 0`) + mensaje; pendiente → URL + `Sin comprobar`.

- [ ] **Step 1: Escribir el test que falla**

**`tests/test_list_item.gd`** — añadir al inicio, junto a las otras constantes:
```gdscript
const ListItemScript := preload("res://scripts/list_item.gd")
```
Insertar el siguiente bloque tras el bloque del Task 1 (después de `_check(con_detalle.fecha == 1000000000, ...)`) y antes de `if _fallos == 0:`:
```gdscript
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
```

- [ ] **Step 2: Ejecutar el test para verificar que falla**

```powershell
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_list_item.gd 2>&1 | Select-Object -Last 3
```
Expected: RED — `Invalid call. Nonexistent function 'formatear_fecha'…` y comprobaciones de tooltip fallidas (`TESTS FALLIDOS`). La `aplicar_estado` ya acepta 4 argumentos (Task 1 devuelto), así que el modo de fallo ahora es runtime, no parse.

- [ ] **Step 3: Implementación mínima**

**`scripts/list_item.gd`** — añadir tras `aplicar_estado`:
```gdscript
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
```
En `setup()`, sustituir `tooltip_text = enlace` por:
```gdscript
	_actualizar_tooltip()
```
En `aplicar_estado`, añadir al final (`mostrar_acciones(ok == false)` ya existe, añadir justo después):
```gdscript
	_actualizar_tooltip()
```
En `_on_check_terminado`, añadir justo antes de `verificacion_terminada.emit()`:
```gdscript
	_actualizar_tooltip()
```

**`scripts/main.gd`** — en `_mostrar_lista`, sustituir las líneas 190-194:
```gdscript
		var estado: Dictionary = _estados.get(url_item, {})
		if estado.is_empty():
			item.mostrar_acciones(false)
		else:
			item.aplicar_estado(
				estado.get("valido"),
				str(estado.get("mensaje", "")),
				int(estado.get("codigo", 0)),
				int(estado.get("fecha", 0))
			)
```
(Así el tooltip incluye el `codigo`/`fecha` persistidos al recargar la lista; las entradas viejas sin `codigo` → `0` → `Código: —`.)

- [ ] **Step 4: Ejecutar el test para verificar que pasa**

```powershell
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_list_item.gd 2>&1 | Select-Object -Last 3
```
Expected: `TESTS OK`, EXIT 0, 13 checks.

- [ ] **Step 5: Commit**

```powershell
git add scripts/list_item.gd scripts/main.gd tests/test_list_item.gd && git commit -m "feat: tooltip con detalle de estado en cada enlace (#18)" -q
```

---

### Task 3: Botón copiar URL (#16)

**Files:**
- Modify: `scenes/ListItem.tscn:68-91` (nodo `%BtnCopiar` entre `EstadoLabel` y `Acciones`; nodo `%TemporizadorCopiar` al final)
- Modify: `scripts/list_item.gd:3-5` (señal), `scripts/list_item.gd:19-22` (`_ready`), `scripts/list_item.gd:99-102` (handlers)
- Modify: `scripts/main.gd:195-196` (conexión `copiar_pedido`)
- Test: `tests/test_list_item.gd`

**Interfaces:**
- Consumes: `main._mostrar_lista` (donde se conecta por fila); `ListItem.url`.
- Produces: señal `copiar_pedido(url: String)`; `%BtnCopiar` (Button visible siempre, al final de `Fila`); `%TemporizadorCopiar` (Timer `one_shot = true`, `wait_time = 1.5`); handler `_on_copiar()` (emite + feedback `¡Copiada!` + disable + `start()`); `_restaurar_boton_copiar()` (texto `Copiar`, `disabled = false`); `main._on_copiar_pedido(item: Button)` → `DisplayServer.clipboard_set(item.url)`.

- [ ] **Step 1: Escribir el test que falla**

**`tests/test_list_item.gd`** — insertar tras el bloque del Task 2 (después de `_check(sin_estado.tooltip_text == ..., ...)`) y antes de `if _fallos == 0:`:
```gdscript
	var copiar := _crear_item()
	copiar.setup("Nom", "Desc", "https://ejemplo.com/copiar")
	var urls_copiadas: Array[String] = []
	copiar.copiar_pedido.connect(func(u: String) -> void: urls_copiadas.append(u))
	root.add_child(copiar)
	await process_frame
	copiar.get_node("%BtnCopiar").pressed.emit()
	await process_frame
	_check(urls_copiadas == ["https://ejemplo.com/copiar"], "el botón copiar emite copiar_pedido con la URL")
	_check(copiar.get_node("%BtnCopiar").text == "¡Copiada!", "al copiar el botón muestra feedback")
	copiar.get_node("%TemporizadorCopiar").emit_signal("timeout")
	await process_frame
	_check(copiar.get_node("%BtnCopiar").text == "Copiar", "el botón copiar restaura el texto al terminar el temporizador")
```

- [ ] **Step 2: Ejecutar el test para verificar que falla**

```powershell
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_list_item.gd 2>&1 | Select-Object -Last 3
```
Expected: RED — `Invalid node ... '%BtnCopiar'` y `Invalid access to property or key 'copiar_pedido'…`.

- [ ] **Step 3: Implementación mínima**

**`scenes/ListItem.tscn`** — entre el cierre del nodo `EstadoLabel` (línea 75) y `[node name="Acciones" ...]` (línea 77) insertar:
```
[node name="BtnCopiar" type="Button" parent="Margen/Fila"]
unique_name_in_owner = true
layout_mode = 2
text = "Copiar"
```
Al final del archivo (tras el nodo `BtnEliminar`) insertar:
```
[node name="TemporizadorCopiar" type="Timer" parent="."]
unique_name_in_owner = true
wait_time = 1.5
one_shot = true
```
(Indentación a columna 0, igual que el resto del `.tscn`.)

**`scripts/list_item.gd`** — añadir señal tras `signal recomprobar_pedido`:
```gdscript
signal copiar_pedido(url: String)
```
En `_ready()`, añadir tras las conexiones existentes:
```gdscript
	%BtnCopiar.pressed.connect(_on_copiar)
	%TemporizadorCopiar.timeout.connect(_restaurar_boton_copiar)
```
Añadir handlers al final del archivo (tras `_pressed()`):
```gdscript
func _on_copiar() -> void:
	copiar_pedido.emit(url)
	%BtnCopiar.text = "¡Copiada!"
	%BtnCopiar.disabled = true
	%TemporizadorCopiar.start()


func _restaurar_boton_copiar() -> void:
	%BtnCopiar.text = "Copiar"
	%BtnCopiar.disabled = false
```

**`scripts/main.gd`** — en `_mostrar_lista`, tras la conexión `recomprobar_pedido`:
```gdscript
		item.copiar_pedido.connect(_on_copiar_pedido.bind(item))
```
Añadir handler (junto a los demás `_on_*_pedido`):
```gdscript
func _on_copiar_pedido(item: Button) -> void:
	if not is_instance_valid(item):
		return
	DisplayServer.clipboard_set(item.url)
```

- [ ] **Step 4: Ejecutar el test para verificar que pasa**

```powershell
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_list_item.gd 2>&1 | Select-Object -Last 3
```
Expected: `TESTS OK`, EXIT 0, 16 checks.

- [ ] **Step 5: Commit**

```powershell
git add scenes/ListItem.tscn scripts/list_item.gd scripts/main.gd tests/test_list_item.gd && git commit -m "feat: botón copiar URL en cada fila (#16)" -q
```

---

### Task 4: Barra de progreso y aviso al terminar (#15)

**Files:**
- Modify: `scenes/Main.tscn:92-96` (nodo `%BarraProgreso` tras `Progreso`)
- Modify: `scripts/main.gd:19` (`@onready`), `scripts/main.gd:203-218` (`_comprobar_visibles`), `scripts/main.gd:231-249` (`_on_item_terminado`)
- Test: `tests/test_main_barra.gd`

**Interfaces:**
- Consumes: `main._hechos`/`_total`; `%Progreso`.
- Produces: `%BarraProgreso` (ProgressBar, `visible = false`, `show_percentage = false`, `size_flags_horizontal = 3`); `barra_progreso` en `main`; `_actualizar_barra(hechos, total)` (`max_value = maxi(total, 1)`, `value = hechos`); `_marcar_barra_final(caidos)` (override `fill` StyleBoxFlat verde si `caidos == 0`, rojo si no); `_comprobar_visibles` oculta la barra con `_total == 0` y la muestra/resetea al arrancar; `_on_item_terminado` avanza la barra y la colorea al terminar.

- [ ] **Step 1: Escribir el test que falla**

**`tests/test_main_barra.gd`** — insertar tras el bloque de `_persistir_recompra` (después de `item.free()`) y antes de `_cerrar()`:
```gdscript
	_check(not main.get_node("%BarraProgreso").visible, "la barra de progreso nace oculta")
	main_script._actualizar_barra(3, 5)
	_check(main.get_node("%BarraProgreso").value == 3, "la barra refleja los enlaces comprobados")
	_check(main.get_node("%BarraProgreso").max_value == 5, "la barra usa el total de enlaces como máximo")
	main_script._marcar_barra_final(0)
	var verde: StyleBoxFlat = main.get_node("%BarraProgreso").get_theme_stylebox("fill")
	_check(verde.bg_color.is_equal_approx(Color(0.35, 0.85, 0.45, 1)), "con 0 caídos la barra se pone verde")
	main_script._marcar_barra_final(2)
	var rojo: StyleBoxFlat = main.get_node("%BarraProgreso").get_theme_stylebox("fill")
	_check(rojo.bg_color.is_equal_approx(Color(0.95, 0.35, 0.35, 1)), "con caídos la barra se pone roja")
	for hijo in main.get_node("%ListaContenedor").get_children():
		hijo.visible = false
	main_script._comprobar_visibles()
	_check(not main.get_node("%BarraProgreso").visible, "sin enlaces visibles la barra se oculta")
	_check(main.get_node("%Progreso").text == "Nada que comprobar", "sin enlaces visibles se muestra el aviso")
```

- [ ] **Step 2: Ejecutar el test para verificar que falla**

```powershell
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd 2>&1 | Select-Object -Last 3
```
Expected: RED — `Invalid node ... '%BarraProgreso'` y métodos `_actualizar_barra`/`_marcar_barra_final` inexistentes.

- [ ] **Step 3: Implementación mínima**

**`scenes/Main.tscn`** — tras el nodo `Progreso` (líneas 92-96) insertar:
```
[node name="BarraProgreso" type="ProgressBar" parent="ColumnaApp/Margen/Columna/BarraAcciones"]
unique_name_in_owner = true
custom_minimum_size = Vector2(160, 0)
layout_mode = 2
size_flags_horizontal = 3
value = 0
visible = false
show_percentage = false
```

**`scripts/main.gd`** — tras `@onready var version_label: Label = %Version` añadir:
```gdscript
@onready var barra_progreso: ProgressBar = %BarraProgreso
```
Añadir helpers (entre `_comprobar_visibles` y `_lanzar_siguiente`):
```gdscript
func _actualizar_barra(hechos: int, total: int) -> void:
	%BarraProgreso.max_value = maxi(total, 1)
	%BarraProgreso.value = hechos


func _marcar_barra_final(caidos: int) -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.35, 0.85, 0.45, 1) if caidos == 0 else Color(0.95, 0.35, 0.35, 1)
	%BarraProgreso.add_theme_stylebox_override("fill", estilo)
```
Sustituir `_comprobar_visibles` (líneas 203-218):
```gdscript
func _comprobar_visibles() -> void:
	_cola.clear()
	for hijo in lista.get_children():
		if hijo.visible:
			_cola.append(hijo)

	_total = _cola.size()
	_hechos = 0
	_en_vuelo = 0
	if _total == 0:
		%BarraProgreso.visible = false
		progreso.text = "Nada que comprobar"
		return

	%BotonComprobar.disabled = true
	%BarraProgreso.visible = true
	%BarraProgreso.remove_theme_stylebox_override("fill")
	_actualizar_barra(0, _total)
	progreso.text = "Comprobando 0/%d…" % _total
	_lanzar_siguiente()
```
En `_on_item_terminado`, insertar justo antes de `progreso.text = "Comprobando %d/%d…"`:
```gdscript
	_actualizar_barra(_hechos, _total)
```
Y tras calcular `caidos` (antes de fijar `progreso.text = "Listo: …"`):
```gdscript
	_marcar_barra_final(caidos)
```

- [ ] **Step 4: Ejecutar el test para verificar que pasa**

```powershell
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd 2>&1 | Select-Object -Last 3
```
Expected: `TESTS OK`, EXIT 0, 18 checks.

- [ ] **Step 5: Commit**

```powershell
git add scenes/Main.tscn scripts/main.gd tests/test_main_barra.gd && git commit -m "feat: barra de progreso y aviso al terminar el escaneo (#15)" -q
```

---

### Task 5: Batería completa y smoke

**Files:**
- N/A (verificación; sin cambios de código)

**Interfaces:**
- Consumes: resultado de todas las tareas.

- [ ] **Step 1: Ejecutar la batería completa (8 suites)**

```powershell
$motor = "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe"
$tests = @("test_config_store.gd","test_estado_store.gd","test_gestor_contadores.gd","test_gestor_imagenes.gd","test_link_checker_timeout.gd","test_list_item.gd","test_main_barra.gd","test_preferencias.gd")
foreach ($t in $tests) { & $motor --headless --path "K:\gestor-de-enlaces" --script ("res://tests/" + $t) 2>&1 | Select-String -Pattern "TESTS (OK|FALLIDOS)|Parse Error|SCRIPT ERROR" }
```
Expected: `TESTS OK` en las 8 líneas de salida. Conteos esperados para las suites modificadas: `test_estado_store.gd` 8, `test_link_checker_timeout.gd` 4, `test_list_item.gd` 16, `test_main_barra.gd` 18 (las no modificadas mantienen su conteo actual).

- [ ] **Step 2: Smoke de scripts y escena principal**

```powershell
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://scripts/main.gd --check-only 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://scripts/list_item.gd --check-only 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" res://scenes/Main.tscn --quit-after 60 2>&1 | Select-String -Pattern "Parse Error|SCRIPT ERROR|ERROR"
```
Expected: `--check-only` sin errores; smoke de `Main.tscn` sin `Parse Error|SCRIPT ERROR|ERROR`, EXIT 0.

- [ ] **Step 3: Regenerar/versionar sidecars `.uid` si el editor pas genera alguno**

```powershell
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --editor --quit 2>&1 | Select-Object -Last 2
git status --porcelain
```
Expected: no se crean archivos nuevos (en esta feature solo se modifican archivos existentes). Si `git status` muestra `.uid` nuevos unexpected, versionarlos añadiéndolos a un commit `chore: sidecars .uid`. Si la batería y el smoke están limpios y no hay cambios pendientes → **no commit** en esta tarea.

- [ ] **Step 4: Reportar resultado**

Reportar: suites `TESTS OK` con conteos, smoke EXIT 0, estado de `git status` (solo los commits de Task 1-4 en el log sobre `HEAD`).