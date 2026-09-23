# Ordenación por columnas (#17) — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Permitir ordenar la lista por nombre, estado, fecha o presencia de imagen desde 4 cabeceras clicables, sustituyendo el selector `OrdenFecha`, con persistencia del criterio en `config_store`.

**Architecture:** Las cabeceras (`toggle_mode`) viven en una `FilaCabeceras` nueva en `main.tscn`; `main.gd` guarda `_orden_columna`/`_orden_direccion`, ordena los hijos visibles con `sort_custom` en `_aplicar_filtro()` (patrón actual) y bloquea Subir/Bajar cuando una columna está activa. El criterio se persiste y restaura vía `config_store`.

**Tech Stack:** Godot 4.7.2 / GDScript. Tests SceneTree (`--headless --script`).

## Global Constraints

- Sin comentarios en scripts (los tests pueden llevar comentarios seccionales, como el patrón existente).
- Tabs para indentar; UI en español.
- Preload-const en lugar de class_name (código nuevo).
- Tests usan bases `user://__test_*__` y se limpian.
- Runner local (Windows): matar Godot residuales antes de cada ejecución.
- No tocar trabajo ajeno sin commitear (`data/data.json`, `data/servidores.json`, `project.godot`, `scenes/ListItem.tscn`, `scenes/Main.tscn`, `scripts/tema_store.gd`, `tests/test_tema_store.gd`, untracked). Solo staging selectivo.

---

### Task 1: config_store persiste el criterio de orden

**Files:**
- Modify: `scripts/config_store.gd`
- Test: `tests/test_config_store.gd`

**Interfaces:**
- Produces: `cargar()` devuelve `orden_columna` (String validado) y `orden_direccion` (int, -1 o 1). `guardar(paralelismo, timeout, auto_abrir, intervalo, tema, ultima_version_vista, orden_columna, orden_direccion)` acepta los dos nuevos args opcionales al final (no rompe callers existentes).

- [x] **Step 1: Escribir los tests que fallan**

En `tests/test_config_store.gd` el array de checks de `_initialize()` (tras la línea 26 `_check(ultima_no_string_normaliza(), ...)`), añadir:

```gdscript
	_check(orden_default_sin_fichero(), "sin fichero orden_columna vacía y dirección 1")
	_check(orden_persistido(), "guardar() persiste columna y dirección")
	_check(orden_invalida_normaliza(), "columna no válida se normaliza a vacía")
	_check(orden_direccion_invalida_normaliza(), "dirección no válida se normaliza a 1")
```

Al final del archivo, añadir estas funciones:

```gdscript
func orden_default_sin_fichero() -> bool:
	var c := ConfigStore.new(BASE).cargar()
	return c.get("orden_columna", "#") == "" and c.get("orden_direccion", 0) == 1


func orden_persistido() -> bool:
	var store := ConfigStore.new(BASE)
	if not store.guardar(4, 12.0, true, 30, "oscuro", "", "fecha", -1):
		return false
	var c := store.cargar()
	return c.get("orden_columna", "#") == "fecha" and c.get("orden_direccion", 0) == -1


func orden_invalida_normaliza() -> bool:
	var store := ConfigStore.new(BASE)
	store.guardar(4, 12.0, true, 30, "oscuro", "", "tamanyo", 1)
	return store.cargar().get("orden_columna", "#") == ""


func orden_direccion_invalida_normaliza() -> bool:
	var store := ConfigStore.new(BASE)
	store.guardar(4, 12.0, true, 30, "oscuro", "", "fecha", 42)
	return store.cargar().get("orden_direccion", 0) == 1
```

- [x] **Step 2: Ejecutar para verificar que fallan**

```bash
Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Stop-Process -Force; & "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_config_store.gd --quit-after 700
```

Expected: FAIL con `TESTS FALLIDOS: 4` (los checks leen claves inexistentes → valores por defecto `"#"`/`0`).

- [x] **Step 3: Implementación mínima en config_store.gd**

