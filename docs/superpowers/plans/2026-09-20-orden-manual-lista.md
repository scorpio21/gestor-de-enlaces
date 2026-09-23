# Orden Manual de la Lista (#6) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Permitir reordenar la lista de enlaces con "Subir"/"Bajar" desde el menú contextual de cada fila y persistir ese orden en disco.

**Architecture:** `list_item.gd` expone las señales `subir_pedido`/`bajar_pedido` y un método `fijar_estado_reorden()` para los estados del menú; `main.gd` conecta esas señales, hace el intercambio (swap) de entradas en `_entradas` por `clave_unica(url)` entre filas visibles, guarda con `_guardar_datos()` y refresca. Los estados `disabled` se calculan cada vez que se pide abrir el menú (señal `menu_solicitado`).

**Tech Stack:** Godot 4.7.2 (GDScript), SceneTree tests headless.

## Global Constraints

- Sin comentarios en el código.
- Tabs para indentar.
- UI en español.
- Con `OrdenFecha` en "Más recientes"/"Más antiguos" (`orden_fecha.get_selected_id() > 0`), Subir/Bajar deben ir deshabilitadas y `_on_mover_pedido` debe no hacer nada.
- El intercambio se hace **entre filas visibles**: se localiza la posición de una entrada con `GestorCatalogoScript.clave_unica(url)`, no por índice dentro de `_entradas`.
- Fila invisible (no está en `_filas_visibles()`) → ambas opciones deshabilitadas.
- Test binary: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/<test>.gd`
- Todo test debe imprimir `TESTS OK` y llamar `quit(0)` al pasar; si no, `TESTS FALLIDOS: N` + `quit(1)`.

---
- [x] **Task 1: `list_item.gd` — menú de 7 opciones, señales y estados**

**Files:**
- Modify: `scripts/list_item.gd`
- Test: `tests/test_list_item.gd`

**Interfaces:**
- Produces (consumidas por Task 2):
  - `signal subir_pedido` y `signal bajar_pedido`
  - `signal menu_solicitado`
  - `func fijar_estado_reorden(arriba: bool, abajo: bool) -> void`
  - menú con ids: Editar=0, Volver a comprobar=1, Copiar URL=2, Historial=3, Eliminar=4, **Subir=5, Bajar=6**

- [x] **Step 1: Write the failing test in `tests/test_list_item.gd`**

En `_arrancar()`, ampliar `_menu_completo()` para comprobar 7 opciones y que Subir/Bajar existen por su id:

```gdscript
func _menu_completo(item: Control) -> bool:
	var menu: PopupMenu = item.get_node("%MenuContexto")
	if menu == null or menu.get_item_count() != 7:
		return false
	for id in [0, 1, 2, 3, 4, 5, 6]:
		if menu.get_item_index(id) == -1:
			return false
	return true
```

Añadir, después del bloque de emisiones del menú existente (tras el `id_pressed.emit(4)` y su check, justo antes de los checks de categorías):

```gdscript
	var item_reorden := _crear_item()
	item_reorden.setup("Nom", "Desc", "https://ejemplo.com/reorden")
	var emitido_reorden: Array = []
	item_reorden.subir_pedido.connect(func() -> void: emitido_reorden.append("subir"))
	item_reorden.bajar_pedido.connect(func() -> void: emitido_reorden.append("bajar"))
	root.add_child(item_reorden)
	await process_frame

	item_reorden.get_node("%MenuContexto").id_pressed.emit(5)
	_check(emitido_reorden == ["subir"], "la opción Subir emite subir_pedido")
	item_reorden.get_node("%MenuContexto").id_pressed.emit(6)
	_check(emitido_reorden == ["subir", "bajar"], "la opción Bajar emite bajar_pedido")

	var menu_reorden: PopupMenu = item_reorden.get_node("%MenuContexto")
	menu_reorden.set_item_disabled(menu_reorden.get_item_index(5), true)
	menu_reorden.set_item_disabled(menu_reorden.get_item_index(6), true)
	item_reorden.fijar_estado_reorden(true, true)
	_check(not menu_reorden.is_item_disabled(menu_reorden.get_item_index(5)), "fijar_estado_reorden(true,true) habilita Subir")
	_check(not menu_reorden.is_item_disabled(menu_reorden.get_item_index(6)), "fijar_estado_reorden(true,true) habilita Bajar")
	item_reorden.fijar_estado_reorden(false, false)
	_check(menu_reorden.is_item_disabled(menu_reorden.get_item_index(5)), "fijar_estado_reorden(false,false) deshabilita Subir")
	_check(menu_reorden.is_item_disabled(menu_reorden.get_item_index(6)), "fijar_estado_reorden(false,false) deshabilita Bajar")
