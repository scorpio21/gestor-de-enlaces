# Barra de estado en Main — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Añadir una barra de estado fija al pie de la ventana principal con el número de enlaces rotos, activos y el total del catálogo, y la versión de la app (0.0.1) alineada a la derecha.

**Architecture:** El cálculo de contadores vive en un helper estático puro (`gestor_contadores.gd`, testeable headless) que recibe `_entradas` y `_estados` y devuelve `{"total", "activos", "rotos"}`. `main.gd` lo invoca en `_actualizar_status()` cuando cambian el catálogo o los estados, escribiendo los labels `%Rotos/%Activos/%Total` de la barra. La versión se lee de `project.godot` (`application/config/version`), única fuente de verdad.

**Tech Stack:** Godot 4.7 (GDScript, escenas `.tscn`), ejecución headless para tests (`--script` SceneTree + `--check-only` + smoke `--quit-after`).

## Global Constraints

- **Motor/binario headless:** `K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe` con `--headless --path "K:\gestor-de-enlaces"`. Todas las tareas corren en PowerShell (workdir `K:\gestor-de-enlaces`).
- **Contadores sobre el catálogo completo:** base + usuario, excluyendo borrados (ya filtrados en `_entradas`), independiente del filtro de estado y de la búsqueda.
- **Solo cuentan como activos/rotos** las entradas presentes en `_estados` (`valido` `true`/`false`). Las «sin comprobar» solo suman a `Total`.
- **Versión única de la verdad:** `config/version="0.0.1"` en `[application]` de `project.godot`; la barra lo muestra con prefijo `v` (`v0.0.1`) vía `ProjectSettings.get_setting("application/config/version", "0.0.1")`.
- **No tocar:** `data/data.json.bak`, `data/data2.json`, `data/servidores.json` (untracked). El label `Progreso` existente no cambia su comportamiento.
- **Idioma/texto UI en español** (labels: `Rotos`, `Activos`, `Total`). Nada de comentarios en código nuevo (repo no usa comentarios en código).
- **Tests headless (harness SceneTree fijado):** salida limpia, checks como `print("  OK: %s")`, `push_error("FALLO: ...")`, al final `TESTS OK` + `quit(0)` + `return`, o `TESTS FALLIDOS: N` + `quit(1)`.
- **Estilo de escenas:** indentación de nodos a 0 (column-0, sin TABS), replicando `scenes/Main.tscn` actual.
- **Sidecars `.uid`:** si Godot genera `*.gd.uid`, se versiona en el mismo commit; si no aparece, no es bloqueante.
- **Patrón de preload de scripts** (repo): `const XxxScript := preload("res://scripts/xxx.gd")`, sin `class_name`.

## File Structure

| Archivo | Responsabilidad | Acción |
|---|---|---|
| `scripts/gestor_contadores.gd` | Helper estático puro `contar(entradas, estados)` | Crear (Task 1) |
| `tests/test_gestor_contadores.gd` | Tests del contador | Crear (Task 1) |
| `project.godot` | `config/version="0.0.1"` en `[application]` | Modificar (Task 2) |
| `scenes/Main.tscn` | Nodo `BarraEstado` (PanelContainer) con labels | Modificar (Task 2) |
| `scripts/main.gd` | `_actualizar_status()`, version label y call-sites | Modificar (Task 2) |
| `tests/test_main_barra.gd` | Harness que instancia `Main.tscn` y verifica la barra | Crear (Task 2) |

**Interfaces (contrato entre tareas):**

- `gestor_contadores.gd`: `static func contar(entradas: Array, estados: Dictionary) -> Dictionary` devolviendo `{"total": int, "activos": int, "rotos": int}`. `estados` mapea URL → `{"valido": bool, ...}` (formato de `user://estados.json`).
- `main.gd` expone internamente `_actualizar_status() -> void` que escribe los labels únicos `%Rotos`, `%Activos`, `%Total` y `%Version` (`v` + `config/version`).

---

### Task 1: Helper puro de contadores

**Files:**
- Create: `scripts/gestor_contadores.gd`
- Create: `tests/test_gestor_contadores.gd`

**Interfaces:**
- Consumes: nada externo.
- Produces: `static func contar(entradas: Array, estados: Dictionary) -> Dictionary` con `{"total", "activos", "rotos"}` (int).

- [ ] **Step 1: Escribir los tests que fallan**

`tests/test_gestor_contadores.gd`:

