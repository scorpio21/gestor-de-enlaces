# Disponibilidad de enlaces — auto-escaneo, fecha de última comprobación e historial — Plan de implementación

> **Para trabajadores agente:** SUB-SKILL REQUERIDO: usar superpowers:subagent-driven-development (recomendado) o superpowers:executing-plans para implementar este plan tarea a tarea. Los pasos usan sintaxis de casilla (`- [ ]`) para seguimiento.

**Meta:** Auto-escaneo configurable, fecha de última comprobación visible y ordenable, e historial de disponibilidad por enlace (#8, #9, #10).

**Arquitectura:** Incremento sobre los stores existentes: `estado_store.gd` guarda el historial en un campo `historial` dentro de `user://estados.json` (cap 50, anti-ruido); `config_store.gd` añade `auto_abrir`/`intervalo`; `main.gd` orquesta selector de orden, Timer de auto-escaneo y el diálogo de historial. Sin tocar `data.json`.

**Tech stack:** Godot 4.7.2 (GDScript), tests `extends SceneTree` con harness `print("  OK: ...")` + `quit(0/1)`, shell **pwsh**.

## Restricciones globales

- Motor: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces"` (pwsh; usar comillas simples si hay backticks — no hacen falta aquí).
- Sin `class_name` en **código nuevo** (usar `preload`). Archivos preexistentes con `class_name` (p. ej. `estado_store.gd`) no se renombran.
- Tabs para indentar; sin comentarios de código; UI en español; textos exactos de la spec.
- `estado_store.gd` sigue siendo preexistente con `class_name EstadoStore`: no quitarle esa línea.
- Los tests NO hacen red (headless); el auto-escaneo jamás se dispara en headless (`DisplayServer.get_name() == "headless"`).
- Firma vieja compatible: `config_store.guardar(paralelismo, timeout)` sigue funcionando (defaults `auto_abrir := true`, `intervalo := 0`).
- Al terminar la batería, commitear también los sidecars `.gd.uid`/`.uid` que Godot genere para archivos nuevos.
- Convención de commits: conventional (`feat(...)`, `test(...)`).

---

### Tarea 1: Historial de disponibilidad en el store de estados (#10)

**Archivos:**
- Modificar: `scripts/estado_store.gd`
- Test: `tests/test_estado_store.gd`

**Interfaces:**
- Consume: (ninguna)
- Produce: `LIMITE_HISTORIAL := 50`; `guardar_estado(url: String, valido: bool, mensaje: String, codigo := 0) -> bool` (con historial); `historial_de(url: String) -> Array`; `historial` de no existir en entrada vieja se trata como `[]`.

- [ ] **Paso 1: Escribir los tests que fallan**

Añadir a `tests/test_estado_store.gd` en `_initialize()` tras el `_check(renombrar_misma_url(), ...)`:

```gdscript
	_check(guardar_crea_historial(), "guardar_estado() crea el historial con la primera comprobación")
	_check(historial_nuevos_primero(), "guardar_estado() añade los cambios siempre al principio")
	_check(entrada_identica_no_duplica(), "una comprobación idéntica a la última no duplica el historial")
	_check(fecha_cabecera_se_actualiza(), "fecha de cabecera se actualiza aunque la comprobación sea idéntica")
	_check(historial_truncado_50(), "el historial se trunca al límite de 50 entradas")
	_check(historial_de_desconocida(), "historial_de() devuelve array vacío para URL desconocida")
	_check(historial_de_sin_campo(), "historial_de() devuelve array vacío para una entrada antigua sin historial")
	_check(borrar_estado_limpia_historial(), "borrar_estado() elimina también el historial")
```

Añadir las funciones de apoyo al final del archivo (antes de `_check`):

```gdscript
func guardar_crea_historial() -> bool:
	var store := EstadoStore.new(BASE)
	if not store.guardar_estado("https://hist.com", true, "OK (200)", 200):
		return false
	var e: Dictionary = store.cargar()["estados"].get("https://hist.com", {})
	var h: Array = e.get("historial", [])
	return h.size() == 1 and int(h[0].get("fecha", 0)) > 0 \
		and h[0].get("valido") == true and h[0].get("codigo") == 200


func historial_nuevos_primero() -> bool:
	var store := EstadoStore.new(BASE)
	store.guardar_estado("https://hist.com", true, "OK (200)", 200)
	store.guardar_estado("https://hist.com", false, "No existe (404)", 404)
	var h: Array = store.cargar()["estados"]["https://hist.com"]["historial"]
	return h.size() == 2 and h[0].get("codigo") == 404 and h[1].get("codigo") == 200


func entrada_identica_no_duplica() -> bool:
	var store := EstadoStore.new(BASE)
	store.guardar_estado("https://hist.com", false, "No existe (404)", 404)
	store.guardar_estado("https://hist.com", false, "No existe (404)", 404)
	var e: Dictionary = store.cargar()["estados"]["https://hist.com"]
	return int(e.get("historial", []).size()) == 1


func fecha_cabecera_se_actualiza() -> bool:
	var store := EstadoStore.new(BASE)
	store.guardar_estado("https://hist.com", false, "No existe (404)", 404)
	var f1 := int(store.cargar()["estados"]["https://hist.com"].get("fecha", 0))
	store.guardar_estado("https://hist.com", false, "No existe (404)", 404)
	var f2 := int(store.cargar()["estados"]["https://hist.com"].get("fecha", 0))
	return f2 >= f1 and f2 > 0


func historial_truncado_50() -> bool:
	var store := EstadoStore.new(BASE)
	for i in range(55):
		store.guardar_estado("https://hist.com", true, "OK (200)", 100 + i)
	var h: Array = store.cargar()["estados"]["https://hist.com"]["historial"]
	return h.size() == 50 and h[0].get("codigo") == 154


func historial_de_desconocida() -> bool:
	return EstadoStore.new(BASE).historial_de("https://fantasma.com") == []


func historial_de_sin_campo() -> bool:
	var store := EstadoStore.new(BASE)
	FileAccess.open(BASE + "/estados.json", FileAccess.WRITE).store_string(
		'{"https://vieja.com": {"valido": true, "mensaje": "OK", "codigo": 200, "fecha": 1}}'
	)
	return store.historial_de("https://vieja.com") == []


func borrar_estado_limpia_historial() -> bool:
	var store := EstadoStore.new(BASE)
	store.guardar_estado("https://hist.com", true, "OK (200)", 200)
	store.borrar_estado("https://hist.com")
	return store.cargar()["estados"] == {}
```

- [ ] **Paso 2: Ejecutar el test y verificar que falla**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_estado_store.gd`
Esperado: `TESTS FALLIDOS: 8` (aparecen `FALLO:` para los 8 nuevos).

- [ ] **Paso 3: Implementar la funcionalidad mínima**

En `scripts/estado_store.gd`: añadir la constante y reemplazar `guardar_estado`; añadir `historial_de` y el comparador.

```gdscript
const LIMITE_HISTORIAL := 50
```

Reemplazar `guardar_estado` (líneas 18-26 actuales):

```gdscript
func guardar_estado(url: String, valido: bool, mensaje: String, codigo := 0) -> bool:
	var estados := _leer_estados()
	var ahora := int(Time.get_unix_time_from_system())
	var previa: Dictionary = estados.get(url, {})
	var hist: Variant = previa.get("historial", [])
	var historial: Array = hist if typeof(hist) == TYPE_ARRAY else []
	var nuevo := {"fecha": ahora, "valido": valido, "mensaje": mensaje, "codigo": codigo}
	if historial.is_empty() or not _estados_iguales(historial[0], nuevo):
		historial.push_front(nuevo)
		if historial.size() > LIMITE_HISTORIAL:
			historial.resize(LIMITE_HISTORIAL)
	estados[url] = {
		"valido": valido,
		"mensaje": mensaje,
		"codigo": codigo,
		"fecha": ahora,
		"historial": historial,
	}
	return _escribir_json(_ruta("estados.json"), estados)


func historial_de(url: String) -> Array:
	var estados := _leer_estados()
	var e: Dictionary = estados.get(url, {})
	var h: Variant = e.get("historial", [])
	return h if typeof(h) == TYPE_ARRAY else []


func _estados_iguales(a: Dictionary, b: Dictionary) -> bool:
	return a.get("valido") == b.get("valido") \
		and a.get("mensaje") == b.get("mensaje") \
		and a.get("codigo") == b.get("codigo")
```

- [ ] **Paso 4: Ejecutar el test y verificar que pasa**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_estado_store.gd`
Esperado: `TESTS OK` (20 checks).

- [ ] **Paso 5: Commit**

```bash
git add scripts/estado_store.gd tests/test_estado_store.gd
git commit -m "feat(estado): historial de disponibilidad por URL con anti-ruido y cap 50 (#10)"
```

---

### Tarea 2: Ajustes de auto-escaneo en configuración y Preferencias (#8)

**Archivos:**
- Modificar: `scripts/config_store.gd`, `scenes/Preferencias.tscn`, `scripts/preferencias.gd`
- Test: `tests/test_config_store.gd`, `tests/test_preferencias.gd`

**Interfaces:**
- Consume: (ninguna)
- Produce:
  - `config_store.gd`: `AUTO_ABRIR_DEFAULT := true`, `INTERVALO_DEFAULT := 0`, `INTERVALOS_VALIDOS := [0, 15, 30, 60]`; `cargar() -> Dictionary` con claves `paralelismo`, `timeout`, `auto_abrir: bool`, `intervalo: int`; `guardar(paralelismo: int, timeout: float, auto_abrir := AUTO_ABRIR_DEFAULT, intervalo := INTERVALO_DEFAULT) -> bool`.
  - `preferencias.gd`: `signal aplicado(paralelismo: int, timeout: float, auto_abrir: bool, intervalo: int)`; `abrir(paralelismo: int, timeout: float, auto_abrir := true, intervalo := 0) -> void`.

- [ ] **Paso 1: Escribir los tests que fallan**

**test_config_store.gd** — sustituir el bloque `_check(...)` de `_initialize()`:

```gdscript
	_check(cargar_vacio(), "sin fichero devuelve defaults")
	_check(config_rota_no_rompe(), "JSON roto devuelve defaults")
	_check(clamp_fuera_de_rango(), "valores fuera de rango se clampean")
	_check(tipos_incorrectos(), "tipos incorrectos devuelven defaults")
	_check(guardar_y_recuperar(), "guardar() persiste y cargar() lo recupera")
	_check(guardar_y_recuperar_auto(), "guardar() persiste auto_abrir e intervalo")
	_check(intervalo_invalido_normaliza(), "intervalo no válido se normaliza a 0")
	_check(auto_invalido_default(), "auto_abrir no booleano vuelve al default true")
	_check(guardar_defaults_auto(), "guardar() sin auto_abrir/intervalo persiste los defaults")
```

Añadir las funciones de apoyo (sustituir `guardar_y_recuperar` actual por las tres nuevas y ajustar `cargar_vacio`, `guardar_y_recuperar`):

```gdscript
func cargar_vacio() -> bool:
	var c := ConfigStore.new(BASE).cargar()
	return c.get("paralelismo") == 3 and is_equal_approx(c.get("timeout", -1.0), 10.0) \
		and c.get("auto_abrir") == true and c.get("intervalo") == 0


func guardar_y_recuperar() -> bool:
	var store := ConfigStore.new(BASE)
	if not store.guardar(5, 20.0):
		return false
	var c := store.cargar()
	return c.get("paralelismo") == 5 and is_equal_approx(c.get("timeout", -1.0), 20.0) \
		and c.get("auto_abrir") == true and c.get("intervalo") == 0


func guardar_y_recuperar_auto() -> bool:
	var store := ConfigStore.new(BASE)
	if not store.guardar(5, 20.0, false, 60):
		return false
	var c := store.cargar()
	return c.get("auto_abrir") == false and c.get("intervalo") == 60


func intervalo_invalido_normaliza() -> bool:
	FileAccess.open(BASE + "/config.json", FileAccess.WRITE).store_string('{"auto_abrir": true, "intervalo": 7}')
	return ConfigStore.new(BASE).cargar().get("intervalo") == 0


func auto_invalido_default() -> bool:
	FileAccess.open(BASE + "/config.json", FileAccess.WRITE).store_string('{"auto_abrir": "si", "intervalo": 30}')
	var c := ConfigStore.new(BASE).cargar()
	return c.get("auto_abrir") == true and c.get("intervalo") == 30


func guardar_defaults_auto() -> bool:
	var store := ConfigStore.new(BASE)
	store.guardar(4, 12.0)
	var c := store.cargar()
	return c.get("auto_abrir") == true and c.get("intervalo") == 0
```

`config_rota_no_rompe`, `clamp_fuera_de_rango` y `tipos_incorrectos` se repintan con el nuevo assert:

```gdscript
func config_rota_no_rompe() -> bool:
	FileAccess.open(BASE + "/config.json", FileAccess.WRITE).store_string("{no es json")
	var c := ConfigStore.new(BASE).cargar()
	return c.get("paralelismo") == 3 and is_equal_approx(c.get("timeout", -1.0), 10.0) \
		and c.get("auto_abrir") == true and c.get("intervalo") == 0


func clamp_fuera_de_rango() -> bool:
	FileAccess.open(BASE + "/config.json", FileAccess.WRITE).store_string('{"paralelismo": 99, "timeout": 0.5}')
	var c := ConfigStore.new(BASE).cargar()
	return c.get("paralelismo") == 8 and is_equal_approx(c.get("timeout", -1.0), 3.0) \
		and c.get("auto_abrir") == true and c.get("intervalo") == 0


func tipos_incorrectos() -> bool:
	FileAccess.open(BASE + "/config.json", FileAccess.WRITE).store_string('{"paralelismo": "muchos", "timeout": "lento"}')
	var c := ConfigStore.new(BASE).cargar()
	return c.get("paralelismo") == 3 and is_equal_approx(c.get("timeout", -1.0), 10.0) \
		and c.get("auto_abrir") == true and c.get("intervalo") == 0
```

NOTA: el archivo de test actual declara `guardar_y_recuperar()` solo con 2 args; el cambio de firma con defaults mantiene esa llamada válida.

**test_preferencias.gd** — sustituir `_arrancar()`:

```gdscript
func _arrancar() -> void:
	var ventana := PREF.instantiate()
	root.add_child(ventana)
	await process_frame

	ventana.aplicado.connect(func(p: int, t: float, a: bool, i: int) -> void: _aplicado = [p, t, a, i])
	ventana.abrir(5, 20.0, false, 15)
	_check(is_equal_approx(ventana.get_node("%Paralelismo").value, 5.0), "abrir precarga el paralelismo")
	_check(is_equal_approx(ventana.get_node("%Timeout").value, 20.0), "abrir precarga el timeout")
	_check(ventana.get_node("%AutoAbrir").button_pressed == false \
		and ventana.get_node("%IntervaloAuto").get_selected_id() == 15, "abrir precarga auto_abrir e intervalo")

	ventana.get_node("%BotonCancelar").pressed.emit()
	_check(_aplicado == null and not ventana.visible, "cancelar no emite aplicado y oculta")

	ventana.abrir(5, 20.0, true, 30)
	ventana.get_node("%Paralelismo").value = 7
	ventana.get_node("%Timeout").value = 15.0
	ventana.get_node("%AutoAbrir").button_pressed = true
	ventana.get_node("%IntervaloAuto").select(3)
	ventana.get_node("%BotonGuardar").pressed.emit()
	_check(_aplicado != null and _aplicado[0] == 7 and is_equal_approx(_aplicado[1], 15.0), "guardar emite aplicado con paralelismo y timeout")
	_check(_aplicado != null and _aplicado[2] == true and _aplicado[3] == 60, "guardar emite aplicado con auto_abrir e intervalo")

	ventana.free()
	_cerrar()
```

- [ ] **Paso 2: Ejecutar los tests y verificar que fallan**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_config_store.gd`
Esperado: `TESTS FALLIDOS: 4`.
Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_preferencias.gd`
Esperado: `TESTS FALLIDOS`. (Paso 2 provisional: test_config_store ya valida; preferencias puede fallar por el nodo `%AutoAbrir` ausente.)

- [ ] **Paso 3: Implementar la funcionalidad mínima**

**config_store.gd** — constantes nuevas tras `TIMEOUT_MAX` (línea 8):

```gdscript
const AUTO_ABRIR_DEFAULT := true
const INTERVALO_DEFAULT := 0
const INTERVALOS_VALIDOS := [0, 15, 30, 60]
```

Reemplazar `cargar()` y `guardar()` (líneas 17-32):

```gdscript
func cargar() -> Dictionary:
	var v: Variant = _leer_json(_ruta("config.json"))
	if typeof(v) != TYPE_DICTIONARY:
		return {
			"paralelismo": PARALELO_DEFAULT,
			"timeout": TIMEOUT_DEFAULT,
			"auto_abrir": AUTO_ABRIR_DEFAULT,
			"intervalo": INTERVALO_DEFAULT,
		}
	return {
		"paralelismo": _paralelismo_ok(v.get("paralelismo", PARALELO_DEFAULT)),
		"timeout": _timeout_ok(v.get("timeout", TIMEOUT_DEFAULT)),
		"auto_abrir": _auto_abrir_ok(v.get("auto_abrir", AUTO_ABRIR_DEFAULT)),
		"intervalo": _intervalo_ok(v.get("intervalo", INTERVALO_DEFAULT)),
	}


func guardar(paralelismo: int, timeout: float, auto_abrir := AUTO_ABRIR_DEFAULT, intervalo := INTERVALO_DEFAULT) -> bool:
	var dato := {
		"paralelismo": clampi(int(paralelismo), PARALELO_MIN, PARALELO_MAX),
		"timeout": clampf(float(timeout), TIMEOUT_MIN, TIMEOUT_MAX),
		"auto_abrir": typeof(auto_abrir) == TYPE_BOOL and bool(auto_abrir),
		"intervalo": _intervalo_ok(intervalo),
	}
	return _escribir_json(_ruta("config.json"), dato)


func _auto_abrir_ok(v: Variant) -> bool:
	return v if typeof(v) == TYPE_BOOL else AUTO_ABRIR_DEFAULT


func _intervalo_ok(v: Variant) -> int:
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		return INTERVALO_DEFAULT
	var n := int(v)
	return n if INTERVALOS_VALIDOS.has(n) else INTERVALO_DEFAULT
```

**scenes/Preferencias.tscn** — añadir tras el nodo `Timeout` (línea 60) y antes de `Error`, y reemplazar `size` del root:

```tscn
[node name="EtiquetaAuto" type="Label" parent="Margen/Columna"]
layout_mode = 2
text = "Auto-escaneo"

[node name="AutoAbrir" type="CheckBox" parent="Margen/Columna"]
unique_name_in_owner = true
layout_mode = 2
text = "Comprobar enlaces al abrir"

[node name="EtiquetaIntervalo" type="Label" parent="Margen/Columna"]
layout_mode = 2
text = "Comprobar cada"

[node name="IntervaloAuto" type="OptionButton" parent="Margen/Columna"]
unique_name_in_owner = true
layout_mode = 2
item_count = 4
popup/item_0/text = "Desactivado"
popup/item_0/id = 0
popup/item_1/text = "Cada 15 minutos"
popup/item_1/id = 15
popup/item_2/text = "Cada 30 minutos"
popup/item_2/id = 30
popup/item_3/text = "Cada 1 hora"
popup/item_3/id = 60
```

Reemplazar en el root `size = Vector2i(400, 260)` por `size = Vector2i(400, 340)`.

**scripts/preferencias.gd** — reemplazar el archivo completo:

```gdscript
extends Window

signal aplicado(paralelismo: int, timeout: float, auto_abrir: bool, intervalo: int)

@onready var paralelismo_spin: SpinBox = %Paralelismo
@onready var timeout_spin: SpinBox = %Timeout
@onready var auto_abrir_box: CheckBox = %AutoAbrir
@onready var intervalo_auto: OptionButton = %IntervaloAuto


func _ready() -> void:
	close_requested.connect(hide)
	%BotonCancelar.pressed.connect(hide)
	%BotonGuardar.pressed.connect(_on_guardar)


func abrir(paralelismo: int, timeout: float, auto_abrir := true, intervalo := 0) -> void:
	paralelismo_spin.value = paralelismo
	timeout_spin.value = timeout
	auto_abrir_box.button_pressed = auto_abrir
	_seleccionar_intervalo(intervalo)
	popup_centered()


func _seleccionar_intervalo(minutos: int) -> void:
	for i in intervalo_auto.get_item_count():
		if intervalo_auto.get_item_id(i) == minutos:
			intervalo_auto.select(i)
			return
	intervalo_auto.select(0)


func _on_guardar() -> void:
	aplicado.emit(
		int(paralelismo_spin.value),
		float(timeout_spin.value),
		auto_abrir_box.button_pressed,
		intervalo_auto.get_item_id(intervalo_auto.get_selected_index())
	)
	hide()
```

- [ ] **Paso 4: Ejecutar los tests y verificar que pasan**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_config_store.gd`
Esperado: `TESTS OK` (9 checks).
Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_preferencias.gd`
Esperado: `TESTS OK` (6 checks).

- [ ] **Paso 5: Commit**

```bash
git add scripts/config_store.gd scenes/Preferencias.tscn scripts/preferencias.gd tests/test_config_store.gd tests/test_preferencias.gd
git commit -m "feat(preferencias): comprobar al abrir e intervalo de auto-escaneo (#8)"
```

---

### Tarea 3: Fecha visible en la fila y menú de historial (#9)

**Archivos:**
- Modificar: `scripts/list_item.gd`, `scenes/ListItem.tscn`
- Test: `tests/test_list_item.gd`

**Interfaces:**
- Consume: (ninguna)
- Produce: señal `historial_pedido` (sin argumentos); ids de menú contextual: 0 Editar…, 1 Volver a comprobar, 2 Copiar URL, 3 Historial…, 4 Eliminar; nodo `%FechaLabel` muestre `formatear_fecha(fecha)` o «Sin comprobar».

- [ ] **Paso 1: Escribir los tests que fallan**

**test_list_item.gd** — cambios:

En `_arrancar()`, tras el bloque de `detallado`/`sin_codigo`/`sin_estado` (final del bloque de tooltips) añadir:

```gdscript
	var fecha_label := _crear_item()
	fecha_label.setup("Nom", "Desc", "https://ejemplo.com/fl")
	root.add_child(fecha_label)
	await process_frame
	_check(fecha_label.get_node("%FechaLabel").text == "Sin comprobar", "la fila sin comprobar muestra 'Sin comprobar' en FechaLabel")

	var fecha_formateada := _crear_item()
	fecha_formateada.setup("Nom", "Desc", "https://ejemplo.com/ff")
	fecha_formateada.aplicar_estado(true, "OK (200)", 200, 1000000000)
	root.add_child(fecha_formateada)
	await process_frame
	_check(fecha_formateada.get_node("%FechaLabel").text == ListItemScript.formatear_fecha(1000000000), "la fila con fecha muestra la fecha formateada en FechaLabel")
```

Sustituir las dos primeras líneas del bloque del menú (líneas ~74-80): la variable emisora y conexiones ganan `historial_pedido`:

```gdscript
	var item := _crear_item()
	item.setup("Nom", "Desc", "https://ejemplo.com/menu")
	var emitido: Array = []
	item.editar_pedido.connect(func() -> void: emitido.append("editar"))
	item.recomprobar_pedido.connect(func() -> void: emitido.append("recomprobar"))
	item.copiar_pedido.connect(func(u: String) -> void: emitido.append(["copiar", u]))
	item.historial_pedido.connect(func() -> void: emitido.append("historial"))
	item.eliminar_pedido.connect(func() -> void: emitido.append("eliminar"))
```

Y tras el check del id 3 (línea ~98), añadir el id de historial y mover Eliminar a id 4:

```gdscript
	item.get_node("%MenuContexto").id_pressed.emit(3)
	_check(emitido == ["editar", "recomprobar", ["copiar", "https://ejemplo.com/menu"], "historial"], "la opción Historial emite historial_pedido")
	item.get_node("%MenuContexto").id_pressed.emit(4)
	_check(emitido == ["editar", "recomprobar", ["copiar", "https://ejemplo.com/menu"], "historial", "eliminar"], "la opción Eliminar emite eliminar_pedido")
```

Sustituir el comparador `_menu_completo` (líneas 132-134):

```gdscript
func _menu_completo(item: Control) -> bool:
	var menu: PopupMenu = item.get_node("%MenuContexto")
	return menu != null and menu.get_item_count() == 5
```

Y sustituir los textos de los dos primeros checks (líneas 26-27): `"...con 4 opciones"` → `"...con 5 opciones"` (ambas ocurrencias: caído y válido).

- [ ] **Paso 2: Ejecutar el test y verificar que falla**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_list_item.gd`
Esperado: `TESTS FALLIDOS` (varios: menú 4 vs 5, Emitir 3 eliminar, `%FechaLabel` ausente, ...).

- [ ] **Paso 3: Implementar la funcionalidad mínima**

**list_item.gd**:

Añadir la señal (línea 7 actual, tras `copiar_pedido`/`editar_pedido`):

```gdscript
signal historial_pedido
```

En `_ready()` (líneas 27-30), cambiar ids del menú:

```gdscript
	menu.add_item("Editar…", 0)
	menu.add_item("Volver a comprobar", 1)
	menu.add_item("Copiar URL", 2)
	menu.add_item("Historial…", 3)
	menu.add_item("Eliminar", 4)
```

En `setup()`, tras `%DescripcionLabel.text = descripcion`, añadir `%FechaLabel.text = "Sin comprobar"`.

En `aplicar_estado()`, tras `fecha = fecha_nueva`, añadir `_pintar_fecha()`.

En `_on_check_terminado()`, tras `fecha = int(Time.get_unix_time_from_system())`, añadir `_pintar_fecha()`.

En `_on_menu()`, actualizar el `match` (líneas 139-148):

```gdscript
func _on_menu(id: int) -> void:
	match id:
		0:
			editar_pedido.emit()
		1:
			recomprobar_pedido.emit()
		2:
			copiar_pedido.emit(url)
		3:
			historial_pedido.emit()
		4:
			eliminar_pedido.emit()
```

Añadir al final del archivo:

```gdscript
func _pintar_fecha() -> void:
	if fecha > 0:
		%FechaLabel.text = formatear_fecha(fecha)
	else:
		%FechaLabel.text = "Sin comprobar"
```

**scenes/ListItem.tscn** — insertar entre `Textos` y `EstadoLabel` (tras línea 46, antes del nodo `EstadoLabel`):

```tscn
[node name="FechaLabel" type="Label" parent="Margen/Fila"]
unique_name_in_owner = true
custom_minimum_size = Vector2(130, 0)
layout_mode = 2
mouse_filter = 2
theme_override_colors/font_color = Color(0.7, 0.7, 0.7, 1)
theme_override_font_sizes/font_size = 13
text = "Sin comprobar"
```

- [ ] **Paso 4: Ejecutar el test y verificar que pasa**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_list_item.gd`
Esperado: `TESTS OK` (24 checks: 21 previos + 2 de FechaLabel + 1 del emit de historial).

- [ ] **Paso 5: Commit**

```bash
git add scripts/list_item.gd scenes/ListItem.tscn tests/test_list_item.gd
git commit -m "feat(lista): fecha de última comprobación visible y opción Historial en fila (#9)"
```

---

### Tarea 4: Ordenación, auto-escaneo y diálogo de historial en Main (#8, #9, #10)

**Archivos:**
- Crear: `scenes/Historial.tscn`, `scripts/historial.gd`
- Modificar: `scripts/main.gd`, `scenes/Main.tscn`
- Test: `tests/test_main_barra.gd`

**Interfaces:**
- Consume: `historial_de(url) -> Array` (Tarea 1); señal `historial_pedido` y `%FechaLabel` (Tarea 3); `config_store.cargar()` con `auto_abrir`/`intervalo` (Tarea 2); `preferencias.aplicado` con 4 argumentos (Tarea 2).
- Produce:
  - `main.gd`: `%OrdenFecha` ids 0 «Sin ordenar»/1 «Más recientes»/2 «Más antiguos»; `%AutoEscaneo` (Timer); `%DialogoHistorial`; vars `_auto_abrir := true`, `_intervalo_auto := 0`; métodos `_es_headless() -> bool`, `_rearmar_auto_escaneo()`, `_iniciar_auto_escaneo()`, `_puede_auto_escanear() -> bool`, `_on_auto_timer()`, `_comparar_orden(a, b, modo) -> bool`, `_on_historial_pedido(item)`; `_aplicar_preferencias(paralelismo: int, timeout: float, auto_abrir := true, intervalo := 0)`.
  - `scenes/Historial.tscn` + `scripts/historial.gd`: `abrir(entradas: Array) -> void` (muestra «Sin historial» si vacío).

- [ ] **Paso 1: Escribir los escena/scripts y el test que falla**

Crear **scenes/Historial.tscn**:

```tscn
[gd_scene load_steps=2 format=3 uid="uid://bhistorial0001"]

[ext_resource type="Script" path="res://scripts/historial.gd" id="1_historial"]

[node name="VentanaHistorial" type="Window"]
title = "Historial de disponibilidad"
initial_position = 2
size = Vector2i(420, 300)
resizable = true
exclusive = true
visible = false
script = ExtResource("1_historial")

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

[node name="AvisoVacio" type="Label" parent="Margen/Columna"]
unique_name_in_owner = true
layout_mode = 2
text = "Sin historial"

[node name="Scroll" type="ScrollContainer" parent="Margen/Columna"]
layout_mode = 2
size_flags_vertical = 3

[node name="ListaHistorial" type="VBoxContainer" parent="Margen/Columna/Scroll"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/separation = 4
```

Crear **scripts/historial.gd**:

```gdscript
extends Window

const ListItemScript := preload("res://scripts/list_item.gd")

@onready var lista_historial: VBoxContainer = %ListaHistorial
@onready var aviso_vacio: Label = %AvisoVacio


func _ready() -> void:
	close_requested.connect(hide)


func abrir(entradas: Array) -> void:
	for hijo in lista_historial.get_children():
		hijo.queue_free()
	var filas := 0
	for e in entradas:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var fila := Label.new()
		fila.text = "%s — %s — %s" % [
			ListItemScript.formatear_fecha(int(e.get("fecha", 0))),
			"Válido" if e.get("valido") == true else "Caído",
			str(e.get("mensaje", "")),
		]
		fila.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lista_historial.add_child(fila)
		filas += 1
	aviso_vacio.visible = filas == 0
	popup_centered()
```

**test_main_barra.gd** — añadir una clase fake al inicio (junto a `_FakeStore`):

```gdscript
class _FakeHistorial extends RefCounted:
	func historial_de(_url: String) -> Array:
		return [{"fecha": 1000000000, "valido": true, "mensaje": "OK (200)", "codigo": 200}]
```

Añadir tras el bloque de `Ctrl+R` dispara la comprobación (línea ~388), antes del `Esc`:

```gdscript
	# Disponibilidad: selector de orden por fecha (#9)
	_check(main.has_node("%OrdenFecha"), "la barra tiene el selector de orden")
	var orden: OptionButton = main.get_node("%OrdenFecha")
	_check(orden.get_item_count() == 3 and orden.get_item_text(0) == "Sin ordenar" \
		and orden.get_item_text(1) == "Más recientes" and orden.get_item_text(2) == "Más antiguos", "el selector de orden ofrece las 3 opciones")

	main_script._entradas = [
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""},
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": ""},
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": ""},
	]
	main_script._estados = {
		"a.test": {"valido": true, "mensaje": "OK", "codigo": 200, "fecha": 1000},
		"b.test": {"valido": true, "mensaje": "OK", "codigo": 200, "fecha": 2000},
	}
	main_script._refrescar_vista()
	orden.select(1)
	main_script._aplicar_filtro()
	var orden_recientes: Array = []
	for hijo in main.get_node("%ListaContenedor").get_children():
		if hijo.visible:
			orden_recientes.append(hijo.url)
	_check(orden_recientes == ["https://b.test", "https://a.test", "https://c.test"], "Más recientes ordena por fecha y deja lo sin comprobar al final")

	orden.select(2)
	main_script._aplicar_filtro()
	var orden_antiguos: Array = []
	for hijo in main.get_node("%ListaContenedor").get_children():
		if hijo.visible:
			orden_antiguos.append(hijo.url)
	_check(orden_antiguos == ["https://a.test", "https://b.test", "https://c.test"], "Más antiguos invierte el orden con lo sin comprobar al final")

	orden.select(0)
	main_script._aplicar_filtro()
	var orden_natural: Array = []
	for hijo in main.get_node("%ListaContenedor").get_children():
		if hijo.visible:
			orden_natural.append(hijo.url)
	_check(orden_natural == ["https://a.test", "https://b.test", "https://c.test"], "Sin ordenar conserva el orden de inserción")

	# Disponibilidad: historial desde la fila (#10)
	main_script._estado_store = _FakeHistorial.new()
	var fila_hist: Button = main.get_node("%ListaContenedor").get_child(0)
	main_script._on_historial_pedido(fila_hist)
	_check(main.has_node("%DialogoHistorial") and main.get_node("%DialogoHistorial").visible, "el historial de la fila abre el diálogo")
	_check(main.get_node("%ListaHistorial").get_child_count() == 1, "el diálogo muestra una fila por entrada del historial")
	main.get_node("%DialogoHistorial").hide()

	# Disponibilidad: auto-escaneo desactivado en headless/intervalo 0 (#8)
	main_script._intervalo_auto = 0
	main_script._rearmar_auto_escaneo()
	_check(main.get_node("%AutoEscaneo").is_stopped(), "intervalo 0 deja el Timer detenido")
	main_script._intervalo_auto = 15
	main_script._rearmar_auto_escaneo()
	_check(main.get_node("%AutoEscaneo").is_stopped(), "en headless el intervalo no arranca el Timer")
```

- [ ] **Paso 2: Ejecutar el test y verificar que falla**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd`
Esperado: `TESTS FALLIDOS` (falta `%OrdenFecha`, `%AutoEscaneo`, `%DialogoHistorial`, `_rearmar_auto_escaneo`, orden).

- [ ] **Paso 3: Implementar la funcionalidad mínima**

**scenes/Main.tscn**:

- `load_steps=4` → `load_steps=5`; añadir `[ext_resource type="PackedScene" path="res://scenes/Historial.tscn" id="4_historial"]`.
- En `BarraAcciones`, tras el nodo `FiltroCategoria` (antes de `Progreso`, línea ~96) insertar:

```tscn
[node name="OrdenFecha" type="OptionButton" parent="ColumnaApp/Margen/Columna/BarraAcciones"]
unique_name_in_owner = true
layout_mode = 2
selected = 0
item_count = 3
popup/item_0/text = "Sin ordenar"
popup/item_0/id = 0
popup/item_1/text = "Más recientes"
popup/item_1/id = 1
popup/item_2/text = "Más antiguos"
popup/item_2/id = 2
```

- Tras la instancia de `VentanaPreferencias` (línea ~142) añadir el diálogo y el Timer:

```tscn
[node name="DialogoHistorial" parent="." instance=ExtResource("4_historial")]
unique_name_in_owner = true

[node name="AutoEscaneo" type="Timer" parent="."]
unique_name_in_owner = true
```

**scripts/main.gd**:

Añadir tres `@onready` tras `barra_progreso` (línea 25):

```gdscript
@onready var orden_fecha: OptionButton = %OrdenFecha
@onready var dialogo_historial: Window = %DialogoHistorial
@onready var timer_auto: Timer = %AutoEscaneo
```

Añadir tras `_timeout := 10.0` (línea 35):

```gdscript
var _auto_abrir := true
var _intervalo_auto := 0
```

En `_ready()`, tras el bloque del `filtro_cat` (línea 62), añadir:

```gdscript
	orden_fecha.clear()
	orden_fecha.add_item("Sin ordenar", 0)
	orden_fecha.add_item("Más recientes", 1)
	orden_fecha.add_item("Más antiguos", 2)
	orden_fecha.select(0)
	orden_fecha.item_selected.connect(func(_i: int) -> void: _aplicar_filtro())
	timer_auto.timeout.connect(_on_auto_timer)
```

En `_ready()`, sustituir la lectura de config (líneas 68-70):

```gdscript
	var cfg: Dictionary = _config_store.cargar()
	_paralelismo = clampi(int(cfg.get("paralelismo", 3)), 1, 8)
	_timeout = clampf(float(cfg.get("timeout", 10.0)), 3.0, 60.0)
	_auto_abrir = cfg.get("auto_abrir", true) == true
	_intervalo_auto = int(cfg.get("intervalo", 0))
```

En `_ready()`, tras `_actualizar_status()` (línea 76), añadir:

```gdscript
	_rearmar_auto_escaneo()
	_iniciar_auto_escaneo()
```

En `_on_utilidades_id` (línea 144), sustituir `preferencias.abrir(_paralelismo, _timeout)` por:

```gdscript
		preferencias.abrir(_paralelismo, _timeout, _auto_abrir, _intervalo_auto)
```

En `_mostrar_lista`, tras `item.editar_pedido.connect(_on_editar_pedido.bind(item))` (línea 530), añadir:

```gdscript
		item.historial_pedido.connect(_on_historial_pedido.bind(item))
```

Sustituir `_aplicar_preferencias` (líneas 693-697):

```gdscript
func _aplicar_preferencias(paralelismo: int, timeout: float, auto_abrir := true, intervalo := 0) -> void:
	_paralelismo = paralelismo
	_timeout = timeout
	_auto_abrir = auto_abrir
	_intervalo_auto = intervalo
	if not _config_store.guardar(paralelismo, timeout, auto_abrir, intervalo):
		progreso.text = "No se pudo guardar la configuración."
	_rearmar_auto_escaneo()
	if _auto_abrir and _puede_auto_escanear():
		_comprobar_visibles()
```

Sustituir `_aplicar_filtro` (líneas 664-679) para añadir la reordenación al final:

```gdscript
func _aplicar_filtro() -> void:
	var modo := filtro.get_selected_id()
	var cat_id := filtro_cat.get_selected_id()
	var clave_cat := ""
	if cat_id > 0:
		clave_cat = GestorCatalogoScript.CATEGORIAS[cat_id - 1]
	for hijo in lista.get_children():
		var visible_estado := true
		match modo:
			1:
				visible_estado = hijo.valido == true
			2:
				visible_estado = hijo.valido == false
			3:
				visible_estado = hijo.valido == null
		hijo.visible = visible_estado and (cat_id == 0 or hijo.categoria == clave_cat)

	var modo_orden := orden_fecha.get_selected_id()
	if modo_orden > 0:
		var hijos: Array = lista.get_children()
		hijos.sort_custom(func(a: Button, b: Button) -> bool:
			return _comparar_orden(a, b, modo_orden)
		)
		for hijo in hijos:
			lista.move_child(hijo, -1)
```

Añadir al final del archivo (tras `_aplicar_preferencias`):

```gdscript
func _es_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _rearmar_auto_escaneo() -> void:
	if _es_headless() or _intervalo_auto <= 0:
		timer_auto.stop()
		return
	timer_auto.wait_time = float(_intervalo_auto * 60)
	timer_auto.start()


func _iniciar_auto_escaneo() -> void:
	if _es_headless() or not _auto_abrir:
		return
	await get_tree().create_timer(0.5).timeout
	if _puede_auto_escanear():
		_comprobar_visibles()
	_rearmar_auto_escaneo()


func _puede_auto_escanear() -> bool:
	return not _es_headless() and _cola.is_empty() and _en_vuelo == 0


func _on_auto_timer() -> void:
	if _puede_auto_escanear():
		_comprobar_visibles()


func _comparar_orden(a: Button, b: Button, modo: int) -> bool:
	var fa := int(a.fecha)
	var fb := int(b.fecha)
	if fa == fb:
		return a.url < b.url
	if fa == 0:
		return false
	if fb == 0:
		return true
	return fa > fb if modo == 1 else fa < fb


func _on_historial_pedido(item: Button) -> void:
	if not is_instance_valid(item):
		return
	var clave_estado := GestorCatalogoScript.clave_unica(item.url)
	dialogo_historial.abrir(_estado_store.historial_de(clave_estado))
```

NOTA: la firma actual de `_aplicar_preferencias` es `(paralelismo: int, timeout: float)`; el cambio con defaults conserva las llamadas internas (solo conecta la señal).

- [ ] **Paso 4: Ejecutar el test y verificar que pasa**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd`
Esperado: `TESTS OK` (91 checks: 84 previos + 7 nuevos).

- [ ] **Paso 5: Verificar la batería completa y smoke**

Run cada suite (todas deben dar `TESTS OK`):

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_agregar_enlace.gd
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_config_store.gd
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_estado_store.gd
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_gestor_archivo.gd
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_gestor_catalogo.gd
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_gestor_contadores.gd
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_gestor_datos.gd
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_gestor_imagenes.gd
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_link_checker_timeout.gd
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_list_item.gd
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_preferencias.gd
```

Esperado: las 12 suites, total **294 checks** (30+9+20+15+32+8+20+19+20+24+91+6).

Smoke: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" res://scenes/Main.tscn --quit-after 90`
Esperado: sale con código 0 y sin `SCRIPT ERROR` en la salida.

- [ ] **Paso 6: Commit**

```bash
git add scripts/main.gd scenes/Main.tscn scenes/Historial.tscn scripts/historial.gd tests/test_main_barra.gd scripts/historial.gd.uid scenes/Historial.tscn.uid
git commit -m "feat(disponibilidad): selector de orden por fecha, auto-escaneo y diálogo de historial (#8, #9, #10)"
```

Si Godot generó sidecars `.uid` adicionales, inclúyelos también (p. ej. `scripts/list_item.gd.uid`, `scenes/ListItem.tscn.uid`, `scenes/Preferencias.tscn.uid` que hayan cambiado).

---

## Autoevaluación

**1. Cobertura de la spec:**
- Config auto_abrir + intervalo → Tarea 2; UI de Preferencias → Tarea 2. ✔
- FechaLabel visible y selector de orden + sort estable con «sin comprobar» al final → Tareas 3 y 4. ✔
- Historial cap 50 + anti-ruido + `historial_de` + diálogo + menú contextual → Tareas 1, 3 y 4. ✔
- Auto-escaneo solo no-headless, inicial con retardo + intervalo, respeta filtros/paralelismo, no lo dispara si escaneo en curso → Tarea 4 (guardas `_es_headless`, `_puede_auto_escanear`, `_rearmar_auto_escaneo`). ✔
- Retrocompatibilidad `estados.json` sin `historial` y `config.json` sin campos → Tareas 1 y 2 (defaults). ✔
- Escritura fallida best-effort → sin cambios (comportamiento existente). ✔
- Batería ~300 → 294 checks + smoke. ✔

**2. Placeholders:** ninguno; cada paso incluye código y comando exactos.

**3. Coherencia de tipos:** `historial_de(url) -> Array`, `limite` 50, señal `historial_pedido` sin args, ids de menú 0-4, `aplicado` 4 args, `guardar` 4 params con defaults, `_aplicar_filtro` reordena con `_comparar_orden(a, b, modo)`. `_FakeHistorial` en test reproduce el contrato de `historial_de`. ✔