```

- [x] **Step 2: Run test to verify it fails**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_list_item.gd`
Expected: FAIL — `_menu_completo` devuelve false (solo hay 5 opciones) y `subir_pedido`/`bajar_pedido`/`fijar_estado_reorden` no existen.

- [x] **Step 3: Write minimal implementation in `scripts/list_item.gd`**

Añadir las señales (junto a las existentes, líneas 3-8):

```gdscript
signal subir_pedido
signal bajar_pedido
signal menu_solicitado
```

En `_ready()`, sustituir el bloque de construcción del menú (líneas 28-34) por:

```gdscript
func _ready() -> void:
	var menu: PopupMenu = %MenuContexto
	menu.add_item("Editar…", 0)
	menu.add_separator()
	menu.add_item("Subir", 5)
	menu.add_item("Bajar", 6)
	menu.add_separator()
	menu.add_item("Volver a comprobar", 1)
	menu.add_item("Copiar URL", 2)
	menu.add_item("Historial…", 3)
	menu.add_item("Eliminar", 4)
	menu.id_pressed.connect(_on_menu)
	gui_input.connect(_on_gui_input)
```

Añadir el método `fijar_estado_reorden` (junto a los demás públicos, tras `configurar_timeout`):

```gdscript
func fijar_estado_reorden(arriba: bool, abajo: bool) -> void:
	var menu: PopupMenu = %MenuContexto
	menu.set_item_disabled(menu.get_item_index(5), not arriba)
	menu.set_item_disabled(menu.get_item_index(6), not abajo)
```

En `_on_gui_input` (líneas 140-142), emitir `menu_solicitado` antes de `popup()`:

```gdscript
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		menu_solicitado.emit()
		%MenuContexto.popup(Rect2i(Vector2i(event.global_position), Vector2i.ZERO))
```

En `_on_menu` (líneas 145-156), añadir los casos:

```gdscript
		5:
			subir_pedido.emit()
		6:
			bajar_pedido.emit()
```

- [x] **Step 4: Run test to verify it passes**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_list_item.gd`
Expected: `TESTS OK`

- [x] **Step 5: Commit**

```bash
git add scripts/list_item.gd tests/test_list_item.gd
git commit -m "feat(reorden): menu contextual con Subir/Bajar, senales y estados (TDD)"
```

---
- [x] **Task 2: `main.gd` — conexiones de señales y helpers de visibilidad**

**Files:**
- Modify: `scripts/main.gd`
- Test: `tests/test_main_barra.gd`

**Interfaces:**
- Consumes: de Task 1 — `subir_pedido`, `bajar_pedido`, `menu_solicitado`, `fijar_estado_reorden`.
- Produces (consumidas por Task 3):
  - `func _filas_visibles() -> Array`
  - `func _indice_entrada(url: String) -> int`
  - `_on_menu_solicitado(item: Button)`, `_on_mover_pedido(item: Button, delta: int)`
  - las conexiones en `_mostrar_lista()`.

- [x] **Step 1: Write the failing test in `tests/test_main_barra.gd`**

Añadir al final de `_arrancar()` (tras los checks existentes, antes del cierre del método):

```gdscript
	main_script._persistir = false
	main_script._entradas = [
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""},
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": ""},
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": ""}
	]
	main_script._refrescar_vista()
	await process_frame

	var visibles: Array = main_script._filas_visibles()
	_check(visibles.size() == 3, "_filas_visibles devuelve las 3 filas sin filtros")

	var idx_b: int = main_script._indice_entrada("https://b.test")
	_check(idx_b == 1, "_indice_entrada localiza B en _entradas")
	var idx_inex: int = main_script._indice_entrada("https://no-existe.test")
	_check(idx_inex == -1, "_indice_entrada devuelve -1 para url ausente")

	var items_visibles: Array = visibles
	var item_a: Button = items_visibles[0]
	var item_b: Button = items_visibles[1]
	var item_c: Button = items_visibles[2]
	var menu_a: PopupMenu = item_a.get_node("%MenuContexto")
	var menu_b: PopupMenu = item_b.get_node("%MenuContexto")
	var menu_c: PopupMenu = item_c.get_node("%MenuContexto")

	main_script._on_menu_solicitado(item_a)
	_check(menu_a.is_item_disabled(menu_a.get_item_index(5)), "en la primera fila Subir queda deshabilitada")
	_check(not menu_a.is_item_disabled(menu_a.get_item_index(6)), "en la primera fila Bajar queda habilitada")

	main_script._on_menu_solicitado(item_b)
	_check(not menu_b.is_item_disabled(menu_b.get_item_index(5)), "en la fila central Subir queda habilitada")
	_check(not menu_b.is_item_disabled(menu_b.get_item_index(6)), "en la fila central Bajar queda habilitada")

	main_script._on_menu_solicitado(item_c)
	_check(not menu_c.is_item_disabled(menu_c.get_item_index(5)), "en la última fila Subir queda habilitada")
	_check(menu_c.is_item_disabled(menu_c.get_item_index(6)), "en la última fila Bajar queda deshabilitada")