```gdscript
extends SceneTree

const ContadoresScript := preload("res://scripts/gestor_contadores.gd")

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	var vacio := ContadoresScript.contar([], {})
	_check(vacio.get("total", -1) == 0, "catálogo vacío → total 0")
	_check(vacio.get("activos", -1) == 0, "catálogo vacío → activos 0")
	_check(vacio.get("rotos", -1) == 0, "catálogo vacío → rotos 0")

	var estados := {
		"https://a.com": {"valido": false, "mensaje": "No existe (404)"},
		"https://b.com": {"valido": true, "mensaje": "OK (200)"},
	}
	var entradas := [
		{"nombre": "A", "url": "https://a.com"},
		{"nombre": "B", "url": "https://b.com"},
		{"nombre": "C", "url": "https://c.com"},
		"basura",
	]
	var r := ContadoresScript.contar(entradas, estados)
	_check(r.get("total", -1) == 3, "total cuenta solo entradas con formato correcto")
	_check(r.get("activos", -1) == 1, "activos = entradas con estado valido true")
	_check(r.get("rotos", -1) == 1, "rotos = entradas con estado valido false")

	var repetida := ContadoresScript.contar([
		{"url": "https://a.com"},
		{"url": "https://a.com"},
	], estados)
	_check(repetida.get("total", -1) == 2, "dos entradas con la misma URL se cuentan dos veces")

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

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_gestor_contadores.gd 2>&1`
Expected: NO termina en `TESTS OK` — `Parse Error` por no poder preload `res://scripts/gestor_contadores.gd` (aún no existe): es el estado RED esperado.

- [ ] **Step 3: Crear el helper de contadores**

`scripts/gestor_contadores.gd`:

```gdscript
extends RefCounted


static func contar(entradas: Array, estados: Dictionary) -> Dictionary:
	var total := 0
	var activos := 0
	var rotos := 0
	for entrada in entradas:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		total += 1
		var estado: Dictionary = estados.get(str(entrada.get("url", "")), {})
		if estado.get("valido") == true:
			activos += 1
		elif estado.get("valido") == false:
			rotos += 1
	return {"total": total, "activos": activos, "rotos": rotos}
```

- [ ] **Step 4: Ejecutar y verificar que pasan (GREEN)**

Run: el mismo comando del Step 2.
Expected: `TESTS OK`, EXIT 0, 7 checks `OK`.

- [ ] **Step 5: Smoke y commit**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" res://scenes/Main.tscn --quit-after 60 2>&1`
Expected: sin `Parse Error|SCRIPT ERROR|ERROR`.

```bash
git add scripts/gestor_contadores.gd tests/test_gestor_contadores.gd tests/test_gestor_contadores.gd.uid
git commit -m "feat: helper de contadores del catálogo (total, activos, rotos)"
```

---

### Task 2: Barra de estado en Main y versión 0.0.1

**Files:**
- Modify: `project.godot` (sección `[application]`)
- Modify: `scenes/Main.tscn` (insertar `BarraEstado` tras `Margen`)
- Modify: `scripts/main.gd` (`_actualizar_status()`, `%Version`, call-sites)
- Create: `tests/test_main_barra.gd`

**Interfaces:**
- Consumes: `ContadoresScript.contar(entradas, estados)` (Task 1).
- Produces: nodos únicos `%Rotos`, `%Activos`, `%Total`, `%Version` en `Main.tscn`; `_actualizar_status()` en `main.gd`; `ProjectSettings` con `application/config/version = "0.0.1"`.

- [ ] **Step 1: Escribir el harness que verifica la barra**

`tests/test_main_barra.gd`:

```gdscript
extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)

	await process_frame
	await process_frame

	_check(main.has_node("%Rotos"), "la barra tiene el label Rotos")
	_check(main.has_node("%Activos"), "la barra tiene el label Activos")
	_check(main.has_node("%Total"), "la barra tiene el label Total")
	_check(main.has_node("%Version"), "la barra tiene el label Version")

	if not main.has_node("%Rotos"):
		_cerrar()
		return

	_check(main.get_node("%Version").text.begins_with("v"), "la versión se muestra con prefijo v")
	_check(not main.get_node("%Rotos").text.is_empty(), "Rotos muestra un valor")
	_check(not main.get_node("%Activos").text.is_empty(), "Activos muestra un valor")
	_check(not main.get_node("%Total").text.is_empty(), "Total muestra un valor")

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

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd 2>&1`
Expected: `TESTS FALLIDOS: 4` — `has_node("%Rotos")` y los demás devuelven `false` (los nodos no existen aún en la escena): es el estado RED esperado.