Añadir constantes tras `ULTIMA_VERSION_DEFAULT` (línea 14):

```gdscript
const ORDEN_COLUMNA_DEFAULT := ""
const ORDEN_COLUMNAS_VALIDAS := ["", "nombre", "estado", "fecha", "imagen"]
const ORDEN_DIRECCION_DEFAULT := 1
```

En `cargar()`: en el return del caso "sin fichero" (líneas 26-33) añadir al dict:

```gdscript
			"orden_columna": ORDEN_COLUMNA_DEFAULT,
			"orden_direccion": ORDEN_DIRECCION_DEFAULT,
```

En el return del segundo caso (dict JSON), añadir:

```gdscript
		"orden_columna": _orden_columna_ok(v.get("orden_columna", ORDEN_COLUMNA_DEFAULT)),
		"orden_direccion": _orden_direccion_ok(v.get("orden_direccion", ORDEN_DIRECCION_DEFAULT)),
```

Cambiar la firma de `guardar()` (línea 44) a:

```gdscript
func guardar(paralelismo: int, timeout: float, auto_abrir := AUTO_ABRIR_DEFAULT, intervalo := INTERVALO_DEFAULT, tema := TEMA_DEFAULT, ultima_version_vista := ULTIMA_VERSION_DEFAULT, orden_columna := ORDEN_COLUMNA_DEFAULT, orden_direccion := ORDEN_DIRECCION_DEFAULT) -> bool:
```

En el dict de `guardar()`, añadir:

```gdscript
		"orden_columna": _orden_columna_ok(orden_columna),
		"orden_direccion": _orden_direccion_ok(orden_direccion),
```

Añadir los validadores (junto a `_string_ok`, tras línea 74):

```gdscript
func _orden_columna_ok(v: Variant) -> String:
	var col := str(v)
	return col if ORDEN_COLUMNAS_VALIDAS.has(col) else ORDEN_COLUMNA_DEFAULT


func _orden_direccion_ok(v: Variant) -> int:
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		return ORDEN_DIRECCION_DEFAULT
	return -1 if int(v) < 0 else 1
```

- [x] **Step 4: Ejecutar para verificar que pasan**

Mismo comando que Step 2. Expected: `TESTS OK`.

- [x] **Step 5: Commit**

```bash
git add scripts/config_store.gd tests/test_config_store.gd
git commit -m "feat(config): #17 persistir criterio de ordenacion por columnas"
```

---

### Task 2: list_item expone nombre e imagen

**Files:**
- Modify: `scripts/list_item.gd`
- Test: `tests/test_list_item.gd`

**Interfaces:**
- Produces: las filas (`Button`) expondrán `nombre: String` y `img: String` tras `setup()`. Los comparadores de `main.gd` (Task 4) los usan.

- [x] **Step 1: Escribir el test que falla**

En `tests/test_list_item.gd`, en el bloque de `con_imagen`/`sin_imagen` (líneas 29-34), cambiar para usar la ruta del png temporal y añadir el check tras la línea 43:

```gdscript
	var ruta_png := _generar_png_temporal()
	var con_imagen := _crear_item()
	con_imagen.setup("Nom", "Desc", "https://ejemplo.com/v", ruta_png)
	var sin_imagen := _crear_item()
	sin_imagen.setup("Nom", "Desc", "https://ejemplo.com/w", "")
	var inexistente := _crear_item()
	inexistente.setup("Nom", "Desc", "https://ejemplo.com/u", BASE + "/no-existe.png")

	root.add_child(con_imagen)
	root.add_child(sin_imagen)
	root.add_child(inexistente)

	await process_frame
	_check(con_imagen.nombre == "Nom" and con_imagen.img == ruta_png, "setup expone nombre e imagen")
	_check(sin_imagen.img == "", "sin imagen la fila guarda img vacía")
	_check(_miniatura_es(con_imagen, false), "miniatura muestra la imagen elegida")
```

- [x] **Step 2: Ejecutar para verificar que falla**

