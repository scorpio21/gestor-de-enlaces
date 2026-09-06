# Preferencias de escaneo (paralelismo y timeout) — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hacer configurables el número de verificaciones en paralelo y el timeout por enlace, exponerlos en un diálogo de preferencias y persistirlos en `user://config.json`.

**Architecture:** Un `config_store.gd` (RefCounted, patrón `estado_store`) lee/escribe `user://config.json` con defaults `{"paralelismo": 3, "timeout": 10.0}`. Un diálogo `Preferencias.tscn` (Window, patrón `AgregarEnlace.tscn`) con dos `SpinBox` captura los valores y emite `aplicado`. `main.gd` carga la config al arrancar, usa `_paralelismo` en `_lanzar_siguiente()` y propaga `_timeout` a cada `ListItem` → `LinkChecker` (que pasa de `const` a propiedad `timeout_s`). Los cambios se aplican desde la próxima tanda; las verificaciones en vuelo conservan su config.

**Tech Stack:** Godot 4.7 (GDScript, escenas `.tscn`), ejecución headless para tests (`--script` SceneTree + `--check-only` + smoke `--quit-after`).

## Global Constraints

- **Motor/binario headless:** `K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe` con `--headless --path "K:\gestor-de-enlaces"`. Todas las tareas corren en PowerShell (workdir `K:\gestor-de-enlaces`).
- **Persistencia:** `user://config.json`, formato `{"paralelismo": int, "timeout": float}` con tabs (`JSON.stringify(..., "\t")`, patrón `estado_store`).
- **Defaults:** paralelismo `3`, timeout `10.0`. **Rangos:** paralelismo 1–8, timeout 3–60.
- **Aplicación:** los cambios valen desde la próxima tanda de comprobación; los checkers en vuelo conservan su `timeout_s` ya capturado.
- **No tocar:** `data/data.json.bak`, `data/data2.json`, `data/servidores.json` (untracked). `MAX_REDIRECTS` y demás constantes del checker se quedan fijas.
- **Idioma/texto UI en español.** Nada de comentarios en código nuevo (repo no usa comentarios en código).
- **Tests headless (harness SceneTree fijado):** salida limpia, checks como `print("  OK: %s")`, `push_error("FALLO: ...")`, al final `TESTS OK` + `quit(0)` + `return`, o `TESTS FALLIDOS: N` + `quit(1)`.
- **Estilo de escenas:** indentación de nodos a 0 (column-0, sin TABS), replicando `scenes/Main.tscn` actual.
- **Sidecars `.uid`:** si Godot genera `*.gd.uid`, se versiona en el mismo commit; si no aparece, no es bloqueante.
- **Patrón de preload de scripts** (repo): `const XxxScript := preload("res://scripts/xxx.gd")`, sin `class_name`.
- **Bases temporales de test:** `user://__test_*__` con `DirAccess.make_dir_recursive_absolute` y limpieza al final (patrón `test_estado_store.gd`).

## File Structure

| Archivo | Responsabilidad | Acción |
|---|---|---|
| `scripts/config_store.gd` | Store de `user://config.json` (cargar/guardar, defaults y clamp) | Crear (Task 1) |
| `tests/test_config_store.gd` | Tests del store | Crear (Task 1) |
| `scripts/link_checker.gd` | `const TIMEOUT_S` → propiedad `timeout_s` | Modificar (Task 2) |
| `scripts/list_item.gd` | `configurar_timeout()` y asignarlo al checker | Modificar (Task 2) |
| `tests/test_link_checker_timeout.gd` | Tests de la propiedad `timeout_s` | Crear (Task 2) |
| `scripts/preferencias.gd` | Lógica del diálogo (signal `aplicado`) | Crear (Task 3) |
| `scenes/Preferencias.tscn` | Diálogo Window con dos `SpinBox` | Crear (Task 3) |
| `tests/test_preferencias.gd` | Tests del diálogo | Crear (Task 3) |
| `scripts/main.gd` | Cargar config, menu, `_lanzar_siguiente`, propagar timeout | Modificar (Task 4) |
| `scenes/Main.tscn` | Instancia `VentanaPreferencias` | Modificar (Task 4) |