```

Nota: `_on_menu_solicitado(item)` se comprueba directamente, sin abrir el menú real (el popup real no es viable en headless). La llamada directa es válida porque el estado se calcula y se aplica al `PopupMenu`.

- [x] **Step 2: Run test to verify it fails**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd`
Expected: FAIL — `_filas_visibles`, `_indice_entrada` y `_on_menu_solicitado` no existen.

- [x] **Step 3: Write minimal implementation in `scripts/main.gd`**

En `_mostrar_lista()` (tras las conexiones de señales, líneas 639-643), conectar las tres nuevas:

```gdscript
		item.subir_pedido.connect(_on_mover_pedido.bind(item, -1))
		item.bajar_pedido.connect(_on_mover_pedido.bind(item, 1))
		item.menu_solicitado.connect(_on_menu_solicitado.bind(item))
```

Añadir los helpers y handlers (junto a `_comparar_orden` al final del archivo, tras la línea 1025):

```gdscript
func _filas_visibles() -> Array:
	var visibles: Array = []
	for hijo in lista.get_children():
		if hijo.visible:
			visibles.append(hijo)
	return visibles


func _indice_entrada(url: String) -> int:
	for i in _entradas.size():
		var entrada: Dictionary = _entradas[i]
		if GestorCatalogoScript.clave_unica(str(entrada.get("url", ""))) == GestorCatalogoScript.clave_unica(url):
			return i
	return -1


func _on_menu_solicitado(item: Button) -> void:
	if orden_fecha.get_selected_id() > 0:
		item.fijar_estado_reorden(false, false)
		return
	var visibles := _filas_visibles()
	var idx := visibles.find(item)
	item.fijar_estado_reorden(idx > 0, idx >= 0 and idx < visibles.size() - 1)


func _on_mover_pedido(item: Button, delta: int) -> void:
	if orden_fecha.get_selected_id() > 0:
		return
	var visibles := _filas_visibles()
	var idx := visibles.find(item)
	if idx < 0:
		return
	var vecino_idx := idx + delta
	if vecino_idx < 0 or vecino_idx >= visibles.size():
		return
	var i := _indice_entrada(item.url)
	var j := _indice_entrada(visibles[vecino_idx].url)
	if i < 0 or j < 0:
		return
	var tmp = _entradas[i]
	_entradas[i] = _entradas[j]
	_entradas[j] = tmp
	if not _guardar_datos():
		_entradas[j] = _entradas[i]
		_entradas[i] = tmp
		progreso.text = "No se pudo guardar el orden."
		return
	_refrescar_vista()
```

