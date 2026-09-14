# Datos persistentes confiables — Implementación (#23 escritura atómica + #24 esquema versionado)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** El catálogo persiste con esquema versionado (`schema_version`) y escritura atómica con copia de seguridad restaurable desde el menú Archivo.

**Architecture:** Nuevo módulo `scripts/gestor_datos.gd` (RefCounted, API estática, sin `class_name`) que lee/escribe los archivos de catálogo en formato v1 `{"schema_version":1,"enlaces":[...]}`, migra v0 (array plano) al cargar y rota `tmp→bak→main` al guardar. `main.gd` consume ese módulo en `_cargar_datos`/`_guardar_datos` y agrega el item «Restaurar copia…» en el menú Archivo con ConfirmDialog.

**Tech Stack:** Godot 4.7.2 headless para tests (harness `SceneTree` + `_check`). GDScript puro, sin librerías externas.

**Fecha:** 2026-09-14
**Issues:** #23 (escritura atómica + restaurar copia), #24 (schema_version y chequeo en `_ready`)
**Spec:** `docs/superpowers/specs/2026-09-14-datos-persistentes-confiable-design.md` (commit `b089976`)

## Global Constraints

1. **GDScript repos:** sin `class_name`; `const XScript := preload("res://scripts/x.gd")`; tabs; sin comentarios en producción (los tests pueden tener); nombres en minúscula_con_guion; labels y mensajes en español.
2. **Harness de tests:** `extends SceneTree`; `_check(cond, nombre)` con `_fallos`; salida `  OK: <nombre>`, al final `TESTS OK` o `TESTS FALLIDOS: N`; `quit(0 if _fallos == 0 else 1)`. Convención: `print("TESTS OK")` sin literal de contador.
3. **Ejecución de un test:**
   `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/<archivo>.gd`
4. **Quirks del motor (verificados):** `--check-only` requiere `--script` (solo, se cuelga); en headless el runtime fuerza ventanas embebidas (irrelevante aquí); `DirAccess.rename_absolute(from, to)` no sobreescribe en Windows (por eso se borra `.bak` antes de rotar); `FileAccess` no renombra.
5. **Protegidos (nunca commitear/borrar):** `data/data2.json`. `data/data.json.bak` es artefacto generado por la app → se añade a `.gitignore` (`data/*.bak`, `data/*.tmp`).
6. **`data/data.json` está commiteado y hoy es v0 (array plano):** la primera ejecución con `GestorDatosScript.cargar` lo reescribe a v1. Ese archivo migrado se commitea como parte de la Task 2 (es el formato que el repo debe quedar).
7. Los `.gd.uid` nuevos generados por Godot al primer parseo **se commitean** junto al `.gd`.
8. Commit por tarea con los mensajes indicados; no mezclar cambios de tareas distintas.
9. **Batería final:** 12 suites / **269 checks**: agregar_enlace 30, config_store 5, estado_store 12, gestor_archivo 15, gestor_catalogo 32, gestor_contadores 8, **gestor_datos 19 (nuevo)**, gestor_imagenes 19, link_checker_timeout 20, list_item 21, **main_barra 84**, preferencias 4.

---

### Task 1: Módulo `scripts/gestor_datos.gd` + `tests/test_gestor_datos.gd`

**Files:**
- Create: `scripts/gestor_datos.gd`, `tests/test_gestor_datos.gd` (+ sus `.gd.uid`).

**Interfaces:**
- Produces (lo consume la Task 2): `const SCHEMA_ACTUAL := 1`; `static func version_de(ruta: String) -> int`; `static func cargar(ruta: String) -> Array`; `static func guardar(ruta: String, enlaces: Array) -> bool`; `static func hay_copia(ruta: String) -> bool`; `static func restaurar_copia(ruta: String) -> bool`. Todas reciben rutas estilo `user://…`/`res://…`.

- [ ] **Step 1: RED — escribir `tests/test_gestor_datos.gd` (19 checks)**

Rutas bajo `user://__test_gestor_datos__/` (se crea el directorio con `make_dir_recursive_absolute`). No limpiar al final (igual que el resto de suites del repo).