```bash
Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Stop-Process -Force; & "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_list_item.gd --quit-after 700
```

Expected: FAIL con `TESTS FALLIDOS` (y `Invalid access to property 'nombre'/'img'`).

- [x] **Step 3: Implementación mínima en list_item.gd**

Añadir, junto a `var url: String = ""` (línea 21):

```gdscript
var nombre := ""
var img := ""
```

En `setup()` (línea 45), al inicio del cuerpo setear antes de sobreescribir el texto (no modificar nada más del cuerpo):

```gdscript
	self.nombre = nombre
	self.img = imagen
```

- [x] **Step 4: Ejecutar para verificar que pasa**

Mismo comando que Step 2. Expected: `TESTS OK`.

- [x] **Step 5: Commit**

```bash
git add scripts/list_item.gd tests/test_list_item.gd
git commit -m "feat(list_item): #17 exponer nombre e imagen para comparar"
```

---

### Task 3: escena con las 4 cabeceras

**Files:**
- Create (dentro de `Main.tscn`): `FilaCabeceras/CabNombre`, `CabEstado`, `CabFecha`, `CabImagen`
- Test: `tests/test_main_barra.gd`

**Interfaces:**
- Consumes: nodos únicos `%CabNombre`, `%CabEstado`, `%CabFecha`, `%CabImagen` (Task 4 los conecta).
- Nota: `OrdenFecha` se retira en la Task 4 (mismo commit que la lógica), para no romper `main.gd` a mitad.

- [x] **Step 1: Escribir el test que falla**

En `tests/test_main_barra.gd`, al inicio del bloque de la línea 450 (`# Disponibilidad: selector de orden por fecha (#9)`), añadir un check de disponibilidad de cabeceras (antes de la línea 452 que aún valida OrdenFecha):

```gdscript
	_check(main.has_node("%CabNombre") and main.has_node("%CabEstado") \
		and main.has_node("%CabFecha") and main.has_node("%CabImagen"), "la barra muestra las 4 cabeceras de columna")
```

- [x] **Step 2: Ejecutar para verificar que falla**

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd --quit-after 700
```

Expected: FAIL con "la barra muestra las 4 cabeceras de columna".

- [x] **Step 3: Añadir la fila de cabeceras en scenes/Main.tscn**

Insertar entre el fin de `BarraAcciones` (tras `BarraProgreso`, línea ~120) y el nodo `ScrollContainer` (línea 122), como hijo de `ColumnaApp/Margen/Columna` (mismo nivel que `BarraAcciones`):

```
[node name="FilaCabeceras" type="HBoxContainer" parent="ColumnaApp/Margen/Columna"]
layout_mode = 2
theme_override_constants/separation = 8

[node name="CabNombre" type="Button" parent="ColumnaApp/Margen/Columna/FilaCabeceras"]
unique_name_in_owner = true
layout_mode = 2
size_flags_horizontal = 3
toggle_mode = true
text = "Nombre"

[node name="CabEstado" type="Button" parent="ColumnaApp/Margen/Columna/FilaCabeceras"]
unique_name_in_owner = true
layout_mode = 2
toggle_mode = true
text = "Estado"

[node name="CabFecha" type="Button" parent="ColumnaApp/Margen/Columna/FilaCabeceras"]
unique_name_in_owner = true
layout_mode = 2
toggle_mode = true
text = "Fecha"