- [x] **Step 4: Run test to verify it passes**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd`
Expected: `TESTS OK`

- [x] **Step 5: Commit**

```bash
git add scripts/main.gd tests/test_main_barra.gd
git commit -m "feat(reorden): main conecta Subir/Bajar, estados del menu y visibilidad (TDD)"
```

---
- [x] **Task 3: reorden real, filtros y persistencia**

**Files:**
- Modify: `scripts/main.gd`, `tests/test_main_barra.gd`

**Interfaces:**
- Consumes: de Task 2 — `_filas_visibles`, `_indice_entrada`, `_on_mover_pedido`, `_on_menu_solicitado`, conexiones en `_mostrar_lista`.

- [x] **Step 1: Write the failing test in `tests/test_main_barra.gd`**

**Precondición de persistencia:** para que el test no toque los ficheros reales del usuario (`user://enlaces.json`) ni el trackeado `res://data/data.json`, esta tarea cambia `DATA_RES` y `DATA_USER` de `const` a `var` en `main.gd` (líneas 4-5) y el test redirige ambas a una base temporal antes de instanciar Main. Así `_cargar_datos()` del `_ready()` arranca con un catálogo vacío (mejor aislamiento, y los checks existentes ya no dependen de los datos reales).

En `_arrancar()` (línea 27), justo tras `var main := MAIN_SCENE.instantiate()` y antes de `root.add_child(main)`:

```gdscript
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://__test_main_barra__"))
	var main := MAIN_SCENE.instantiate()
	main.DATA_RES = "user://__test_main_barra__/data.json"
	main.DATA_USER = "user://__test_main_barra__/enlaces.json"
	root.add_child(main)
```

> Nota: `DirAccess.make_dir_recursive_absolute` crea la carpeta temporal; `_cargar_datos()` la lee vacía o inexistente y arranca con catálogo vacío.

Añadir, tras el bloque de checks de la Task 2, este bloque único de reorden/persistencia/filtros:

```gdscript
	main_script._entradas = [
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""},
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": ""},
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": ""}
	]
	main_script._refrescar_vista()
	await process_frame
	visibles = main_script._filas_visibles()
	var item_b_real: Button = visibles[1]
	main_script._persistir = true
	main_script._on_mover_pedido(item_b_real, -1)
	main_script._persistir = false
	_check(main_script._indice_entrada("https://a.test") == 1 and main_script._indice_entrada("https://b.test") == 0, "Subir B la coloca antes de A en _entradas")

	# limpiar y refrescar (el swap anterior ya devolvió el orden a B,A,C; resetear para la 2a vuelta)
	var urls_antes: Array = []
	for e in main_script._entradas:
		urls_antes.append(str(e.get("url", "")))
	_check(urls_antes == ["https://b.test", "https://a.test", "https://c.test"], "tras guardar el orden B,A,C queda persistido en memoria")

	var persistido: Array = GestorDatosScript.cargar(main_script.DATA_USER)
	var orden_persistido: Array = []
	for e in persistido:
		orden_persistido.append(str(e.get("url", "")))
	_check(orden_persistido == ["https://b.test", "https://a.test", "https://c.test"], "tras guardar el orden B,A,C queda en el archivo de usuario")

	var item_b_rest: Button = main_script._filas_visibles()[0]
	main_script._on_mover_pedido(item_b_rest, 1)
	_check(main_script._indice_entrada("https://b.test") == 1, "Bajar devuelve B a su posición original")

	main_script._entradas = [
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": "", "cat": "cliente"},
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": "", "cat": "otro"},
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": "", "cat": "cliente"}
	]
	main_script._estados = {}
	main_script.filtro_cat.select(2)
	main_script._refrescar_vista()
	await process_frame
	var visibles_filtradas := main_script._filas_visibles()
	_check(visibles_filtradas.size() == 2, "el filtro Cliente oculta la fila A (otro)")
	var item_c2: Button = visibles_filtradas[1]
	main_script._on_mover_pedido(item_c2, -1)
	_check(main_script._indice_entrada("https://b.test") == 2 and main_script._indice_entrada("https://c.test") == 0, "Subir C la cruza con B saltando la fila oculta A")
	main_script.filtro_cat.select(0)

	main_script.orden_fecha.select(1)
	main_script._on_mover_pedido(main_script._filas_visibles()[0], -1)
	var antes: Array = []
	for e in main_script._entradas:
		antes.append(str(e.get("url", "")))
	_check(antes == ["https://c.test", "https://a.test", "https://b.test"], "con OrdenFecha activo _on_mover_pedido no modifica _entradas")
	main_script.orden_fecha.select(0)
```