```gdscript
extends SceneTree

const GestorDatosScript := preload("res://scripts/gestor_datos.gd")
const BASE := "user://__test_gestor_datos__"
const RUTA := BASE + "/catalogo.json"

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	DirAccess.make_dir_recursive_absolute(BASE)

	_check(GestorDatosScript.version_de(BASE + "/no-existe.json") == -1, "version_de de un archivo inexistente es -1")

	var f_v0 := FileAccess.open(BASE + "/v0.json", FileAccess.WRITE)
	f_v0.store_string(JSON.stringify([{"nombre": "A", "url": "https://a.test"}], "\t"))
	f_v0.close()
	_check(GestorDatosScript.version_de(BASE + "/v0.json") == 0, "version_de de un array plano (v0) es 0")

	var f_v1 := FileAccess.open(BASE + "/v1.json", FileAccess.WRITE)
	f_v1.store_string(JSON.stringify({"schema_version": 1, "enlaces": [{"nombre": "B", "url": "https://b.test"}]}, "\t"))
	f_v1.close()
	_check(GestorDatosScript.version_de(BASE + "/v1.json") == 1, "version_de de un archivo v1 es 1")

	var entradas_v0 := GestorDatosScript.cargar(BASE + "/v0.json")
	_check(entradas_v0.size() == 1 and str(entradas_v0[0].get("url", "")) == "https://a.test", "cargar migra un array plano y devuelve sus entradas")
	var migrado: Variant = JSON.parse_string(FileAccess.get_file_as_string(BASE + "/v0.json"))
	_check(typeof(migrado) == TYPE_DICTIONARY and int(migrado.get("schema_version", -1)) == 1, "cargar reescribe el v0 como v1 en disco")

	var entradas_v1 := GestorDatosScript.cargar(BASE + "/v1.json")
	_check(entradas_v1.size() == 1 and str(entradas_v1[0].get("url", "")) == "https://b.test", "cargar devuelve las entradas de un v1")

	_check(GestorDatosScript.cargar(BASE + "/no-existe.json").is_empty(), "cargar de un archivo inexistente devuelve []")

	var f_raro := FileAccess.open(BASE + "/raro.json", FileAccess.WRITE)
	f_raro.store_string("{\"a\":1}")
	f_raro.close()
	_check(GestorDatosScript.cargar(BASE + "/raro.json").is_empty(), "cargar de un JSON que no es array ni v1 devuelve []")

	var texto_futuro := JSON.stringify({"schema_version": 2, "enlaces": [{"nombre": "Z"}]}, "\t")
	var f_futuro := FileAccess.open(BASE + "/futuro.json", FileAccess.WRITE)
	f_futuro.store_string(texto_futuro)
	f_futuro.close()
	_check(GestorDatosScript.cargar(BASE + "/futuro.json").is_empty(), "cargar de un esquema futuro devuelve []")
	_check(FileAccess.get_file_as_string(BASE + "/futuro.json") == texto_futuro, "cargar no modifica el archivo de esquema futuro")

	_check(GestorDatosScript.guardar(RUTA, [{"nombre": "A", "url": "https://a.test"}]), "guardar escribe el catálogo")
	var guardado: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA))
	_check(typeof(guardado) == TYPE_DICTIONARY and int(guardado.get("schema_version", -1)) == 1 and (guardado.get("enlaces", []) as Array).size() == 1, "guardar crea un JSON v1 con enlaces")

	var segundo_ok := GestorDatosScript.guardar(RUTA, [{"nombre": "A2", "url": "https://a2.test"}])
	_check(segundo_ok, "guardar rota el archivo en el segundo guardado")
	var bak_v1: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA + ".bak"))
	_check(segundo_ok and typeof(bak_v1) == TYPE_DICTIONARY and str((bak_v1.get("enlaces", []) as Array)[0].get("url", "")) == "https://a.test", "el segundo guardado deja en .bak el contenido previo")
	_check(not FileAccess.file_exists(RUTA + ".tmp"), "guardar no deja archivos temporales")

	_check(not GestorDatosScript.guardar(BASE + "/sin-carpeta/c.json", []), "guardar a una carpeta inexistente falla")

	_check(GestorDatosScript.hay_copia(RUTA), "hay_copia es true cuando existe el .bak")
	_check(GestorDatosScript.restaurar_copia(RUTA) and str(GestorDatosScript.cargar(RUTA)[0].get("url", "")) == "https://a.test", "restaurar_copia recupera el catálogo anterior desde el .bak")
	_check(not GestorDatosScript.restaurar_copia(BASE + "/no-existe.json"), "restaurar_copia sin copia falla")

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

- [ ] **Step 2: Verificar que falla (RED)**

Run:
```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_gestor_datos.gd
```
Expected: falla en el preload (`Can't open file 'res://scripts/gestor_datos.gd'`) y `TESTS FALLIDOS`. El comando es `bash` del harness (rutas entre comillas).

