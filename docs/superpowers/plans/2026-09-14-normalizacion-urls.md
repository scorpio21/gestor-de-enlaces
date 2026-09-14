# Normalización de URLs y arreglos de la ventana Agregar enlace — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Normalizar las URLs al guardarlas (`normalizar_url`) y usar una forma canónica sin esquema (`clave_unica`) como clave de unicidad y de estado, eliminando los duplicados semánticos (`http`/`https`, `/` final, mayúsculas, fragmento, puerto por defecto). En el mismo ciclo se arreglan dos bugs de la ventana Agregar enlace: el botón Guardar fuera de vista (#32) y la aceptación real de imágenes `.jpg` (#33, con carpeta propia y errores visibles).

**Architecture:** `gestor_catalogo.gd` gana dos helpers estáticos puros (`normalizar_url` para la forma guardada conservando el esquema elegido, `clave_unica` sin esquema para deduplicar y indexar estados/borrados); `separar()` compara por `clave_unica` y devuelve formas canónicas. `main.gd` normaliza en todas las rutas de escritura (alta, lote, edición), aplica una migración en memoria al cargar (`_normalizar_urls` re-aja `_estados`/`_borrados` y normaliza las URLs de las entradas) y usa `clave_unica` para estados, borrados y listado. `gestor_contadores.gd` busca estados por `clave_unica`. `link_checker.gd` y `estado_store.gd` NO cambian. Además: `gestor_imagenes.copiar()` conserva el formato por extensión (jpg → `Assets/jpg`), `limpiar_huerfanas` cubre ambas carpetas, y la ventana pasa a `resizable` con más altura.

**Tech Stack:** Godot 4.7 (GDScript, escenas `.tscn`), ejecución headless para tests (`--script res://tests/<archivo>.gd` con harness SceneTree `_check`), smoke con `res://scenes/Main.tscn --quit-after`.

## Global Constraints