Limpiar la base temporal al final, dentro de `_cerrar()` (antes del `quit`, líneas 616-622):

```gdscript
func _cerrar() -> void:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("user://__test_main_barra__")):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://__test_main_barra__"))
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)
```

**Cambio de producción necesario (Task 3):** en `scripts/main.gd` líneas 4-5, `const DATA_RES := "res://data/data.json"` y `const DATA_USER := "user://enlaces.json"` pasan a `var DATA_RES := "res://data/data.json"` y `var DATA_USER := "user://enlaces.json"`. Solo se usan dentro de `_cargar_datos()` y `_guardar_datos()`, así que el test puede reasignarlas tras `instantiate()`.

- [x] **Step 2: Run test to verify it fails**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd`
Expected: FAIL — `_on_mover_pedido` no conectado o el orden no cambia.

Nota: si `_on_mover_pedido` ya existe (Task 2), comprobar que la conexión `subir_pedido.connect(_on_mover_pedido.bind(item, -1))` está puesta; en el test se llama a `_on_mover_pedido` directamente sobre el instante, así que la comprobación es de comportamiento del swap.

- [x] **Step 3: Ensure implementation from Task 2 covers this**

La lógica de swap ya está en `_on_mover_pedido` (Task 2); esta tarea añade cobertura de filtros y persistencia. Además del bloque de Task 2, hacer **un único cambio de producción**:

En `scripts/main.gd` líneas 4-5, cambiar las constantes a variables:

```gdscript
var DATA_RES := "res://data/data.json"
var DATA_USER := "user://enlaces.json"
```

Verificar que la suite pasa.

Si algo falla por orden de filtros: recordar que `_aplicar_filtro()` (línea 848) usa `filtro.get_selected_id()`; el filtro "Caídos / no existen" es id **2** (no 3). En el test, para ocultar una fila VÁLIDA se usa id 2.

- [x] **Step 4: Run the full battery of tests**

Run:
```bash
$bin="K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe"; Get-ChildItem "K:\gestor-de-enlaces\tests" -Filter "test_*.gd" | ForEach-Object { $out = & $bin --headless --path "K:\gestor-de-enlaces" --script ("res://tests/" + $_.Name) 2>&1; $ok = $out -match "TESTS OK"; Write-Output ("{0}: {1}" -f $_.Name, $(if ($ok) {"OK"} else {"FALLO"})); if (-not $ok) { $out | Select-String -Pattern "FALLO|ERROR" } }
```
Expected: todas las suites `OK`.

- [x] **Step 5: Commit**

```bash
git add scripts/main.gd tests/test_main_barra.gd
git commit -m "test(reorden): reorden con filtros y persistencia en user data"
```

---
- [x] **Task 4: verificación manual y limpieza**

**Files:**
- Modify: ninguno (verificación).
- Test: `tests/test_list_item.gd`, `tests/test_main_barra.gd`.

- [x] **Step 1: Run both suites once more**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_list_item.gd`
Y: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd`
Expected: ambas `TESTS OK`.

- [x] **Step 2: Boot check headless**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --quit-after 3 2>&1`
Expected: sin errores (sin output de `ERROR`/`SCRIPT ERROR`).

- [x] **Step 3: Commit leftover docs if any**

Revisar `git status --short`. Si hay cambios sueltos de esta rama (por ejemplo la spec del tema claro `docs/superpowers/specs/2026-09-19-tema-claro-oscuro-design.md` u otros sin relación), **no** commitearlos aquí.

```bash
git status --short
```

- [x] **Step 4: Close the loop**

Confirmar con el usuario que abra el editor y pruebe en vivo: abrir menú contextual → Subir/Bajar con los estados correctos en primera/última fila, con filtros y con OrdenFecha activo; reiniciar la app para ver el orden persistido.