- [ ] **Step 3: Añadir la versión en `project.godot`**

En la sección `[application]`, tras `config/name="GestorAO"`, añadir:

```
config/version="0.0.1"
```

- [ ] **Step 4: Añadir la barra en `scenes/Main.tscn`**

Insertar como último hijo de `ColumnaApp` (después del nodo `Margen`), al final del fichero:

```
[node name="BarraEstado" type="PanelContainer" parent="ColumnaApp"]
layout_mode = 2

[node name="Box" type="HBoxContainer" parent="ColumnaApp/BarraEstado"]
layout_mode = 2
theme_override_constants/separation = 12

[node name="Rotos" type="Label" parent="ColumnaApp/BarraEstado/Box"]
unique_name_in_owner = true
layout_mode = 2
text = "Rotos: 0"

[node name="Activos" type="Label" parent="ColumnaApp/BarraEstado/Box"]
unique_name_in_owner = true
layout_mode = 2
text = "Activos: 0"

[node name="Total" type="Label" parent="ColumnaApp/BarraEstado/Box"]
unique_name_in_owner = true
layout_mode = 2
text = "Total: 0"

[node name="Empuje" type="Control" parent="ColumnaApp/BarraEstado/Box"]
layout_mode = 2
size_flags_horizontal = 3

[node name="Version" type="Label" parent="ColumnaApp/BarraEstado/Box"]
unique_name_in_owner = true
layout_mode = 2
text = "v0.0.1"
```

- [ ] **Step 5: Integrar la lógica en `scripts/main.gd`**

Al inicio, tras `const EstadoStoreScript ...`:

```gdscript
const ContadoresScript := preload("res://scripts/gestor_contadores.gd")
```

Junto a los `@onready` existentes:

```gdscript
@onready var rotos_label: Label = %Rotos
@onready var activos_label: Label = %Activos
@onready var total_label: Label = %Total
@onready var version_label: Label = %Version
```

En `_ready()`, justo después de `_refrescar_vista()`:

```gdscript
	version_label.text = "v" + str(ProjectSettings.get_setting("application/config/version", "0.0.1"))
	_actualizar_status()
```

Añadir la función al final del fichero:

```gdscript
func _actualizar_status() -> void:
	var c: Dictionary = ContadoresScript.contar(_entradas, _estados)
	rotos_label.text = "Rotos: %d" % c.get("rotos", 0)
	activos_label.text = "Activos: %d" % c.get("activos", 0)
	total_label.text = "Total: %d" % c.get("total", 0)
```

Call-sites donde se recalcula:

- En `_on_enlace_guardado()`, tras `_refrescar_vista()` (antes de `progreso.text = ...`): añadir `_actualizar_status()`.
- En `_confirmar_borrado()`, tras `_aplicar_filtro()`: añadir `_actualizar_status()`.
- En `_on_item_terminado()`, tras la primera `_aplicar_filtro()`: añadir `_actualizar_status()`.
- En `_persistir_recompra()`, tras `_aplicar_filtro()`: añadir `_actualizar_status()`.

- [ ] **Step 6: Ejecutar y verificar que pasan (GREEN)**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd 2>&1`
Expected: `TESTS OK`, EXIT 0, 8 checks `OK`.

- [ ] **Step 7: Smoke, batería de regresión y commit**

Run:
```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://scripts/main.gd --check-only 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" res://scenes/Main.tscn --quit-after 60 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_list_item.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_gestor_imagenes.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_estado_store.gd 2>&1
```
Expected: `TESTS OK` en los tests; ningún `Parse Error|SCRIPT ERROR|ERROR`.

```bash
git add project.godot scenes/Main.tscn scripts/main.gd tests/test_main_barra.gd tests/test_main_barra.gd.uid
git commit -m "feat: barra de estado con contadores del catálogo y versión 0.0.1"
```

---

## Verificación final (toda la feature)

Run:
```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_gestor_contadores.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_list_item.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_gestor_imagenes.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_estado_store.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" res://scenes/Main.tscn --quit-after 60 2>&1
```
Expected: 5× `TESTS OK`, ningún `Parse Error|SCRIPT ERROR|ERROR`.

Criterios de aceptación del spec cubiertos: contadores sobre catálogo completo (Task 1 + `_actualizar_status`), labels y prefijo `v` + `config/version` (Task 2), puntos de actualización (Task 2 Step 5), casos límite (verificación final).