**Interfaces (contrato entre tareas):**

- `config_store.gd`: `func _init(base := "user://") -> void`; `func cargar() -> Dictionary` → `{"paralelismo": int, "timeout": float}` (defaults `3`/`10.0`, clamp 1–8/3–60, JSON roto → defaults); `func guardar(paralelismo: int, timeout: float) -> bool`.
- `preferencias.gd` (extends Window): `signal aplicado(paralelismo: int, timeout: float)`; `func abrir(paralelismo: int, timeout: float) -> void`.
- `list_item.gd`: `func configurar_timeout(segundos: float) -> void`.
- `link_checker.gd`: `var timeout_s: float = 10.0`.
- `main.gd` expone internamente `_aplicar_preferencias(paralelismo: int, timeout: float) -> void` (conectada a la signal del diálogo).

---

### Task 1: Config store de `user://config.json`

**Files:**
- Create: `scripts/config_store.gd`
- Create: `tests/test_config_store.gd`

**Interfaces:**
- Consumes: nada externo.
- Produces: `ConfigStore.new(base)` con `cargar() -> Dictionary` y `guardar(paralelismo: int, timeout: float) -> bool`.

- [ ] **Step 1: Escribir los tests que fallan**

`tests/test_config_store.gd`:

```gdscript
extends SceneTree

const ConfigStore := preload("res://scripts/config_store.gd")
const BASE := "user://__test_config__"

var _fallos := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(BASE)
	_limpiar()
	_check(cargar_vacio(), "sin fichero devuelve defaults")
	_check(guardar_y_recuperar(), "guardar() persiste y cargar() lo recupera")
	_check(config_rota_no_rompe(), "JSON roto devuelve defaults")
	_check(clamp_fuera_de_rango(), "valores fuera de rango se clampean")
	_check(tipos_incorrectos(), "tipos incorrectos devuelven defaults")
	_limpiar()
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func cargar_vacio() -> bool:
	var c := ConfigStore.new(BASE).cargar()
	return c.get("paralelismo") == 3 and is_equal_approx(c.get("timeout", -1.0), 10.0)


func guardar_y_recuperar() -> bool:
	var store := ConfigStore.new(BASE)
	if not store.guardar(5, 20.0):
		return false
	var c := store.cargar()
	return c.get("paralelismo") == 5 and is_equal_approx(c.get("timeout", -1.0), 20.0)


func config_rota_no_rompe() -> bool:
	FileAccess.open(BASE + "/config.json", FileAccess.WRITE).store_string("{no es json")
	var c := ConfigStore.new(BASE).cargar()
	return c.get("paralelismo") == 3 and is_equal_approx(c.get("timeout", -1.0), 10.0)


func clamp_fuera_de_rango() -> bool:
	FileAccess.open(BASE + "/config.json", FileAccess.WRITE).store_string('{"paralelismo": 99, "timeout": 0.5}')
	var c := ConfigStore.new(BASE).cargar()
	return c.get("paralelismo") == 8 and is_equal_approx(c.get("timeout", -1.0), 3.0)


func tipos_incorrectos() -> bool:
	FileAccess.open(BASE + "/config.json", FileAccess.WRITE).store_string('{"paralelismo": "muchos", "timeout": "lento"}')
	var c := ConfigStore.new(BASE).cargar()
	return c.get("paralelismo") == 3 and is_equal_approx(c.get("timeout", -1.0), 10.0)


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)


func _limpiar() -> void:
	DirAccess.remove_absolute(BASE + "/config.json")
```

- [ ] **Step 2: Ejecutar y verificar que fallan (RED)**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_config_store.gd 2>&1`
Expected: NO termina en `TESTS OK` — `Parse Error` por no poder preload `res://scripts/config_store.gd` (aún no existe): es el estado RED esperado.

- [ ] **Step 3: Crear el store de configuración**

`scripts/config_store.gd`:

```gdscript
extends RefCounted

const PARALELO_DEFAULT := 3
const TIMEOUT_DEFAULT := 10.0
const PARALELO_MIN := 1
const PARALELO_MAX := 8
const TIMEOUT_MIN := 3.0
const TIMEOUT_MAX := 60.0

var _base: String


func _init(base := "user://") -> void:
	_base = base


func cargar() -> Dictionary:
	var v: Variant = _leer_json(_ruta("config.json"))
	if typeof(v) != TYPE_DICTIONARY:
		return {"paralelismo": PARALELO_DEFAULT, "timeout": TIMEOUT_DEFAULT}
	return {
		"paralelismo": _paralelismo_ok(v.get("paralelismo", PARALELO_DEFAULT)),
		"timeout": _timeout_ok(v.get("timeout", TIMEOUT_DEFAULT)),
	}


func guardar(paralelismo: int, timeout: float) -> bool:
	var dato := {
		"paralelismo": clampi(int(paralelismo), PARALELO_MIN, PARALELO_MAX),
		"timeout": clampf(float(timeout), TIMEOUT_MIN, TIMEOUT_MAX),
	}
	return _escribir_json(_ruta("config.json"), dato)


func _paralelismo_ok(v: Variant) -> int:
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		return PARALELO_DEFAULT
	return clampi(int(v), PARALELO_MIN, PARALELO_MAX)


func _timeout_ok(v: Variant) -> float:
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		return TIMEOUT_DEFAULT
	return clampf(float(v), TIMEOUT_MIN, TIMEOUT_MAX)


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


func _ruta(nombre: String) -> String:
	if _base.ends_with("://"):
		return _base + nombre
	return _base + "/" + nombre
```

- [ ] **Step 4: Ejecutar y verificar que pasan (GREEN)**

Run: el mismo comando del Step 2.
Expected: `TESTS OK`, EXIT 0, 5 checks `OK`.

- [ ] **Step 5: Smoke y commit**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://scripts/config_store.gd --check-only 2>&1`
Expected: sin `Parse Error|SCRIPT ERROR|ERROR`.

```bash
git add scripts/config_store.gd tests/test_config_store.gd tests/test_config_store.gd.uid
git commit -m "feat: config_store para user://config.json (paralelismo y timeout)"
```

---

### Task 2: Timeout del checker configurable por instancia

**Files:**
- Modify: `scripts/link_checker.gd` (`const TIMEOUT_S` → `var timeout_s`)
- Modify: `scripts/list_item.gd` (`configurar_timeout` + asignación al checker)
- Create: `tests/test_link_checker_timeout.gd`

**Interfaces:**
- Consumes: nada nuevo (list_item instancia el checker tal como hoy).
- Produces: `link_checker.gd` con `var timeout_s: float = 10.0`; `list_item.gd` con `func configurar_timeout(segundos: float) -> void`.

- [ ] **Step 1: Escribir los tests que fallan**

`tests/test_link_checker_timeout.gd`:

```gdscript
extends SceneTree

const LinkChecker := preload("res://scripts/link_checker.gd")

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	var checker := LinkChecker.new()
	_check(is_equal_approx(checker.timeout_s, 10.0), "timeout_s tiene default 10.0")
	checker.timeout_s = 25.0
	_check(is_equal_approx(checker.timeout_s, 25.0), "timeout_s es asignable")
	checker.free()
	_cerrar()


func _cerrar() -> void:
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

- [ ] **Step 2: Ejecutar y verificar que fallan (RED)**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_link_checker_timeout.gd 2>&1`
Expected: error en runtime — `timeout_s` no existe aún (`const TIMEOUT_S` es de solo lectura, la asignación `checker.timeout_s = 25.0` falla con `Invalid assignment of property "timeout_s"`). NO termina en `TESTS OK`: es el estado RED esperado.

- [ ] **Step 3: Convertir `TIMEOUT_S` en propiedad**

En `scripts/link_checker.gd:5`, reemplazar:

```gdscript
const TIMEOUT_S := 10.0
```

por:

```gdscript
var timeout_s: float = 10.0
```

En `scripts/link_checker.gd:41`, reemplazar `if _transcurrido >= TIMEOUT_S:` por `if _transcurrido >= timeout_s:`.

- [ ] **Step 4: Añadir `configurar_timeout` a `list_item.gd`**

En `scripts/list_item.gd`, junto al resto de vars (tras `var _checker: Node = null`):

```gdscript
var _timeout := 10.0
```

Añadir la función tras `mostrar_acciones`:

```gdscript
func configurar_timeout(segundos: float) -> void:
	_timeout = segundos
```

En `verificar()`, justo antes de `_checker.comprobar(url)`:

```gdscript
	_checker.timeout_s = _timeout
```

- [ ] **Step 5: Ejecutar y verificar que pasan (GREEN)**

Run: el mismo comando del Step 2.
Expected: `TESTS OK`, EXIT 0, 2 checks `OK`.

- [ ] **Step 6: Regresión y commit**

Run:
```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://scripts/link_checker.gd --check-only 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://scripts/list_item.gd --check-only 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_list_item.gd 2>&1
```
Expected: sin `Parse Error|SCRIPT ERROR|ERROR`; `test_list_item.gd` → `TESTS OK` (6).

```bash
git add scripts/link_checker.gd scripts/list_item.gd tests/test_link_checker_timeout.gd tests/test_link_checker_timeout.gd.uid
git commit -m "feat: timeout del checker configurable por instancia"
```

---

### Task 3: Diálogo de preferencias

**Files:**
- Create: `scripts/preferencias.gd`
- Create: `scenes/Preferencias.tscn`
- Create: `tests/test_preferencias.gd`

**Interfaces:**
- Consumes: nada (no usa el store directamente).
- Produces: `preferencias.gd` con `signal aplicado(paralelismo: int, timeout: float)` y `func abrir(paralelismo: int, timeout: float) -> void`; nodos únicos `%Paralelismo`, `%Timeout` (SpinBox).

- [ ] **Step 1: Escribir los tests que fallan**

`tests/test_preferencias.gd`:

```gdscript
extends SceneTree

const PREF := preload("res://scenes/Preferencias.tscn")

var _fallos := 0
var _aplicado: Variant = null


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	var ventana := PREF.instantiate()
	root.add_child(ventana)
	await process_frame

	ventana.aplicado.connect(func(p: int, t: float) -> void: _aplicado = [p, t])
	ventana.abrir(5, 20.0)
	_check(is_equal_approx(ventana.get_node("%Paralelismo").value, 5.0), "abrir precarga el paralelismo")
	_check(is_equal_approx(ventana.get_node("%Timeout").value, 20.0), "abrir precarga el timeout")

	ventana.get_node("%BotonCancelar").pressed.emit()
	_check(_aplicado == null and not ventana.visible, "cancelar no emite aplicado y oculta")

	ventana.abrir(5, 20.0)
	ventana.get_node("%Paralelismo").value = 7
	ventana.get_node("%Timeout").value = 15.0
	ventana.get_node("%BotonGuardar").pressed.emit()
	_check(_aplicado != null and _aplicado[0] == 7 and is_equal_approx(_aplicado[1], 15.0), "guardar emite aplicado con los valores")

	ventana.free()
	_cerrar()


func _cerrar() -> void:
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

- [ ] **Step 2: Ejecutar y verificar que fallan (RED)**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_preferencias.gd 2>&1`
Expected: `Parse Error` por no poder preload `res://scenes/Preferencias.tscn` (aún no existe): es el estado RED esperado.

- [ ] **Step 3: Crear el script del diálogo**

`scripts/preferencias.gd`:

```gdscript
extends Window

signal aplicado(paralelismo: int, timeout: float)

@onready var paralelismo_spin: SpinBox = %Paralelismo
@onready var timeout_spin: SpinBox = %Timeout


func _ready() -> void:
	close_requested.connect(hide)
	%BotonCancelar.pressed.connect(hide)
	%BotonGuardar.pressed.connect(_on_guardar)


func abrir(paralelismo: int, timeout: float) -> void:
	paralelismo_spin.value = paralelismo
	timeout_spin.value = timeout
	popup_centered()


func _on_guardar() -> void:
	aplicado.emit(int(paralelismo_spin.value), float(timeout_spin.value))
	hide()
```