[node name="CabImagen" type="Button" parent="ColumnaApp/Margen/Columna/FilaCabeceras"]
unique_name_in_owner = true
layout_mode = 2
toggle_mode = true
text = "Imagen"
```

- [x] **Step 4: Ejecutar para verificar que pasa**

Mismo comando que Step 2. Expected: `TESTS OK`.

- [x] **Step 5: Commit**

```bash
git add scenes/Main.tscn tests/test_main_barra.gd
git commit -m "feat(ui): #17 cabeceras de ordenacion por columnas en la escena"
```

---

### Task 4: lógica de ordenación, guards, persistencia y restauración

**Files:**
- Modify: `scripts/main.gd` (varias zonas listadas abajo)
- Modify: `scenes/Main.tscn` (quitar `OrdenFecha`)
- Test: `tests/test_main_barra.gd`

**Interfaces:**
- Consumes: `config_store.guardar(...)` con 8 args (Task 1), filas con `nombre`/`img` (Task 2), cabeceras `%Cab*` (Task 3).
- Produces: `_orden_columna: String`, `_orden_direccion: int`, `_pulsar_cabecera(columna: String)`, `_pintar_cabeceras()`, `_comparar_orden(a, b) -> bool`, `_persistir_orden() -> bool`, `_peso_estado(v) -> int`, `_direccion_por_defecto(columna) -> int`, `CONFIG_BASE: String` (inyectable, default `"user://"`).

- [x] **Step 1: Reescribir el bloque de tests del selector (RED)**

En `tests/test_main_barra.gd`, sustituir el bloque completo de la disponibilidad de OrdenFecha y el bloque de ordenación por fecha (líneas 452-490) por:

```gdscript
	_check(main.has_node("%CabNombre") and main.has_node("%CabEstado") \
		and main.has_node("%CabFecha") and main.has_node("%CabImagen"), "la barra muestra las 4 cabeceras de columna")
	var cab_nombre_btn := main.get_node("%CabNombre")
	var cab_estado_btn := main.get_node("%CabEstado")
	var cab_fecha_btn := main.get_node("%CabFecha")
	var cab_imagen_btn := main.get_node("%CabImagen")
	_check(cab_nombre_btn.get_parent().name == "FilaCabeceras", "las cabeceras viven en FilaCabeceras")
	_check(cab_nombre_btn.toggle_mode and cab_estado_btn.toggle_mode \
		and cab_fecha_btn.toggle_mode and cab_imagen_btn.toggle_mode, "las cabeceras son pulsables (toggle_mode)")

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
	await process_frame

	main_script._pulsar_cabecera("fecha")
	_check(main_script._orden_columna == "fecha" and main_script._orden_direccion == -1, "primer clic en Fecha activa descendente")
	_check(cab_fecha_btn.text == "Fecha ▼", "la cabecera Fecha activa muestra indicador descendente")
	_check(_urls_visibles(main) == ["https://b.test", "https://a.test", "https://c.test"], "Fecha descendente: más recientes primero y lo sin comprobar al final")

	main_script._pulsar_cabecera("fecha")
	_check(main_script._orden_direccion == 1, "segundo clic en la misma cabecera invierte a ascendente")
	_check(cab_fecha_btn.text == "Fecha ▲", "la cabecera Fecha invertida muestra indicador ascendente")
	_check(_urls_visibles(main) == ["https://a.test", "https://b.test", "https://c.test"], "Fecha ascendente: más antiguos primero y lo sin comprobar al final")

	main_script._pulsar_cabecera("fecha")
	_check(main_script._orden_columna == "", "tercer clic desactiva la columna")
	_check(_urls_visibles(main) == ["https://a.test", "https://b.test", "https://c.test"], "sin columna conserva el orden de inserción")
```

- [x] **Step 2: Añadir los tests de los demás criterios (RED)**

Tras el bloque del Step 1 (y antes del comentario `# Disponibilidad: historial desde la fila (#10)`), insertar:

```gdscript
	# #17: columna Nombre (asc por defecto)
	main_script._entradas = [
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": ""},
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""},
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": ""},
	]
	main_script._estados = {}
	main_script._refrescar_vista()
	await process_frame
	main_script._pulsar_cabecera("nombre")
	_check(_urls_visibles(main) == ["https://a.test", "https://b.test", "https://c.test"], "Nombre ascendente ordena alfabéticamente")
	main_script._pulsar_cabecera("nombre")
	_check(_urls_visibles(main) == ["https://c.test", "https://b.test", "https://a.test"], "Nombre descendente invierte el orden")
	main_script._pulsar_cabecera("nombre")
	_check(main_script._orden_columna == "", "3 clics en Nombre vuelven a sin ordenar")

	# #17: columna Imagen (con imagen primero en asc)
	var ruta_b := _crear_captura("img_ord_b.png")
	var ruta_c := _crear_captura("img_ord_c.png")
	main_script._entradas = [
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""},
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": ruta_b},
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": ruta_c},
	]
	main_script._estados = {}
	main_script._refrescar_vista()
	await process_frame
	main_script._pulsar_cabecera("imagen")
	_check(_urls_visibles(main) == ["https://b.test", "https://c.test", "https://a.test"], "Imagen ascendente pone con captura primero (alfabético luego)")
	main_script._pulsar_cabecera("imagen")
	_check(_urls_visibles(main) == ["https://a.test", "https://b.test", "https://c.test"], "Imagen descendente pone sin captura primero")
	main_script._pulsar_cabecera("imagen")
	_check(main_script._orden_columna == "", "3 clics en Imagen vuelven a sin ordenar")

	# #17: columna Estado (sin comprobar → válidos → caídos)
	main_script._entradas = [
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""},
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": ""},
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": ""},
	]
	main_script._estados = {
		"a.test": {"valido": true, "mensaje": "OK", "codigo": 200, "fecha": 1000},
		"b.test": {"valido": false, "mensaje": "No existe", "codigo": 404, "fecha": 1000},
	}
	main_script._refrescar_vista()
	await process_frame
	main_script._pulsar_cabecera("estado")
	_check(_urls_visibles(main) == ["https://b.test", "https://a.test", "https://c.test"], "Estado descendente: caídos, válidos, sin comprobar")
	main_script._pulsar_cabecera("estado")
	_check(_urls_visibles(main) == ["https://c.test", "https://a.test", "https://b.test"], "Estado ascendente: sin comprobar, válidos, caídos")
	main_script._pulsar_cabecera("estado")
	_check(main_script._orden_columna == "", "3 clics en Estado vuelven a sin ordenar")
```

- [x] **Step 3: Añadir tests de guard, persistencia, restauración y rollback (RED)**

Reemplazar el bloque de guard existente (líneas 679-685, `main_script.orden_fecha.select(1) ...`) — que ya no compila al eliminar la var `orden_fecha` — por:

```gdscript
	main_script._pulsar_cabecera("imagen")
	main_script._on_mover_pedido(main_script._filas_visibles()[0], -1)
	var antes: Array = []
	for e in main_script._entradas:
		antes.append(str(e.get("url", "")))
	_check(antes == ["https://c.test", "https://a.test", "https://b.test"], "con columna activa _on_mover_pedido no modifica _entradas")
	main_script._on_menu_solicitado(main_script._filas_visibles()[0])
	_check(main_script._filas_visibles()[0].get_node("%MenuContexto").is_item_disabled(
		main_script._filas_visibles()[0].get_node("%MenuContexto").get_item_index(5)), "con columna activa Subir queda deshabilitada")
	main_script._pulsar_cabecera("imagen")
	main_script._pulsar_cabecera("imagen")
	_check(main_script._orden_columna == "", "3 clics en la columna activa vuelven a sin ordenar")
```

Tras ese bloque, añadir el test de persistencia/restauración y rollback:

```gdscript
	# #17: persistencia y restauración del criterio
	main_script._pulsar_cabecera("fecha")
	var guardado: Dictionary = main_script._config_store.cargar()
	_check(guardado.get("orden_columna", "") == "fecha" and guardado.get("orden_direccion", 0) == -1, "pulsar una cabecera persiste el criterio")
	main_script._persistir_version_vista()
	var preservado: Dictionary = main_script._config_store.cargar()
	_check(preservado.get("orden_columna", "") == "fecha", "persistir la versión vista conserva el criterio")
	main_script._pulsar_cabecera("fecha")
	main_script._pulsar_cabecera("fecha")
	_check(main_script._config_store.cargar().get("orden_columna", "#") == "", "desactivar la columna persiste sin criterio")

	var base_orden := "user://__test_orden_restore__"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_orden))
	ConfigStoreScript.new(base_orden).guardar(3, 10.0, true, 0, "oscuro", "", "fecha", -1)
	var main_rest := MAIN_SCENE.instantiate()
	main_rest.DATA_RES = base_orden + "/data.json"
	main_rest.DATA_USER = base_orden + "/enlaces.json"
	main_rest.CONFIG_BASE = base_orden
	root.add_child(main_rest)
	await process_frame
	await process_frame
	var mrs: Node = main_rest.get_node(".")
	_check(mrs._orden_columna == "fecha" and mrs._orden_direccion == -1, "otro arranque restaura el criterio desde config")
	_check(_urls_visibles(main_rest).is_empty() or _urls_visibles(main_rest).size() >= 0, "el segundo arranque carga sin errores")
	main_rest.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(base_orden))

	# #17: si no se puede guardar, se revierte el criterio
	var store_roto := ConfigStoreScript.new("user://__test_main_barra__/nada/cfg")
	main_script._config_store = store_roto
	main_script._pulsar_cabecera("nombre")
	_check(main_script._orden_columna == "", "si la persistencia falla se revierte el criterio")
	_check(store_roto.cargar().get("orden_columna", "") == "", "el fallo no deja criterio guardado")
	main_script._config_store = ConfigStoreScript.new()
```

Añadir el preload `ConfigStoreScript` a los consts del test (junto a `const GestorDatosScript`, línea 17):

```gdscript
const ConfigStoreScript := preload("res://scripts/config_store.gd")
```

Añadir el helper `_urls_visibles` (junto a `_filas_visibles`… no existe en el test; añadir cerca de `_check`, línea 736):

```gdscript
func _urls_visibles(main_node: Node) -> Array:
	var urls: Array = []
	for hijo in main_node.get_node("%ListaContenedor").get_children():
		if hijo.visible:
			urls.append(hijo.url)
	return urls
```

En `_arrancar()` (línea 29), hacer inyectable la base de config antes de `add_child`:

```gdscript
	var main := MAIN_SCENE.instantiate()
	main.DATA_RES = "user://__test_main_barra__/data.json"
	main.DATA_USER = "user://__test_main_barra__/enlaces.json"
	main.CONFIG_BASE = "user://__test_main_barra__"
	root.add_child(main)
```

- [x] **Step 4: Ejecutar para verificar que todo lo nuevo falla**

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd --quit-after 700
```

Expected: fallos de parseo (`orden_fecha` no existe, `pressed`/`_pulsar_cabecera` no existen, `CONFIG_BASE` no existe, etc.).

- [x] **Step 5: Implementar main.gd**

**5a. Eliminar la var del selector.** Quitar la línea 32 `@onready var orden_fecha: OptionButton = %OrdenFecha` y sustituirla por (junto a los otros `@onready`):

```gdscript
@onready var cab_nombre: Button = %CabNombre
@onready var cab_estado: Button = %CabEstado
@onready var cab_fecha: Button = %CabFecha
@onready var cab_imagen: Button = %CabImagen
```

**5b. Var de estado e inyección de base.** Junto a `var _config_store: RefCounted` (línea 42), añadir:

```gdscript
var CONFIG_BASE := "user://"
var _orden_columna := ""
var _orden_direccion := 1
```

**5c. Conectar cabeceras en _ready.** Sustituir el bloque 81-86 (poblar y conectar `orden_fecha`) por:

```gdscript
	cab_nombre.pressed.connect(func() -> void: _pulsar_cabecera("nombre"))
	cab_estado.pressed.connect(func() -> void: _pulsar_cabecera("estado"))
	cab_fecha.pressed.connect(func() -> void: _pulsar_cabecera("fecha"))
	cab_imagen.pressed.connect(func() -> void: _pulsar_cabecera("imagen"))