- [ ] **Step 3: Implementar `scripts/gestor_datos.gd`**

```gdscript
extends RefCounted

const SCHEMA_ACTUAL := 1


static func version_de(ruta: String) -> int:
	var parseado: Variant = _parsear(ruta)
	if typeof(parseado) == TYPE_ARRAY:
		return 0
	if typeof(parseado) == TYPE_DICTIONARY:
		return int(parseado.get("schema_version", -1))
	return -1


static func cargar(ruta: String) -> Array:
	var parseado: Variant = _parsear(ruta)
	if typeof(parseado) == TYPE_ARRAY:
		guardar(ruta, parseado)
		return parseado
	if typeof(parseado) == TYPE_DICTIONARY:
		if int(parseado.get("schema_version", -1)) != SCHEMA_ACTUAL:
			return []
		var enlaces: Variant = parseado.get("enlaces", [])
		if typeof(enlaces) != TYPE_ARRAY:
			return []
		return enlaces
	return []


static func guardar(ruta: String, enlaces: Array) -> bool:
	var texto := JSON.stringify({"schema_version": SCHEMA_ACTUAL, "enlaces": enlaces}, "\t")
	var abs := ProjectSettings.globalize_path(ruta)
	var abs_tmp := ProjectSettings.globalize_path(ruta + ".tmp")
	var abs_bak := ProjectSettings.globalize_path(ruta + ".bak")
	var archivo := FileAccess.open(ruta + ".tmp", FileAccess.WRITE)
	if archivo == null:
		return false
	archivo.store_string(texto)
	archivo.close()
	if FileAccess.file_exists(ruta):
		if FileAccess.file_exists(ruta + ".bak"):
			DirAccess.remove_absolute(abs_bak)
		if DirAccess.rename_absolute(abs, abs_bak) != OK:
			DirAccess.remove_absolute(abs_tmp)
			return false
	if DirAccess.rename_absolute(abs_tmp, abs) != OK:
		DirAccess.remove_absolute(abs_tmp)
		return false
	return true


static func hay_copia(ruta: String) -> bool:
	return FileAccess.file_exists(ruta + ".bak")


static func restaurar_copia(ruta: String) -> bool:
	if not hay_copia(ruta):
		return false
	var parseado: Variant = _parsear(ruta + ".bak")
	if typeof(parseado) == TYPE_ARRAY:
		return guardar(ruta, parseado)
	if typeof(parseado) == TYPE_DICTIONARY and int(parseado.get("schema_version", -1)) == SCHEMA_ACTUAL:
		return guardar(ruta, parseado.get("enlaces", []))
	return false


static func _parsear(ruta: String) -> Variant:
	if not FileAccess.file_exists(ruta):
		return null
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return null
	return JSON.parse_string(archivo.get_as_text())
```

- [ ] **Step 4: Verificar que pasa (GREEN)**