- [ ] **Step 4: Crear la escena del diálogo**

`scenes/Preferencias.tscn` (nodos a columna 0, sin TABS):

```
[gd_scene load_steps=2 format=3 uid="uid://hpreferencias001"]

[ext_resource type="Script" path="res://scripts/preferencias.gd" id="1_preferencias"]

[node name="VentanaPreferencias" type="Window"]
title = "Preferencias"
initial_position = 2
size = Vector2i(400, 260)
unresizable = true
exclusive = true
visible = false
script = ExtResource("1_preferencias")

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

[node name="EtiquetaParalelismo" type="Label" parent="Margen/Columna"]
layout_mode = 2
text = "Verificaciones en paralelo"

[node name="Paralelismo" type="SpinBox" parent="Margen/Columna"]
unique_name_in_owner = true
layout_mode = 2
min_value = 1
max_value = 8
value = 3.0

[node name="EtiquetaTimeout" type="Label" parent="Margen/Columna"]
layout_mode = 2
text = "Timeout por enlace (segundos)"

[node name="Timeout" type="SpinBox" parent="Margen/Columna"]
unique_name_in_owner = true
layout_mode = 2
min_value = 3
max_value = 60
step = 1.0
value = 10.0
suffix = " s"

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
```

Nota: si Godot asigna otro `uid` interno a la escena al abrirla en el editor, mantener el que genere el motor; este valor es un placeholder válido.

- [ ] **Step 5: Ejecutar y verificar que pasan (GREEN)**

Run: el mismo comando del Step 2.
Expected: `TESTS OK`, EXIT 0, 4 checks `OK`.

- [ ] **Step 6: Smoke y commit**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://scripts/preferencias.gd --check-only 2>&1`
Expected: sin `Parse Error|SCRIPT ERROR|ERROR`.

```bash
git add scripts/preferencias.gd scenes/Preferencias.tscn tests/test_preferencias.gd tests/test_preferencias.gd.uid
git commit -m "feat: diálogo de preferencias de escaneo"
```

---

### Task 4: Integrar preferencias en Main

**Files:**
- Modify: `scripts/main.gd` (config, menu, `_lanzar_siguiente`, `_mostrar_lista`, `_aplicar_preferencias`)
- Modify: `scenes/Main.tscn` (instancia `VentanaPreferencias`)

**Interfaces:**
- Consumes: `ConfigStoreScript` (Task 1), `preferencias.aplicado` + `preferencias.abrir()` (Task 3), `item.configurar_timeout()` (Task 2).
- Produces: `main.gd` con `_paralelismo`/`_timeout` cargados y propagados; menú Utilidades → «Preferencias…».

- [ ] **Step 1: Cambios en `scripts/main.gd`**

**Constantes:** eliminar `const MAX_PARALELO := 3` (main.gd:6). Tras `const EstadoStoreScript...` / `const ContadoresScript...`, añadir:

```gdscript
const ConfigStoreScript := preload("res://scripts/config_store.gd")
```

**@onready:** junto a `@onready var ventana_agregar = %VentanaAgregar`, añadir:

```gdscript
@onready var preferencias: Window = %VentanaPreferencias
```

**Vars:** junto a `var _estado_store: RefCounted`, añadir:

```gdscript
var _config_store: RefCounted
var _paralelismo := 3
var _timeout := 10.0
```

**`_ready()`** (tras `_cargar_datos()`, antes de `_refrescar_vista()`):

```gdscript
	_config_store = ConfigStoreScript.new()
	var cfg: Dictionary = _config_store.cargar()
	_paralelismo = clampi(int(cfg.get("paralelismo", 3)), 1, 8)
	_timeout = clampf(float(cfg.get("timeout", 10.0)), 3.0, 60.0)
	preferencias.aplicado.connect(_aplicar_preferencias)
```