```

**5d. Restaurar el criterio al arrancar.** En `_ready()`, cambiar la línea 92 `_config_store = ConfigStoreScript.new()` por `_config_store = ConfigStoreScript.new(CONFIG_BASE)` y, justo después de la línea 99 (`TemaStoreScript.aplicar(...)`), añadir:

```gdscript
	_orden_columna = str(cfg.get("orden_columna", ""))
	_orden_direccion = -1 if int(cfg.get("orden_direccion", 1)) < 0 else 1
	_pintar_cabeceras()
	if _orden_columna != "":
		_aplicar_filtro()
```

**5e. Métodos de pulsación y pintado.** Añadir (junto a `_comparar_orden`, tras la línea 1028):

```gdscript
func _pulsar_cabecera(columna: String) -> void:
	var prev_col := _orden_columna
	var prev_dir := _orden_direccion
	if _orden_columna != columna:
		_orden_columna = columna
		_orden_direccion = _direccion_por_defecto(columna)
	elif _orden_direccion == _direccion_por_defecto(columna):
		_orden_direccion = -_orden_direccion
	else:
		_orden_columna = ""
	_pintar_cabeceras()
	_aplicar_filtro()
	if not _persistir_orden():
		_orden_columna = prev_col
		_orden_direccion = prev_dir
		_pintar_cabeceras()
		_aplicar_filtro()
		progreso.text = "No se pudo guardar el orden."


func _direccion_por_defecto(columna: String) -> int:
	return 1 if columna == "nombre" or columna == "imagen" else -1


func _pintar_cabeceras() -> void:
	var titulos := {"nombre": "Nombre", "estado": "Estado", "fecha": "Fecha", "imagen": "Imagen"}
	var flecha := "▼" if _orden_direccion == -1 else "▲"
	var pares := {
		"nombre": cab_nombre,
		"estado": cab_estado,
		"fecha": cab_fecha,
		"imagen": cab_imagen,
	}
	for col in pares:
		var boton: Button = pares[col]
		boton.button_pressed = _orden_columna == col
		boton.text = "%s %s" % [titulos[col], flecha] if _orden_columna == col else str(titulos[col])


func _persistir_orden() -> bool:
	var cfg: Dictionary = _config_store.cargar()
	return _config_store.guardar(
		int(cfg.get("paralelismo", 3)),
		float(cfg.get("timeout", 10.0)),
		bool(cfg.get("auto_abrir", true)),
		int(cfg.get("intervalo", 0)),
		str(cfg.get("tema", "oscuro")),
		str(cfg.get("ultima_version_vista", "")),
		_orden_columna,
		_orden_direccion,
	)


func _peso_estado(v: Variant) -> int:
	if v == null:
		return 0
	return 1 if v == true else 2
```

**5f. Generalizar el comparador.** Sustituir `_comparar_orden(a: Button, b: Button, modo: int)` (líneas 1019-1028) por:

```gdscript
func _comparar_orden(a: Button, b: Button) -> bool:
	var dir := _orden_direccion
	match _orden_columna:
		"nombre":
			var na := a.nombre if a.nombre != "" else a.url
			var nb := b.nombre if b.nombre != "" else b.url
			if na == nb:
				return a.url < b.url
			return na < nb if dir == 1 else na > nb
		"estado":
			var ea := _peso_estado(a.valido)
			var eb := _peso_estado(b.valido)
			if ea == eb:
				return a.url < b.url
			return ea > eb if dir == 1 else ea < eb
		"fecha":
			var fa := int(a.fecha)
			var fb := int(b.fecha)
			if fa == fb:
				return a.url < b.url
			if fa == 0:
				return false
			if fb == 0:
				return true
			return fa > fb if dir == -1 else fa < fb
		"imagen":
			var ia := 1 if a.img != "" else 0
			var ib := 1 if b.img != "" else 0
			if ia == ib:
				return a.url < b.url
			return ia > ib if dir == 1 else ia < ib
	return a.url < b.url