Run el mismo comando del Step 2. Expected: 19 `  OK:` y `TESTS OK`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/gestor_datos.gd tests/test_gestor_datos.gd scripts/gestor_datos.gd.uid tests/test_gestor_datos.gd.uid
git commit -m "feat: gestor_datos.gd con esquema v1, escritura atómica y copia de seguridad (#23, #24)"
```

---

### Task 2: Integración en `main.gd`, `Main.tscn` y menú «Restaurar copia…»

**Files:**
- Modify: `scripts/main.gd` (const GestorDatosScript; `_ready` connect; `_cargar_datos` línea 216-217; `_guardar_datos` 284; línea 172; eliminar `_leer_array` 272 y `_escribir_archivo` 295; `_configurar_menus` 78-84; `_on_file_id` 94-101; nuevos `_on_restaurar_copia`/`_confirmar_restaurar`).
- Modify: `scenes/Main.tscn` (nodo `%ConfirmarRestaurar`).
- Modify: `tests/test_main_barra.gd` (+2 checks en el bloque del menú).
- Modify: `.gitignore` (`data/*.bak`, `data/*.tmp`).
- Commit: `data/data.json` migrado a v1 (se reescribe en la primera ejecución).

**Interfaces:**
- Consumes: API de `GestorDatosScript` de la Task 1 (`cargar`, `guardar`, `hay_copia`, `restaurar_copia`).
- Produces: método `_on_restaurar_copia()` (sin parámetros) y `_confirmar_restaurar()` (sin parámetros) en `main.gd`; nodo `%ConfirmarRestaurar` (ConfirmationDialog).

- [ ] **Step 1: RED — añadir las 2 comprobaciones del menú a `tests/test_main_barra.gd`**

Insertar justo después del bloque «Importar/Exportar: menú y flujos (#3)» (tras `diag_exp.hide()`, ~línea 321):

```gdscript
	# Restaurar copia (#23, #24)
	var menu_file: PopupMenu = main.get_node("%File")
	var hay_restaurar := false
	for i in menu_file.get_item_count():
		if menu_file.get_item_id(i) == 4 and menu_file.get_item_text(i) == "Restaurar copia…":
			hay_restaurar = true
	_check(hay_restaurar, "Archivo > Restaurar copia… está en el menú")
	var hay_copia := FileAccess.file_exists("user://enlaces.json.bak") or FileAccess.file_exists("res://data/data.json.bak")
	main_script._on_file_id(4)
	if hay_copia:
		_check(main.has_node("%ConfirmarRestaurar") and main.get_node("%ConfirmarRestaurar").visible, "Restaurar copia… abre el diálogo de confirmación al existir copia")
		if main.has_node("%ConfirmarRestaurar"):
			main.get_node("%ConfirmarRestaurar").hide()
	else:
		_check(main.get_node("%Progreso").text == "No hay copia de seguridad disponible.", "Restaurar copia… sin copia informa en la barra")
```

- [ ] **Step 2: Verificar que falla (RED)**

Run:
```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd
```
Expected: `TESTS FALLIDOS` (el item 4 no existe y `_on_file_id(4)` no hace nada).

- [ ] **Step 3: Implementar**

**a) `scenes/Main.tscn`** — añadir tras el nodo `ConfirmarLimpieza` (~línea 133):

```gdscript
[node name="ConfirmarRestaurar" type="ConfirmationDialog" parent="."]
unique_name_in_owner = true
title = "Restaurar copia"
ok_button_text = "Restaurar"
dialog_text = "¿Restaurar el catálogo desde la copia de seguridad?"
```

**b) `scripts/main.gd`**:

- Tras la línea 11 (`const GestorArchivoScript := ...`):
```gdscript
const GestorDatosScript := preload("res://scripts/gestor_datos.gd")
```
- En `_ready()`, tras la línea 47 (`%ConfirmarLimpieza.confirmed.connect(...)`):
```gdscript
	%ConfirmarRestaurar.confirmed.connect(_confirmar_restaurar)
```
- En `_cargar_datos()` (líneas 216-217):
```gdscript
	var base := GestorDatosScript.cargar(DATA_RES)
	var usuario := GestorDatosScript.cargar(DATA_USER)
```
- Línea 172 (`for lista in [...]`):
```gdscript
	for lista in [GestorDatosScript.cargar(DATA_RES), GestorDatosScript.cargar(DATA_USER), _entradas]:
```
- `_guardar_datos()` (284-292) queda:
```gdscript
func _guardar_datos() -> bool:
	if not _persistir:
		return true
	if not GestorDatosScript.guardar(DATA_USER, _entradas):
		progreso.text = "No se pudo guardar el enlace."
		return false
	GestorDatosScript.guardar(DATA_RES, _entradas)
	return true
```
- Eliminar `_leer_array` (272-281) y `_escribir_archivo` (295-301) — quedan sin uso.
- `_configurar_menus()` (80-83), entre el separador y «Salir»:
```gdscript
	menu_file.add_item("Restaurar copia…", 4)
```
- `_on_file_id()` — añadir el caso `4`:
```gdscript
		4:
			_on_restaurar_copia()
```
- Nuevos métodos (al final de `_on_file_id` / tras `_confirmar_limpieza`):
```gdscript
func _on_restaurar_copia() -> void:
	if not GestorDatosScript.hay_copia(DATA_USER) and not GestorDatosScript.hay_copia(DATA_RES):
		progreso.text = "No hay copia de seguridad disponible."
		return
	%ConfirmarRestaurar.popup_centered()


func _confirmar_restaurar() -> void:
	var ok_rest := true
	if not GestorDatosScript.restaurar_copia(DATA_USER):
		ok_rest = false
	if not GestorDatosScript.restaurar_copia(DATA_RES):
		ok_rest = false
	if not ok_rest:
		progreso.text = "No se pudo restaurar la copia."
		return
	_cargar_datos()
	_refrescar_vista()
	_actualizar_status()
	progreso.text = "Catálogo restaurado desde la copia."
```

**c) `.gitignore`** — añadir al final:
```
data/*.bak
data/*.tmp
```

- [ ] **Step 4: Verificar (GREEN) + batería + migración de `data/data.json`**

Run:
```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd
```
Expected: 84 `  OK:` y `TESTS OK`.

Run la batería completa (los 12 archivos de `tests/`): todos `TESTS OK` y exit 0, con los recuentos de la constraint 9 (total 269). La primera ejecución de cualquier suite que instancie `Main` reescribe `res://data/data.json` a v1 y crea `data/data.json.bak`/`.tmp` (ignorados por el `.gitignore` nuevo).

Comprobar: `git status --short` debe mostrar `data/data.json` modificado (ahora v1) y NADA más.

```
Smoke:
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --path "K:\gestor-de-enlaces" res://scenes/Main.tscn --quit-after 90
```
Expected: exit 0, sin `SCRIPT ERROR`.

- [ ] **Step 5: Commit**

```bash
git add scripts/main.gd scenes/Main.tscn tests/test_main_barra.gd .gitignore data/data.json
git commit -m "feat: persistencia atómica en main y menú Archivo > Restaurar copia… (#23, #24)"
```
Asegurarse de que `data/data.json.bak` / `*.tmp` NO se agregan (ignorados). Si aparecen en `git status` tras el commit, revisar la regla de `.gitignore`.

---

## Verification (final)

Ejecutar la batería completa: **12 suites**, todos `TESTS OK`, exit 0, sumando **269 checks**:

| suite | checks |
|---|---|
| test_agregar_enlace.gd | 30 |
| test_config_store.gd | 5 |
| test_estado_store.gd | 12 |
| test_gestor_archivo.gd | 15 |
| test_gestor_catalogo.gd | 32 |
| test_gestor_contadores.gd | 8 |
| test_gestor_datos.gd | 19 |
| test_gestor_imagenes.gd | 19 |
| test_link_checker_timeout.gd | 20 |
| test_list_item.gd | 21 |
| test_main_barra.gd | 84 |
| test_preferencias.gd | 4 |

Confirmar además:
- `git status --short` limpio (salvo `data/data2.json` y `data/data.json.bak` ignorados/untracked `??` que no se deben commitear).
- Smoke de `Main.tscn` exit 0 sin errores.
- Validación de que el formato v1 del FS real: `Get-Content data/data.json | Select-Object -First 1` empieza por `{` (diccionario con `"schema_version": 1`).