Nota: los nodes del diálogo ya están instanciados en la escena (Task 4 Step 2), por lo que `%VentanaPreferencias` está disponible en `_ready` aunque ocupe el `@onready` normal.

**Menú Utilidades** (`_configurar_menus()`):

```gdscript
	menu_util.add_item("Agregar", 0)
	menu_util.add_item("Preferencias…", 1)
```

**`_on_utilidades_id`**:

```gdscript
func _on_utilidades_id(id: int) -> void:
	if id == 0:
		ventana_agregar.abrir()
	elif id == 1:
		preferencias.abrir(_paralelismo, _timeout)
```

**`_lanzar_siguiente()`** (main.gd:209): reemplazar `while _en_vuelo < MAX_PARALELO ...` por `while _en_vuelo < _paralelismo ...`.

**`_mostrar_lista()`**: tras `item.setup(...)`, añadir:

```gdscript
		item.configurar_timeout(_timeout)
```

**Nueva función** al final del fichero (tras `_actualizar_status()`):

```gdscript
func _aplicar_preferencias(paralelismo: int, timeout: float) -> void:
	_paralelismo = paralelismo
	_timeout = timeout
	if not _config_store.guardar(paralelismo, timeout):
		progreso.text = "No se pudo guardar la configuración."
```

- [ ] **Step 2: Instanciar el diálogo en `scenes/Main.tscn`**

Añadir el `ext_resource` al inicio (junto a los existentes):

```
[ext_resource type="PackedScene" path="res://scenes/Preferencias.tscn" id="3_preferencias"]
```

Actualizar `load_steps` de la cabecera (de 3 a 4). Al final del fichero (tras `[node name="ConfirmarBorrado"...]`), añadir:

```
[node name="VentanaPreferencias" parent="." instance=ExtResource("3_preferencias")]
unique_name_in_owner = true
```

- [ ] **Step 3: Smoke y verificación manual de wiring**

Run:
```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://scripts/main.gd --check-only 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" res://scenes/Main.tscn --quit-after 60 2>&1
```
Expected: sin `Parse Error|SCRIPT ERROR|ERROR`. Verificar con un echo de los nodos (opcional) que `%VentanaPreferencias` existe tras instanciar `Main.tscn`.

- [ ] **Step 4: Batería de regresión completa**

Run:
```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_config_store.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_preferencias.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_link_checker_timeout.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_gestor_contadores.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_list_item.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_gestor_imagenes.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_estado_store.gd 2>&1
```
Expected: 8× `TESTS OK`, ningún `Parse Error|SCRIPT ERROR|ERROR`.

> Nota: `test_main_barra.gd` usa `user://__test_list_item__`/`__test_config__`/la config real del usuario solo si la guarda — no la guarda. Pero `Main.tscn` al arrancar lee `user://config.json` si existe; si el desarrollador ya ha configurado valores, los tests de la barra los cargarán sin afectarlos (el harness no los modifica).

- [ ] **Step 5: Commit**

```bash
git add scripts/main.gd scenes/Main.tscn
git commit -m "feat: integrar preferencias en main (paralelismo y timeout desde config)"
```

---

## Verificación final (toda la feature)

Run:
```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_config_store.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_preferencias.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_link_checker_timeout.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_gestor_contadores.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_list_item.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_gestor_imagenes.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_estado_store.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" res://scenes/Main.tscn --quit-after 60 2>&1
```
Expected: 8× `TESTS OK`, ningún `Parse Error|SCRIPT ERROR|ERROR`.

Criterios de aceptación del spec cubiertos: persistencia en `user://config.json` (Task 1), defaults y clamp (Task 1), timeout por instancia (Task 2), diálogo con precarga y signal `aplicado` (Task 3), paralelismo y propagación de timeout en main (Task 4), cambios desde la próxima tanda (diseño — in-flight conserva su `timeout_s`), regresión completa (Tasks 2 Step 6 y 4 Step 4).