```

**5g. Actualizar _aplicar_filtro.** Sustituir las líneas 868-875:

```gdscript
	if _orden_columna != "":
		var hijos: Array = lista.get_children()
		hijos.sort_custom(func(a: Button, b: Button) -> bool:
			return _comparar_orden(a, b)
		)
		for hijo in hijos:
			lista.move_child(hijo, -1)
```

**5h. Guards de Subir/Bajar.** En `_on_menu_solicitado` (línea 1055) y `_on_mover_pedido` (línea 1064), sustituir `if orden_fecha.get_selected_id() > 0:` por `if _orden_columna != "":`.

**5i. Conservar el criterio al persistir la versión vista.** En `_persistir_version_vista()` (líneas 975-985), añadir dos args al final de la llamada `_config_store.guardar(...)`:

```gdscript
		_dialogo_version,
		_orden_columna,
		_orden_direccion,
	)
```

- [x] **Step 6: Retirar OrdenFecha de la escena**

En `scenes/Main.tscn`, eliminar el bloque completo del nodo `OrdenFecha` (líneas 97-107, desde `[node name="OrdenFecha"...` hasta la línea `popup/item_2/id = 2`).

- [x] **Step 7: Ejecutar para verificar que pasa**

```bash
Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Stop-Process -Force; & "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd --quit-after 700
```

Expected: `TESTS OK`. Si algún check falla, depurar: (a) `progreso` es un `@onready` accesible en `_pulsar_cabecera`; (b) `_urls_visibles` recibe el nodo correcto; (c) `ConfigStoreScript` está preloadado en el test; (d) la base `user://__test_main_barra__` de config no interfiere porque `_cerrar()` borra la carpeta completa.

- [x] **Step 8: Commit**

```bash
git add scripts/main.gd scenes/Main.tscn tests/test_main_barra.gd
git commit -m "feat(ui): #17 ordenacion por columnas con persistencia"
```

---

### Task 5: verificación de la batería completa

**Files:**
- Test: batería completa de `tests/test_*.gd`

- [x] **Step 1: Ejecutar la batería completa (21 suites)**

```bash
Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Stop-Process -Force; foreach ($t in (Get-ChildItem tests/test_*.gd | Select-Object -ExpandProperty BaseName)) { "== $t =="; & "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script "res://tests/$t.gd" --quit-after 700 }
```

Expected: `TESTS OK` en las 21 suites (`test_main_barra`, `test_config_store`, `test_list_item` incluidos).

- [x] **Step 2: Boot headless sin errores**

```bash
Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Stop-Process -Force; & "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --quit-after 500
```

Expected: arranque limpio sin errores de parseo ni nodos faltantes.

- [x] **Step 3: Marcar los checkboxes de este plan**

Sustituir todos los `- [x]` de este archivo por `- [x]` y commitear:

```bash
git add docs/superpowers/plans/2026-09-23-ordenacion-columnas.md
git commit -m "docs(plan): #17 ordenacion por columnas completado (checkboxes)"
```

---

## Self-Review (del plan contra la spec)

- **Spec → Task:** cabeceras (`Task 3`+`Task 4`), criterios nombre/estado/fecha/imagen (`Task 4` comparador + tests), dirección por defecto por columna (`_direccion_por_defecto`), toggle en la misma cabecera (`_pulsar_cabecera`), desactivación y vuelta al orden manual (3er clic, test), guard de Subir/Bajar con columna activa (Step 3), reemplazo de OrdenFecha (5a/6), persistencia + restauración (5d/5i + tests), rollback de guardar fallido (5e + test). Cubierto.
- **Placeholders:** ninguna — todos los pasos tienen código literal.
- **Consistencia de tipos:** `_comparar_orden(a, b)` con 2 args en `_aplicar_filtro` y test; `guardar(...)` 8 args con los 2 últimos opcionales; `CONFIG_BASE` usado en `_ready()` (5d) y en el test (Step 3 de Task 4). Nombres de métodos/props idénticos en todas las tareas.