- **Motor/binario headless:** `K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe` con `--headless --path "K:\gestor-de-enlaces"`. Todas las tareas corren en PowerShell (workdir `K:\gestor-de-enlaces`). El segmento `4.6.1` de la ruta es solo la carpeta que contiene el binario 4.7.2.
- **Formas canónicas:** `normalizar_url` conserva el esquema; `clave_unica` lo elimina (host en minúsculas, sin fragmento, sin slash de raíz, puerto por defecto omitido, path intacto con sus mayúsculas). Definido en `docs/superpowers/specs/2026-09-14-normalizacion-urls-design.md` (tabla de ejemplos línea 63-71).
- **Sin unificar `www.`** (decisión de alcance): `x.com` y `www.x.com` siguen siendo enlaces distintos.
- **Estado de las claves:** `_estados` (en memoria) y las claves escritas en `estados.json`/`borrados.json` pasan a ser `clave_unica`; `estado_store.gd` no cambia (es un diccionario por clave; `main` decide la clave).
- **Migración:** solo en memoria al cargar (`_normalizar_urls`); colisión de claves de estados → gana la **última** en orden del JSON; borrados re-ajeado + deduplicado. La base `data/data.json` se sincroniza sola con `_guardar_datos()` como hoy (las 56 URLs actuales ya son canónicas → no-op).
- **Imágenes (#33):** png → `Assets/png/img_<ts>.png`; jpg/jpeg → `Assets/jpg/img_<ts>.jpg` (`save_jpg` calidad 0.9); webp → reconvertido a png en `Assets/png`; otra extensión → `ok:false` "Formato no soportado.". Redimensión >800px igual para todos. `limpiar_huerfanas` y `_borrar_captura_si_huerfana` cubren `Assets/png` y `Assets/jpg`.
- **Ventana (#32):** `unresizable = true` → `resizable = true`; `size = Vector2i(540, 680)`.
- **No tocar:** `data/data.json.bak`, `data/data2.json`, `docs/superpowers/plans/2026-09-05-captura-enlaces.md` (untracked protegidos). `tests/diag_jpg.gd` (scratch de diagnóstico) se elimina antes del push.
- **Idioma/texto UI en español.** Null de comentarios en código nuevo.
- **Tests headless (harness SceneTree fijado):** salida limpia, `print("  OK: %s")`, `push_error("FALLO: ...")`, al final `TESTS OK` + `quit(0)`, o `TESTS FALLIDOS: N` + `quit(1)`.
- **Patrón de preload** (repo): `const XxxScript := preload("res://scripts/xxx.gd")`, sin `class_name`. Tabs. Las cabeceras `extends` van seguidas de dos líneas en blanco.
- **Sidecars `.uid`:** si Godot genera `*.gd.uid` nuevos al tocar scripts, se versionan en el commit de su tarea; si no aparecen, no es bloqueante.

## File Structure

| Archivo | Responsabilidad | Acción |
|---|---|---|
| `scripts/gestor_catalogo.gd` | `normalizar_url`, `clave_unica`, `separar` canónico | Modificar (Task 1) |
| `tests/test_gestor_catalogo.gd` | Tests de normalización (21 → ~32) | Modificar (Task 1) |
| `scripts/main.gd` | Migración + escrituras (entradas/estados/borrados/lista) | Modificar (Tasks 2 y 3) |
| `tests/test_main_barra.gd` | Dedup semántico, migración, recompra, filtro | Modificar (Tasks 2, 3 y 5) |
| `scripts/gestor_contadores.gd` | Contar estados por `clave_unica` | Modificar (Task 3) |
| `tests/test_gestor_contadores.gd` | Claves sin esquema (7 → 8) | Modificar (Task 3) |
| `scenes/AgregarEnlace.tscn` | `resizable`, altura 680, filtros del diálogo | Modificar (Task 4) |
| `scripts/agregar_enlace.gd` | Error visible al decodificar imagen | Modificar (Task 4) |
| `tests/test_agregar_enlace.gd` | Ventana (#32) e imagen (#33) (25 → ~30) | Modificar (Task 4) |
| `scripts/gestor_imagenes.gd` | `copiar` por formato, `limpiar_huerfanas` ambas carpetas | Modificar (Task 5) |
| `tests/test_gestor_imagenes.gd` | Formatos/carpetas (13 → ~20) | Modificar (Task 5) |

**Interfaces (contrato entre tareas):**

- `gestor_catalogo.gd`: `static func normalizar_url(url: String) -> String`; `static func clave_unica(url: String) -> String`.
- `main.gd`: helpers privados `_normalizar_urls()`, `_url_existente(url) -> String` (devuelve la URL canónica de la entrada que colisiona, o `""`).
- `gestor_contadores.gd`: `contar(entradas, estados)` busca `estados.get(clave_unica(url))`; preload `const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")`.
- `gestor_imagenes.gd`: `copiar(origen) -> Dictionary` conserva formato; `limpiar_huerfanas(referidas)` cubre png+jpg.

---

### Task 1: `normalizar_url`, `clave_unica` y `separar` canónico en gestor_catalogo

**Files:**
- Modify: `scripts/gestor_catalogo.gd`
- Modify: `tests/test_gestor_catalogo.gd`

**Interfaces:**
- Consumes: nada.
- Produces: `normalizar_url`, `clave_unica`, y `separar` devolviendo formas canónicas.

- [ ] **Step 1: Actualizar los tests que fallan (RED)**

En `tests/test_gestor_catalogo.gd`, sustituir el check de mayúsculas (líneas 22-23):

```gdscript
	sep = GestorCatalogo.separar(["HTTPS://A.COM"], ["https://a.com"])
	_check(sep.get("nuevas") == [] and sep.get("repetidas") == ["https://a.com"], "separar colisiona HTTPS/https y devuelve la forma canónica")
```

Añadir después del bloque de `separar` existente (tras la línea 29), antes de `# Categorías`:

```gdscript
	_check(GestorCatalogo.normalizar_url("HTTP://Ejemplo.com/a#sec") == "http://ejemplo.com/a", "normalizar_url baja esquema y host y quita el fragmento")
	_check(GestorCatalogo.normalizar_url("http://x.com/") == "http://x.com", "normalizar_url quita el slash de raíz")
	_check(GestorCatalogo.normalizar_url("http://x.com:80/p?q=1") == "http://x.com/p?q=1", "normalizar_url quita el puerto 80 de http")
	_check(GestorCatalogo.normalizar_url("https://x.com:443/A/B/") == "https://x.com/A/B/", "normalizar_url quita el puerto 443 y conserva la subruta")
	_check(GestorCatalogo.normalizar_url("https://x.com:8080/A/B/") == "https://x.com:8080/A/B/", "normalizar_url conserva el puerto no estándar")
	_check(GestorCatalogo.normalizar_url("ftp://x.com") == "ftp://x.com" and GestorCatalogo.normalizar_url("") == "", "normalizar_url no toca no-http ni vacía")
	_check(GestorCatalogo.normalizar_url(GestorCatalogo.normalizar_url("HTTP://x.com/")) == GestorCatalogo.normalizar_url("HTTP://x.com/"), "normalizar_url es idempotente")
	_check(GestorCatalogo.clave_unica("http://X.com/a") == GestorCatalogo.clave_unica("https://x.com/a"), "clave_unica unifica http y https")
	_check(GestorCatalogo.clave_unica("http://x.com/") == "x.com" and GestorCatalogo.clave_unica("https://x.com") == "x.com", "clave_unica ignora esquema y raíz")
	_check(GestorCatalogo.clave_unica("http://x.com/a/") == "x.com/a/" and GestorCatalogo.clave_unica("http://x.com/a/") != GestorCatalogo.clave_unica("http://x.com/a"), "clave_unica conserva el slash de subruta")
	_check(GestorCatalogo.clave_unica("http://x.com:80/a") == GestorCatalogo.clave_unica("http://x.com/a") and GestorCatalogo.clave_unica("http://x.com:8080/a") != GestorCatalogo.clave_unica("http://x.com/a"), "clave_unica ignora solo el puerto por defecto")
```

- [ ] **Step 2: Ejecutar y verificar que fallan (RED)**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_gestor_catalogo.gd 2>&1`
Expected: NO termina en `TESTS OK` — `Parse Error` (el script no existe aún: `normalizar_url`), es el estado RED esperado.

- [ ] **Step 3: Implementar `normalizar_url`, `clave_unica` y `separar`**

En `scripts/gestor_catalogo.gd`, añadir antes de `separar()`:

```gdscript
static func normalizar_url(url: String) -> String:
	var uri := url.strip_edges()
	var pos := uri.find("://")
	if pos == -1:
		return uri
	var esquema := uri.substr(0, pos).to_lower()
	if esquema != "http" and esquema != "https":
		return uri
	var resto := uri.substr(pos + 3)
	if resto.is_empty():
		return uri
	var hash := resto.find("#")
	if hash != -1:
		resto = resto.substr(0, hash)
	var host := resto
	var path := ""
	var barra := resto.find("/")
	if barra != -1:
		host = resto.substr(0, barra)
		path = resto.substr(barra)
	host = host.to_lower()
	if host.is_empty():
		return uri
	var dos := host.rfind(":")
	if dos != -1 and not host.begins_with("["):
		var puerto := host.substr(dos + 1)
		var por_defecto := (esquema == "http" and puerto == "80") or (esquema == "https" and puerto == "443")
		if por_defecto:
			host = host.substr(0, dos)
	if path == "/":
		path = ""
	return "%s://%s%s" % [esquema, host, path]


static func clave_unica(url: String) -> String:
	var normal := normalizar_url(url)
	var pos := normal.find("://")
	if pos == -1:
		return normal
	return normal.substr(pos + 3)
```

Reemplazar `separar()` completo:

```gdscript
static func separar(urls: Array, existentes: Array) -> Dictionary:
	var vistos := {}
	for u in existentes:
		if typeof(u) == TYPE_STRING:
			var c: String = normalizar_url(u)
			if not c.is_empty():
				vistos[clave_unica(c)] = true
	var nuevas: Array = []
	var repetidas: Array = []
	for u in urls:
		var nu: String = normalizar_url(u) if typeof(u) == TYPE_STRING else ""
		if nu.is_empty():
			continue
		if vistos.has(clave_unica(nu)):
			repetidas.append(nu)
		else:
			vistos[clave_unica(nu)] = true
			nuevas.append(nu)
	return {"nuevas": nuevas, "repetidas": repetidas}
```

- [ ] **Step 4: Ejecutar y verificar que pasan (GREEN)**

Run: el mismo comando del Step 2.
Expected: `TESTS OK`, EXIT 0, 32 checks OK.

- [ ] **Step 5: Smoke y commit**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" res://scenes/Main.tscn --quit-after 60 2>&1` y `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://scripts/main.gd --check-only 2>&1`
Expected: sin `Parse Error|SCRIPT ERROR|ERROR`.

```bash
git add scripts/gestor_catalogo.gd tests/test_gestor_catalogo.gd tests/test_gestor_catalogo.gd.uid
git commit -m "feat: normalizar_url y clave_unica en gestor_catalogo para deduplicar variantes de URL (#25)"
```

---

### Task 2: main.gd — migración y escrituras de entradas

**Files:**
- Modify: `scripts/main.gd` (`_cargar_datos` 147, `_url_existe` 285, `_on_enlace_guardado` 215, `_on_lote_guardado` 230, `_on_enlace_editado` 316)
- Modify: `tests/test_main_barra.gd`

**Interfaces:**
- Consumes: `normalizar_url`, `clave_unica`, `separar` canónico (Task 1).
- Produces: `_normalizar_urls()`, `_url_existente(url) -> String`; colisión por `clave_unica` en alta/lote/edición; remapeo de estados/borrados por `clave_unica`.

- [ ] **Step 1: Modificar los tests (RED → GREEN directo para lo nuevo; actualizar lo que rompe el contrato)**

En `tests/test_main_barra.gd`, añadir el preload al inicio (tras `LIST_ITEM_SCENE`):

```gdscript
const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
```

Actualizar el bloque de edición-remapeo (líneas 78-86) para las claves canónicas sin esquema:

- `main_script._estado_store = _FakeStore.new()` (sin cambio)
- Línea 79: `main_script._estados = {"a.test": {"valido": true, "mensaje": "OK (200)", "codigo": 200, "fecha": 1}}`
- Línea 80: `main_script._borrados = ["a.test"]`
- Línea 84: `_check(main_script._estados.has("a2.test") and not main_script._estados.has("a.test"), "editar remapea el estado en memoria")`
- Línea 85: `_check(main_script._borrados == ["a2.test"], "editar remapea los borrados en memoria")`
- Línea 86: `_check(main_script._estado_store.ultima_renombrar == ["a.test", "a2.test"], "editar pide el remapeo persistido al store")`

Añadir un bloque «Catálogo: normalización de URLs (#25)» tras el bloque de colisión de edición (tras la línea 102), antes del bloque de capturas:

```gdscript
	# Catálogo: normalización de URLs (#25)
	main_script._persistir = false
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "http://x.test", "img": ""}]
	main_script._on_enlace_guardado({"nombre": "B", "desc": "", "url": "https://X.test/", "img": ""})
	_check(main_script._entradas.size() == 1, "alta con https://X.test/ colisiona con http://x.test")
	_check(main.get_node("%Progreso").text == "Ya existe: http://x.test", "la colisión muestra la URL canónica existente")
	main_script._entradas = []
	main_script._on_lote_guardado(["HTTP://X.test/", "https://x.test"])
	_check(main_script._entradas.size() == 1, "el lote normaliza y deduplica variantes")
	_check(str(main_script._entradas[0].get("url", "")) == "http://x.test", "el lote guarda la URL canónica")
	main_script._entradas = [
		{"nombre": "A", "desc": "", "url": "http://a.test", "img": ""},
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": ""},
	]
	main_script._estados = {"a.test": {"valido": true, "mensaje": "OK (200)", "codigo": 200, "fecha": 1}}
	main_script._borrados = []
	ventana.abrir_edicion({"nombre": "A", "desc": "", "url": "http://a.test", "img": ""}, "http://a.test")
	ventana.get_node("%Url").text = "https://c.test/"
	ventana.get_node("%BotonGuardar").pressed.emit()
	_check(str(main_script._entradas[0].get("url", "")) == "http://a.test", "editar a una clave existente no modifica")
	_check(main.get_node("%Progreso").text == "Ya existe: https://c.test", "editar colisionado informa con la URL canónica")
	_check(ventana.visible, "editar colisionado reabre el diálogo")
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "HTTP://Migrada.TEST/", "img": ""}]
	main_script._estados = {"https://migrada.test": {"valido": true, "mensaje": "OK", "codigo": 200, "fecha": 1}, "http://migrada.test/": {"valido": false, "mensaje": "X", "codigo": 0, "fecha": 2}}
	main_script._borrados = ["https://migrada.test/", "https://migrada.test"]
	main_script._normalizar_urls()
	_check(str(main_script._entradas[0].get("url", "")) == "http://migrada.test", "la migración normaliza las URLs de las entradas")
	_check(main_script._estados.size() == 1 and main_script._estados.has("migrada.test"), "la migración colapsa los estados a clave única")
	_check(main_script._borrados == ["migrada.test"], "la migración re-aja y deduplica los borrados")
```

- [ ] **Step 2: Implementar la migración y normalizar las escrituras**

En `scripts/main.gd`:

En `_cargar_datos()` (líneas 152-163), el dedup base↔usuario pasa a `clave_unica`:

```gdscript
	if not usuario.is_empty():
		var urls := {}
		for entrada in _entradas:
			if typeof(entrada) == TYPE_DICTIONARY:
				urls[GestorCatalogoScript.clave_unica(str(entrada.get("url", "")))] = true
		for entrada in usuario:
			if typeof(entrada) != TYPE_DICTIONARY:
				continue
			var url := str(entrada.get("url", ""))
			if url.is_empty() or urls.has(GestorCatalogoScript.clave_unica(url)):
				continue
			_entradas.append(entrada)
			urls[GestorCatalogoScript.clave_unica(url)] = true
```

Tras cargar `_estados`/`_borrados` (línea 168) y **antes** del filtro, añadir la llamada; el filtro (líneas 169-173) pasa a:

```gdscript
	_normalizar_urls()
	_entradas = _entradas.filter(
		func(entrada: Variant) -> bool:
			return typeof(entrada) != TYPE_DICTIONARY \
				or not _borrados.has(GestorCatalogoScript.clave_unica(str(entrada.get("url", ""))))
	)
```

Añadir la migración junto a `_normalizar_categorias`:

```gdscript
func _normalizar_urls() -> void:
	var estados := {}
	for url_clave in _estados:
		estados[GestorCatalogoScript.clave_unica(str(url_clave))] = _estados[url_clave]
	_estados = estados
	var borrados_unicos := {}
	var borrados: Array = []
	for b in _borrados:
		var clave_b := GestorCatalogoScript.clave_unica(str(b))
		if clave_b.is_empty():
			continue
		if not borrados_unicos.has(clave_b):
			borrados_unicos[clave_b] = true
			borrados.append(clave_b)
	_borrados = borrados
	for entrada in _entradas:
		if typeof(entrada) == TYPE_DICTIONARY:
			entrada["url"] = GestorCatalogoScript.normalizar_url(str(entrada.get("url", "")))
```

Sustituir `_url_existe` (líneas 285-287) por un buscador que devuelve la URL canónica de la entrada colisionante:

```gdscript
func _url_existente(url: String) -> String:
	var clave := GestorCatalogoScript.clave_unica(url)
	for entrada in _entradas:
		if typeof(entrada) == TYPE_DICTIONARY:
			var c := GestorCatalogoScript.clave_unica(str(entrada.get("url", "")))
			if not c.is_empty() and c == clave:
				return str(entrada.get("url", ""))
	return ""
```

En `_on_enlace_guardado` (líneas 215-227), normalizar y usar el buscador:

```gdscript
func _on_enlace_guardado(datos: Dictionary) -> void:
	var url_nueva := GestorCatalogoScript.normalizar_url(str(datos.get("url", "")))
	var existente := _url_existente(url_nueva)
	if not existente.is_empty():
		progreso.text = "Ya existe: %s" % existente
		return
	datos["url"] = url_nueva
	datos["cat"] = GestorCatalogoScript.normalizar_categoria(datos.get("cat", "otro"))
	_entradas.append(datos)
	if not _guardar_datos():
		_entradas.pop_back()
		return
	_refrescar_vista()
	_actualizar_status()
	progreso.text = "Enlace agregado: %s" % datos.get("nombre", "")
```

En `_on_lote_guardado` (líneas 230-243), normalizar **antes** de validar esquema:

```gdscript
func _on_lote_guardado(urls: Array) -> void:
	var canonicas: Array = []
	for linea in urls:
		var u: String = GestorCatalogoScript.normalizar_url(linea.strip_edges() if typeof(linea) == TYPE_STRING else "")
		if not u.is_empty():
			canonicas.append(u)
	var validas: Array = []
	var invalidas: Array = []
	for u in canonicas:
		if u.begins_with("http://") or u.begins_with("https://"):
			validas.append(u)
		else:
			invalidas.append(u)
	var res := GestorCatalogoScript.separar(validas, _urls_existentes())
```

En `_on_enlace_editado` (líneas 316-342), normalizar la URL nueva y remapear por `clave_unica`:

```gdscript
func _on_enlace_editado(datos: Dictionary, url_original: String) -> void:
	var url_nueva := GestorCatalogoScript.normalizar_url(str(datos.get("url", "")))
	var indice := -1
	for i in range(_entradas.size()):
		if typeof(_entradas[i]) == TYPE_DICTIONARY and str(_entradas[i].get("url", "")) == url_original:
			indice = i
			break
	if indice == -1:
		progreso.text = "No se encontró el enlace."
		return
	var entrada: Dictionary = _entradas[indice]
	var img_anterior := str(entrada.get("img", ""))
	if url_nueva != url_original and not _cambios_url_validos(url_original, url_nueva):
		progreso.text = "Ya existe: %s" % url_nueva
		var datos_reabrir := datos.duplicate(true)
		datos_reabrir["img"] = img_anterior
		datos_reabrir.erase("img_pendiente")
		ventana_agregar.abrir_edicion(datos_reabrir, url_original)
		return
	if url_nueva != url_original:
		var clave_original := GestorCatalogoScript.clave_unica(url_original)
		var clave_nueva := GestorCatalogoScript.clave_unica(url_nueva)
		_estado_store.renombrar(clave_original, clave_nueva)
		if _estados.has(clave_original):
			_estados[clave_nueva] = _estados[clave_original]
			_estados.erase(clave_original)
		for i_b in range(_borrados.size()):
			if str(_borrados[i_b]) == clave_original:
				_borrados[i_b] = clave_nueva
```

El resto de `_on_enlace_editado` (imagen, campos, `entrada["url"] = url_nueva`, guardado) no cambia.

- [ ] **Step 3: Ejecutar y verificar GREEN**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd 2>&1`
Expected: `TESTS OK`, EXIT 0 (todo el bloque, con los checks actualizados y los 10 nuevos).

- [ ] **Step 4: Batería de scripts tocados + smoke y commit**

Run: `test_gestor_catalogo.gd` (Task 1) y `--check-only` sobre `scripts/main.gd` y smoke del Main.
Expected: sin `Parse Error|SCRIPT ERROR|ERROR`, `TESTS OK` en ambos.

```bash
git add scripts/main.gd tests/test_main_barra.gd tests/test_main_barra.gd.uid
git commit -m "feat: normalización de URLs en carga, alta, lote y edición de enlaces (#25)"
```

---

### Task 3: Estados, borrados, listado y contadores por clave única

**Files:**
- Modify: `scripts/main.gd` (`_on_item_terminado` 477, `_persistir_recompra` 511, `_confirmar_borrado` 534, `_mostrar_lista` 397)
- Modify: `scripts/gestor_contadores.gd`
- Modify: `tests/test_gestor_contadores.gd`, `tests/test_main_barra.gd`

**Interfaces:**
- Consumes: `clave_unica` (Task 1).
- Produces: claves de estados/borrados canónicas consistentes entre memoria, contadores y persistencia.

- [ ] **Step 1: Actualizar los tests (RED)**

En `tests/test_gestor_contadores.gd`, cambiar las claves de `estados` (líneas 18-21) a forma sin esquema y añadir un check de variantes tras el existente `repetida`:

```gdscript
	var estados := {
		"a.com": {"valido": false, "mensaje": "No existe (404)"},
		"b.com": {"valido": true, "mensaje": "OK (200)"},
	}
```
```gdscript
	var estados_unicos := {
		"x.com": {"valido": true, "mensaje": "OK (200)"},
		"y.com": {"valido": false, "mensaje": "No existe (404)"},
	}
	var variantes := ContadoresScript.contar([
		{"url": "http://x.com"},
		{"url": "https://x.com"},
		{"url": "https://y.com/"},
	], estados_unicos)
	_check(variantes.get("activos", -1) == 2 and variantes.get("rotos", -1) == 1, "clave única empareja variantes de la misma URL")
```

En `tests/test_main_barra.gd`:
- Bloque de recompra (línea 50): `var estado_memoria: Dictionary = main_script._estados.get(GestorCatalogoScript.clave_unica(item.url), {})`
- Bloque de recompra (línea 54): la limpieza pasa a clave canónica para no dejar residuos en `estados.json` del usuario: `main_script._estado_store.borrar_estado(GestorCatalogoScript.clave_unica(item.url))`
- Bloque de filtro/categorías (líneas 243-247): claves de `_estados` → sin esquema: `{"srv.test": {...}, "srv2.test": {...}, "cli.test": {...}}`. Las listas de `visibles`/`visibles_todas` (líneas 256 y 263) NO cambian (comparan `hijo.url` = URL canónica completa).

Run ambos tests.
Expected: FALLIDOS (`estados.get(item.url)` no encuentra la clave canónica) → RED.

- [ ] **Step 2: Implementar por `clave_unica`**

En `scripts/main.gd`, `_mostrar_lista` (línea 416):

```gdscript
		var estado: Dictionary = _estados.get(GestorCatalogoScript.clave_unica(url_item), {})
```

`_on_item_terminado` (líneas 483-485):

```gdscript
	if is_instance_valid(item):
		var clave_estado := GestorCatalogoScript.clave_unica(item.url)
		_estado_store.guardar_estado(clave_estado, item.valido == true, item.mensaje, item.codigo)
		_estados[clave_estado] = {"valido": item.valido == true, "mensaje": item.mensaje, "codigo": item.codigo, "fecha": ahora}
```

`_persistir_recompra` (líneas 514-516):

```gdscript
	var clave_estado := GestorCatalogoScript.clave_unica(item.url)
	_estado_store.guardar_estado(clave_estado, item.valido == true, item.mensaje, item.codigo)
	_estados[clave_estado] = {"valido": item.valido == true, "mensaje": item.mensaje, "codigo": item.codigo, "fecha": ahora}
```

`_confirmar_borrado` (líneas 540-542):

```gdscript
	var clave_estado := GestorCatalogoScript.clave_unica(item.url)
	_estado_store.marcar_borrado(clave_estado)
	_estado_store.borrar_estado(clave_estado)
	_estados.erase(clave_estado)
```

En `scripts/gestor_contadores.gd`, añadir el preload y cambiar el lookup:

```gdscript
extends RefCounted

const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
```
```gdscript
		var estado: Dictionary = estados.get(GestorCatalogoScript.clave_unica(str(entrada.get("url", ""))), {})
```

- [ ] **Step 3: Ejecutar y verificar GREEN**

Run: `tests/test_gestor_contadores.gd` (8 checks OK), `tests/test_main_barra.gd` (todo OK), `--check-only` sobre `scripts/gestor_contadores.gd` y `scripts/main.gd`.
Expected: `TESTS OK` en todos, sin errores de parseo.

- [ ] **Step 4: Batería de estado_store + smoke y commit**

Run: `tests/test_estado_store.gd` (regresión, 12 checks) y smoke del Main.
Expected: `TESTS OK`.

```bash
git add scripts/main.gd scripts/gestor_contadores.gd tests/test_gestor_contadores.gd tests/test_gestor_contadores.gd.uid tests/test_main_barra.gd tests/test_main_barra.gd.uid
git commit -m "feat: estados, borrados y contadores indexados por clave única de URL (#25)"
```

---

### Task 4: Ventana redimensionable (#32) e imágenes jpg aceptadas (#33) en el diálogo

**Files:**
- Modify: `scenes/AgregarEnlace.tscn`
- Modify: `scripts/agregar_enlace.gd`
- Modify: `tests/test_agregar_enlace.gd`

**Interfaces:**
- Consumes: nada del resto de tasks.
- Produces: `DialogoImagen.filters = PackedStringArray("*.png ; *.jpg ; *.jpeg ; *.webp")`; `_on_imagen_picked` rechaza decodificaciones fallidas con error visible y sin fijar `_imagen_ruta`.

- [ ] **Step 1: Modificar el test (RED)**

En `tests/test_agregar_enlace.gd`, añadir tras el último `abrir_edicion` de "Sin" (línea 119), antes del cierre:

```gdscript
	_check(not dialogo.unresizable, "la ventana de agregar es redimensionable (#32)")
	_check(dialogo.size.y >= 680, "la ventana de agregar tiene altura suficiente (#32)")

	var dialogo_imagen: FileDialog = dialogo.get_node("%DialogoImagen")
	_check(dialogo_imagen.filters.size() == 1 and dialogo_imagen.filters[0] == "*.png ; *.jpg ; *.jpeg ; *.webp", "el diálogo de imagen lista png, jpg, jpeg y webp (#33)")
	var jpg_prueba := ProjectSettings.globalize_path("user://__test_agregar_jpg__.jpg")
	var img := Image.create_empty(8, 8, false, Image.FORMAT_RGB8)
	img.fill(Color.BLUE)
	img.save_jpg(jpg_prueba, 0.9)
	dialogo._on_imagen_picked(jpg_prueba)
	_check(dialogo._imagen_ruta == jpg_prueba and dialogo.get_node("%VistaPrevia").texture != null, "seleccionar un jpg válido lo acepta (#33)")
	dialogo._on_imagen_picked(ProjectSettings.globalize_path("user://__no_existe__.png"))
	_check(dialogo._imagen_ruta == jpg_prueba and dialogo.get_node("%Error").text == "No se pudo cargar la imagen.", "un archivo no decodificable muestra error y no se acepta (#33)")
	DirAccess.remove_absolute(jpg_prueba)
```

- [ ] **Step 2: Ejecutar y verificar que fallan (RED)**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_agregar_enlace.gd 2>&1`
Expected: `TESTS FALLIDOS: 5` (el diálogo no es resizable, altura 520, filtros viejos y `_on_imagen_picked` actual acepta decodificación fallida).

- [ ] **Step 3: Implementar escena y script**

En `scenes/AgregarEnlace.tscn`, nodo `VentanaAgregar` (líneas 6-13); en Godot 4.7.2 `Window` no expone `resizable`, solo `unresizable` (el valor en el archivo es `unresizable = true`):

```
[node name="VentanaAgregar" type="Window"]
title = "Agregar enlace"
initial_position = 2
size = Vector2i(540, 680)
unresizable = false
exclusive = true
visible = false
script = ExtResource("1_agregar")
```

Nodo `DialogoImagen` (línea 158), un único filtro bien formado:

```
filters = PackedStringArray("*.png ; *.jpg ; *.jpeg ; *.webp")
```

En `scripts/agregar_enlace.gd`, reemplazar `_on_imagen_picked` (líneas 121-125):

```gdscript
func _on_imagen_picked(ruta: String) -> void:
	var img := Image.load_from_file(ruta)
	if img == null or img.is_empty():
		error_label.text = "No se pudo cargar la imagen."
		return
	_imagen_ruta = ruta
	_quitar_imagen = false
	vista_previa.texture = ImageTexture.create_from_image(img)
```

- [ ] **Step 4: Ejecutar y verificar GREEN**

Run: el mismo comando del Step 2.
Expected: `TESTS OK`, EXIT 0, 30 checks.

- [ ] **Step 5: Smoke y commit**

Run: smoke del Main (carga `AgregarEnlace.tscn`).
Expected: sin `Parse Error|SCRIPT ERROR|ERROR`.

```bash
git add scenes/AgregarEnlace.tscn scripts/agregar_enlace.gd tests/test_agregar_enlace.gd tests/test_agregar_enlace.gd.uid
git commit -m "fix: ventana de agregar redimensionable y diálogo de imagen que acepta jpg/jpeg/webp (#32, #33)"
```

---

### Task 5: gestor_imagenes por formato y limpieza en ambas carpetas

**Files:**
- Modify: `scripts/gestor_imagenes.gd` (`copiar` 4, `limpiar_huerfanas` 35)
- Modify: `scripts/main.gd` (`_borrar_captura_si_huerfana` 367, guard de `_confirmar_borrado` 551)
- Modify: `tests/test_gestor_imagenes.gd`, `tests/test_main_barra.gd`

**Interfaces:**
- Consumes: nada.
- Produces: `copiar(origen)` según extensión (png, webp→png, jpg/jpeg→jpg, otras→"Formato no soportado."); `limpiar_huerfanas` cubre `Assets/png` y `Assets/jpg`.

- [ ] **Step 1: Actualizar los tests (RED)**

En `tests/test_gestor_imagenes.gd`, añadir antes del cierre (`if _fallos == 0`, línea 81):

```gdscript
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Assets/jpg"))
	var origen_jpg := BASE + "/origen.jpg"
	var img_j := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	img_j.fill(Color.VIOLET)
	img_j.save_jpg(origen_jpg, 0.9)
	var rj: Dictionary = GestorImagenesScript.copiar(origen_jpg)
	var destino_j := str(rj.get("destino", ""))
	_check(rj.get("ok", false) and destino_j.begins_with("res://Assets/jpg/img_") and destino_j.ends_with(".jpg"), "copiar jpg guarda en Assets/jpg con extensión .jpg")
	_check(FileAccess.file_exists(destino_j) and not Image.load_from_file(destino_j).is_empty(), "el jpg copiado existe y se decodifica")
	if FileAccess.file_exists(destino_j):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destino_j))

var origen_jpeg := BASE + "/origen.jpeg"
 	img_j.save_jpg(origen_jpeg, 0.9)
	var rjpeg: Dictionary = GestorImagenesScript.copiar(origen_jpeg)
	_check(str(rjpeg.get("destino", "")).begins_with("res://Assets/jpg/img_") and str(rjpeg.get("destino", "")).ends_with(".jpg"), "copiar jpeg también termina en .jpg")

	var origen_webp := BASE + "/origen.webp"
	img_j.save_webp(origen_webp, false)
	var rw: Dictionary = GestorImagenesScript.copiar(origen_webp)
	var destino_w := str(rw.get("destino", ""))
	_check(rw.get("ok", false) and destino_w.begins_with("res://Assets/png/img_") and destino_w.ends_with(".png") and not Image.load_from_file(destino_w).is_empty(), "copiar webp lo reconvierte a png en Assets/png")
	if FileAccess.file_exists(destino_w):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destino_w))

	var r_ext: Dictionary = GestorImagenesScript.copiar(BASE + "/origen.gif")
	_check(not r_ext.get("ok", true) and str(r_ext.get("error", "")).contains("Formato no soportado."), "extensión desconocida no se copia")

	var jpg_ref := "res://Assets/jpg/img_test_ref.jpg"
	var jpg_huerfana := "res://Assets/jpg/img_test_huerfana.jpg"
	img_j.save_jpg(ProjectSettings.globalize_path(jpg_ref), 0.9)
	img_j.save_jpg(ProjectSettings.globalize_path(jpg_huerfana), 0.9)
	var rl_j := GestorImagenesScript.limpiar_huerfanas([jpg_ref])
	_check(rl_j.get("ok", false) and int(rl_j.get("borradas", -1)) == 1 and FileAccess.file_exists(ProjectSettings.globalize_path(jpg_ref)) and not FileAccess.file_exists(ProjectSettings.globalize_path(jpg_huerfana)), "limpiar_huerfanas elimina la jpg no referida y conserva la referida")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(jpg_ref))
```

En `tests/test_main_barra.gd`, tras `_limpiar_capturas()` (línea 173), añadir:

```gdscript
	# Catálogo: captura jpg huérfana se borra / se conserva (#33)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Assets/jpg"))
	var jpg_borra := "res://Assets/jpg/img_test_borrable.jpg"
	var img_j2 := Image.create_empty(4, 4, false, Image.FORMAT_RGB8)
	img_j2.fill(Color.BLUE)
	img_j2.save_jpg(ProjectSettings.globalize_path(jpg_borra), 0.9)
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": "res://Assets/png/img_test_otra.png"}]
	main_script._borrar_captura_si_huerfana(jpg_borra)
	_check(not FileAccess.file_exists(ProjectSettings.globalize_path(jpg_borra)), "captura jpg no referenciada se borra (#33)")
	var jpg_ref2 := "res://Assets/jpg/img_test_referida.jpg"
	img_j2.save_jpg(ProjectSettings.globalize_path(jpg_ref2), 0.9)
	main_script._entradas[0]["img"] = jpg_ref2
	main_script._borrar_captura_si_huerfana(jpg_ref2)
	_check(FileAccess.file_exists(ProjectSettings.globalize_path(jpg_ref2)), "captura jpg referenciada se conserva (#33)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(jpg_ref2))
```

Run `tests/test_gestor_imagenes.gd` y `tests/test_main_barra.gd`.
Expected: los checks nuevos fallan (`copiar` no ruta, `limpiar_huerfanas` solo png, guard sin jpg) → RED. Los checks de `copiar`/`limpiar` png existentes deben seguir pasando.

- [ ] **Step 2: Implementar `copiar` y `limpiar_huerfanas`**

Reemplazar `scripts/gestor_imagenes.gd` completo:

```gdscript
extends RefCounted


static func copiar(origen: String) -> Dictionary:
	if origen.is_empty():
		return {"ok": true, "destino": "", "error": ""}

	var ext := origen.get_extension().to_lower()
	var carpeta: String
	var sufijo: String
	match ext:
		"png", "webp":
			carpeta = "res://Assets/png"
			sufijo = ".png"
		"jpg", "jpeg":
			carpeta = "res://Assets/jpg"
			sufijo = ".jpg"
		_:
			return {"ok": false, "destino": "", "error": "Formato no soportado."}

	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta))
	if err != OK:
		return {"ok": false, "destino": "", "error": "No se pudo crear la carpeta de imágenes."}

	var destino := "%s/img_%d%s" % [carpeta, int(Time.get_unix_time_from_system()), sufijo]
	var img: Image = Image.load_from_file(origen)
	if img == null or img.is_empty():
		return {"ok": false, "destino": "", "error": "No se pudo copiar la imagen."}
	const ANCHO_MAX := 800
	if img.get_width() > ANCHO_MAX:
		var alto := maxi(1, int(float(img.get_height()) * ANCHO_MAX / float(img.get_width())))
		img.resize(ANCHO_MAX, alto, Image.INTERPOLATE_CUBIC)
	var ok: Error = img.save_png(ProjectSettings.globalize_path(destino)) if ext in ["png", "webp"] else img.save_jpg(ProjectSettings.globalize_path(destino), 0.9)
	if ok != OK:
		return {"ok": false, "destino": "", "error": "No se pudo copiar la imagen."}
	return {"ok": true, "destino": destino, "error": ""}


static func borrar(ruta: String) -> Dictionary:
	if ruta.is_empty():
		return {"ok": false, "error": "Ruta vacía."}
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	if err == OK:
		return {"ok": true, "error": ""}
	return {"ok": false, "error": "No se pudo borrar la captura."}


static func limpiar_huerfanas(referidas: Array) -> Dictionary:
	var referidas_str: Array = []
	for r in referidas:
		referidas_str.append(str(r))
	var borradas := 0
	var errores := 0
	for patron in [["res://Assets/png", "png"], ["res://Assets/jpg", "jpg"]]:
		var carpeta_patron: String = patron[0]
		var ext: String = patron[1]
		var carpeta := DirAccess.open(carpeta_patron)
		if carpeta == null:
			continue
		for f in carpeta.get_files():
			if not (f.begins_with("img_") and f.ends_with(".%s" % ext)):
				continue
			var ruta := "%s/%s" % [carpeta_patron, f]
			if ruta in referidas_str:
				continue
			if borrar(ruta).get("ok", false):
				borradas += 1
			else:
				errores += 1
	return {"ok": true, "borradas": borradas, "errores": errores}
```

- [ ] **Step 3: Extender las guardas en main.gd**

`_borrar_captura_si_huerfana` (líneas 367-369):

```gdscript
func _borrar_captura_si_huerfana(ruta: String) -> void:
	if not (ruta.begins_with("res://Assets/png/") or ruta.begins_with("res://Assets/jpg/")):
		return
```

Guard de borrado directo en `_confirmar_borrado` (línea 551):

```gdscript
	if (imagen_borrada.begins_with("res://Assets/png/") or imagen_borrada.begins_with("res://Assets/jpg/")) and imagen_borrada != "res://Assets/png/no-disponible.png":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(imagen_borrada))
```

- [ ] **Step 4: Ejecutar y verificar GREEN**

Run: `tests/test_gestor_imagenes.gd` (19 checks OK) y `tests/test_main_barra.gd` (todo OK), `--check-only` sobre `scripts/gestor_imagenes.gd`.
Expected: `TESTS OK`, sin errores de parseo.

- [ ] **Step 5: Smoke y commit**

Run: smoke del Main.
Expected: sin `Parse Error|SCRIPT ERROR|ERROR`.

```bash
git add scripts/gestor_imagenes.gd scripts/main.gd tests/test_gestor_imagenes.gd tests/test_gestor_imagenes.gd.uid tests/test_main_barra.gd tests/test_main_barra.gd.uid
git commit -m "feat: copiado de imágenes por formato (jpg/jpeg en Assets/jpg, webp a png) y limpieza en ambas carpetas (#33)"
```

---

## Verificación final (todo el ciclo)

Run:
```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_gestor_catalogo.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_gestor_imagenes.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_agregar_enlace.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_gestor_contadores.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_estado_store.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_list_item.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_preferencias.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_link_checker_timeout.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_config_store.gd 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://scripts/main.gd --check-only 2>&1
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" res://scenes/Main.tscn --quit-after 60 2>&1
```
Expected: 10× `TESTS OK` (32+71+19+30+8+12+21+4+4+5 = 206 checks), ningún `Parse Error|SCRIPT ERROR|ERROR`.

Verificación manual (la hace el implementador): abrir la ventana Agregar enlace → botón Guardar visible sin redimensionar (#32); seleccionar un `.JPG` real del sistema → aparece la vista previa y se guarda como `Assets/jpg/img_*.jpg` (#33); probar un `.JPG` no decodificable (renombrado) → error visible "No se pudo cargar la imagen.". Confirmar `data/data.json.bak` y `data/data2.json` intactos.

Limpieza: eliminar `tests/diag_jpg.gd` (scratch de diagnóstico) y su `.uid` si existiera, antes del push. Push y cierre de issues #25, #32, #33.

Criterios de aceptación del spec cubiertos: helpers y `separar` (Task 1), migración y escrituras (Task 2), estados/borrados/contadores (Task 3), ventana y diálogo (Task 4), imágenes y carpetas (Task 5), regresión (verificación final).