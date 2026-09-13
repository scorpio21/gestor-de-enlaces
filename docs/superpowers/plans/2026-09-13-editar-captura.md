# Cambiar o quitar la captura de un enlace existente (#20) — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir cambiar o borrar la capture de un enlace existente en el diálogo de edición, moviendo toda la I/O de imágenes (copiar/borrar) de `agregar_enlace.gd` a `main.gd`, que decide tras el chequeo de colisión y junto a la persistencia.

**Architecture:** El diálogo pasa a ser un formulario puro en modo editar: reporta `datos["img"]` (ruta original, `""` si se quita) y, si se eligió imagen nueva, `datos["img_pendiente"]` con la ruta fuente. `main._on_enlace_editado()` resuelve el `destino` (copiando desde `img_pendiente` solo tras pasar la colisión de URL), persiste, y borra la captura vieja con `_borrar_captura_si_huerfana()` (guarda de convención `res://Assets/png/img_*` + de captura compartida). En colisión, reabre el diálogo con `img` = imagen original.

**Tech Stack:** Godot 4.7.2 (GDScript), `SceneTree`-based headless test harness.

## Global Constraints

- Sin `class_name` nuevo: usar `const X := preload("res://scripts/...")`.
- Scripts de producción sin comentarios; los tests pueden llevar comentarios de sección `# Catálogo:` / `# Imágenes:`.
- UI en español; mensajes de barra exactos según spec (idioma y texto verbatim).
- Harness `tests/*.gd`: `extends SceneTree`, `func _initialize()` → `_arrancar()`, `_check(condicion, etiqueta)` imprime `  OK:` o `push_error("FALLO: ...")`, y termina con `TESTS OK` + `quit(0)` o `TESTS FALLIDOS: N` + `quit(1)`.
- Comando de tests (desde la raíz `K:\gestor-de-enlaces`, pwsh):
  `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" -s tests/<archivo>.gd`
- Si Godot 4.7.2 queja "Cannot infer the type", tipar explícito (p. ej. `var linea: String`).
- No tocar untracked protegidos: `data/data.json.bak`, `data/data2.json` y este propio fichero del plan.
- `tests/test_list_item.gd` puede emitir "RID allocations leaked at exit" → ruido del harness, no fallo.
- `tests/test_gestor_imagenes.gd` puede emitir ERRORes de imagen inexistente → son casos de error del propio test.
- Base de trabajo: commit `c84af7b` (spec ya commiteada). Commits directos a `main` (igual que el plan anterior).

---

### Task 1: `gestor_imagenes.borrar()` + unit tests

**Files:**
- Modify: `scripts/gestor_imagenes.gd:19` (añadir función tras `copiar`)
- Test: `tests/test_gestor_imagenes.gd:34` (insertar antes del bloque final de fallos)

**Interfaces:**
- Produces: `static func borrar(ruta: String) -> Dictionary` — `ruta` vacía → `{"ok": false, "error": "Ruta vacía."}`; si no, `DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))`; `OK` → `{"ok": true, "error": ""}`, si no `{"ok": false, "error": "No se pudo borrar la captura."}`.

- [ ] **Step 1: Write the failing test**

Añadir al final de `func _arrancar()` en `tests/test_gestor_imagenes.gd`, justo antes del bloque `if _fallos == 0:`:

```gdscript
	var a_borrar := BASE + "/a-borrar.png"
	var img_b := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	img_b.fill(Color.RED)
	img_b.save_png(a_borrar)
	var rb := GestorImagenesScript.borrar(a_borrar)
	_check(rb.get("ok", false) and not FileAccess.file_exists(a_borrar), "borrar elimina el archivo real")
	_check(FileAccess.file_exists(BASE + "/origen.png"), "borrar no afecta a otros archivos")
	_check(not GestorImagenesScript.borrar("").get("ok", true), "borrar con ruta vacía devuelve fallo")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" -s tests/test_gestor_imagenes.gd`
Expected: `FALLO: borrar elimina el archivo real` (Invalid call — `borrar` no existe), `TESTS FALLIDOS: 1`.

- [ ] **Step 3: Write minimal implementation**

En `scripts/gestor_imagenes.gd`, tras el final de `copiar` (fin de archivo):

```gdscript
static func borrar(ruta: String) -> Dictionary:
	if ruta.is_empty():
		return {"ok": false, "error": "Ruta vacía."}
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	if err == OK:
		return {"ok": true, "error": ""}
	return {"ok": false, "error": "No se pudo borrar la captura."}
```

- [ ] **Step 4: Run test to verify it passes**

Run igual que Step 2.
Expected: 8 líneas `  OK:` (5 previas + 3 nuevas) y `TESTS OK`.

- [ ] **Step 5: Commit**

```bash
git add scripts/gestor_imagenes.gd tests/test_gestor_imagenes.gd
git commit -m "feat: gestor_imagenes.borrar elimina una captura (#20)"
```

---

### Task 2: Diálogo — contrato `img_pendiente` en modo editar

**Files:**
- Modify: `scripts/agregar_enlace.gd:148-163` (`_on_guardar`, tramo de imagen + datos)
- Test: `tests/test_agregar_enlace.gd:82` (insertar tras "editar conserva los campos no modificados")

**Interfaces:**
- Consumes: nada (gestor_imagenes seguirá preload en el diálogo para el camino de alta).
- Produces: en modo `editar`, `editado(datos, url_original)` con `datos["img"]` = `_imagen_original`, o `""` si `_quitar_imagen`/imagen nueva; si imagen nueva además `datos["img_pendiente"] = _imagen_ruta`. Firma de `editado` sin cambios.

- [ ] **Step 1: Write the failing test**

Añadir en `tests/test_agregar_enlace.gd`, justo después de la línea `_check(emitido.get("nombre") == "A", "editar conserva los campos no modificados")`:

```gdscript
	dialogo.abrir_edicion({"nombre": "S", "desc": "D", "url": "https://s.com", "img": ""}, "https://s.com")
	emitido = {}
	url_original_emitida = ""
	var fuente_rara := ProjectSettings.globalize_path("res://__fuente_inexistente__.png")
	dialogo._imagen_ruta = fuente_rara
	dialogo.get_node("%BotonGuardar").pressed.emit()
	_check(emitido.get("img") == "" and emitido.get("img_pendiente") == fuente_rara, "editar con imagen nueva emite img vacío e img_pendiente")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" -s tests/test_agregar_enlace.gd`
Expected: `FALLO: editar con imagen nueva emite img vacío e img_pendiente` y `TESTS FALLIDOS: 1` (hoy el diálogo va al `error_label` al fallar el copiado y no emite). Este paso NO copia archivos (fuente inexistente → `error_label`, sin I/O).

- [ ] **Step 3: Write minimal implementation**

En `scripts/agregar_enlace.gd`, sustituir el tramo de `var img_final := _imagen_original` ... `return` ... `img_final = str(resultado.get("destino", ""))` y el bloque de `datos` por:

```gdscript
	var img_final := _imagen_original
	if _quitar_imagen:
		img_final = ""
	elif _imagen_ruta != "":
		if _modo == "editar":
			img_final = ""
		else:
			var resultado := GestorImagenesScript.copiar(_imagen_ruta)
			if not resultado.get("ok", false):
				error_label.text = str(resultado.get("error", "No se pudo copiar la imagen."))
				return
			img_final = str(resultado.get("destino", ""))

	var datos := {"nombre": n, "desc": d, "url": u, "img": img_final}
	if _modo == "editar" and _imagen_ruta != "" and not _quitar_imagen:
		datos["img_pendiente"] = _imagen_ruta
	hide()
	if _modo == "editar":
		editado.emit(datos, _url_original)
	else:
		guardado.emit(datos)
```

Resultado: en modo editar el diálogo ya no copia; en alta individual (`_modo == "individual"`) copia igual que hoy.

- [ ] **Step 4: Run test to verify it passes**

Run igual que Step 2.
Expected: 19 líneas `  OK:` (18 previas + 1 nueva) y `TESTS OK`.

- [ ] **Step 5: Commit**

```bash
git add scripts/agregar_enlace.gd tests/test_agregar_enlace.gd
git commit -m "feat: el diálogo reporta img_pendiente en modo editar sin copiar (#20)"
```

---

### Task 3: `main` copia/borra tras el chequeo de colisión + tests de integración

**Files:**
- Modify: `scripts/main.gd:9` (preload), `scripts/main.gd:249-283` (`_on_enlace_editado`), y añadir `_borrar_captura_si_huerfana` tras `_on_enlace_editado`
- Test: `tests/test_main_barra.gd` (helpers + bloque de capturas)

**Interfaces:**
- Consumes: `GestorImagenesScript.copiar(origen) -> Dictionary` y `GestorImagenesScript.borrar(ruta) -> Dictionary` (Task 1); `datos["img_pendiente"]` opcional (Task 2).
- Produces: `_on_enlace_editado(datos, url_original)` y `_borrar_captura_si_huerfana(ruta)`.

- [ ] **Step 1: Write the failing test**

En `tests/test_main_barra.gd`:

a) Añadir la variable miembro tras `var _fallos := 0`:

```gdscript
var _imgs_iniciales: Array = []
```

b) Añadir estos helpers justo antes de `func _cerrar()`:

```gdscript
func _crear_captura(nombre: String) -> String:
	var ruta := "res://Assets/png/%s" % nombre
	var img := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.MAGENTA)
	if img.save_png(ProjectSettings.globalize_path(ruta)) != OK:
		return ""
	return ruta


func _listar_capturas() -> Array:
	var carpeta := DirAccess.open("res://Assets/png")
	if carpeta == null:
		return []
	var lista: Array = []
	for f in carpeta.get_files():
		if f.begins_with("img_") and f.ends_with(".png"):
			lista.append(f)
	lista.sort()
	return lista


func _limpiar_capturas() -> void:
	var carpeta := DirAccess.open("res://Assets/png")
	if carpeta == null:
		return
	for f in _listar_capturas():
		if f not in _imgs_iniciales:
			carpeta.remove(f)
```

`_limpiar_capturas` solo borra capturas creadas durante el test (las `img_*` nuevas o `img_test_*`); nunca toca capturas previas reales.

c) En `func _arrancar()`, insertar este bloque completo justo después del bloque `# Catálogo: edición con colisión de URL no modifica` (tras la línea `_check(ventana.visible, "editar con colisión reabre el diálogo")`) y antes del bloque `# Catálogo: copiar URL desde la fila...`:

```gdscript
	# Catálogo: capturas (cambiar / quitar / compartir)
	main_script._persistir = false
	_imgs_iniciales = _listar_capturas()
	var fuente := ProjectSettings.globalize_path("res://Assets/png/no-disponible.png")
	var no_existe := ProjectSettings.globalize_path("res://Assets/png/__inexistente__.png")

	# 1) cambiar captura: destino nuevo y archivo viejo borrado
	var vieja1 := _crear_captura("img_test_old1.png")
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": vieja1}]
	ventana.abrir_edicion({"nombre": "A", "desc": "", "url": "https://a.test", "img": vieja1}, "https://a.test")
	ventana._imagen_ruta = fuente
	ventana.get_node("%BotonGuardar").pressed.emit()
	var img_nueva := str(main_script._entradas[0].get("img", ""))
	_check(img_nueva != vieja1 and img_nueva.begins_with("res://Assets/png/img_"), "cambiar captura apunta a un img_*.png nuevo")
	_check(not FileAccess.file_exists(ProjectSettings.globalize_path(vieja1)), "cambiar captura borra el archivo viejo")

	# 2) quitar captura: img vacío y archivo viejo borrado
	var vieja2 := _crear_captura("img_test_old2.png")
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": vieja2}]
	ventana.abrir_edicion({"nombre": "A", "desc": "", "url": "https://a.test", "img": vieja2}, "https://a.test")
	ventana.get_node("%BotonQuitar").pressed.emit()
	ventana.get_node("%BotonGuardar").pressed.emit()
	_check(str(main_script._entradas[0].get("img", "")) == "", "quitar captura deja img vacío")
	_check(not FileAccess.file_exists(ProjectSettings.globalize_path(vieja2)), "quitar captura borra el archivo viejo")

	# 3) editar sin tocar la imagen: archivo conservado e img intacto
	var vieja3 := _crear_captura("img_test_old3.png")
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": vieja3}]
	ventana.abrir_edicion({"nombre": "A", "desc": "", "url": "https://a.test", "img": vieja3}, "https://a.test")
	ventana.get_node("%BotonGuardar").pressed.emit()
	_check(str(main_script._entradas[0].get("img", "")) == vieja3, "editar sin tocar imagen conserva img")
	_check(FileAccess.file_exists(ProjectSettings.globalize_path(vieja3)), "editar sin tocar imagen conserva el archivo")

	# 4) colisión de URL con imagen nueva: sin archivos nuevos y reabre con la original
	var vieja4 := _crear_captura("img_test_old4.png")
	main_script._entradas = [
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": vieja4},
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": ""},
	]
	var antes4 := _listar_capturas()
	ventana.abrir_edicion({"nombre": "A", "desc": "", "url": "https://a.test", "img": vieja4}, "https://a.test")
	ventana._imagen_ruta = fuente
	ventana.get_node("%Url").text = "https://c.test"
	ventana.get_node("%BotonGuardar").pressed.emit()
	_check(_listar_capturas() == antes4, "colisión con imagen nueva no crea archivos")
	_check(main_script._entradas[0].get("img") == vieja4, "colisión con imagen nueva no toca la entrada")
	_check(ventana._imagen_original == vieja4, "colisión con imagen nueva reabre con la imagen original")

	# 5) captura compartida: no se borra al quitar en un enlace
	var vieja5 := _crear_captura("img_test_old5.png")
	main_script._entradas = [
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": vieja5},
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": vieja5},
	]
	ventana.abrir_edicion({"nombre": "A", "desc": "", "url": "https://a.test", "img": vieja5}, "https://a.test")
	ventana.get_node("%BotonQuitar").pressed.emit()
	ventana.get_node("%BotonGuardar").pressed.emit()
	_check(FileAccess.file_exists(ProjectSettings.globalize_path(vieja5)), "captura compartida no se borra al quitar")
	_check(str(main_script._entradas[0].get("img", "")) == "" and str(main_script._entradas[1].get("img", "")) == vieja5, "captura compartida solo se desreferencia en el enlace editado")

	# 6) copiar fallido (fuente inexistente): barra de error y entrada intacta
	var vieja6 := _crear_captura("img_test_old6.png")
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": vieja6}]
	ventana.abrir_edicion({"nombre": "A", "desc": "", "url": "https://a.test", "img": vieja6}, "https://a.test")
	ventana._imagen_ruta = no_existe
	ventana.get_node("%BotonGuardar").pressed.emit()
	_check(main_script._entradas[0].get("img") == vieja6, "copiar fallido deja la entrada intacta")
	_check(main.get_node("%Progreso").text == "No se pudo procesar la imagen.", "copiar fallido informa en la barra")

	_limpiar_capturas()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" -s tests/test_main_barra.gd`
Expected: varios `FALLO:` (p. ej. "cambiar captura borra el archivo viejo", "colisión con imagen nueva reabre con la imagen original") y `TESTS FALLIDOS: N`. De carácter inclusivo: pueden quedar archivos `img_test_*` creados por el test a mitad de la corrida (se limpian en la corrida verde).

- [ ] **Step 3: Write minimal implementation**

a) Añadir el preload en `scripts/main.gd:9`, tras `const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")`:

```gdscript
const GestorImagenesScript := preload("res://scripts/gestor_imagenes.gd")
```

b) Sustituir TODO `func _on_enlace_editado(datos: Dictionary, url_original: String) -> void:` de `scripts/main.gd` (líneas 249-283) por:

```gdscript
func _on_enlace_editado(datos: Dictionary, url_original: String) -> void:
	var url_nueva := str(datos.get("url", ""))
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
		_estado_store.renombrar(url_original, url_nueva)
		if _estados.has(url_original):
			_estados[url_nueva] = _estados[url_original]
			_estados.erase(url_original)
		for i_b in range(_borrados.size()):
			if str(_borrados[i_b]) == url_original:
				_borrados[i_b] = url_nueva
	var destino := str(datos.get("img", ""))
	if datos.has("img_pendiente"):
		var resultado := GestorImagenesScript.copiar(str(datos["img_pendiente"]))
		if not resultado.get("ok", false):
			progreso.text = "No se pudo procesar la imagen."
			return
		destino = str(resultado.get("destino", ""))
	entrada["nombre"] = str(datos.get("nombre", ""))
	entrada["desc"] = str(datos.get("desc", ""))
	entrada["url"] = url_nueva
	entrada["img"] = destino
	if not _guardar_datos():
		_cargar_datos()
		_refrescar_vista()
		progreso.text = "No se pudo guardar el enlace."
		return
	if destino != img_anterior:
		_borrar_captura_si_huerfana(img_anterior)
	_refrescar_vista()
	_actualizar_status()
	progreso.text = "Enlace actualizado: %s" % str(datos.get("nombre", ""))
```

Nota: en la colisión el dialogo recibe `datos_reabrir` (copia profunda) con `img` restaurado a la imagen original; `abrir_edicion` lo usa como precarga (`_imagen_original`), por lo que el test 4 puede leer `ventana._imagen_original`.

c) Añadir el helper justo después de `_on_enlace_editado` (antes de `_refrescar_vista`):

```gdscript
func _borrar_captura_si_huerfana(ruta: String) -> void:
	if not ruta.begins_with("res://Assets/png/"):
		return
	if not ruta.get_file().begins_with("img_"):
		return
	for entrada in _entradas:
		if typeof(entrada) == TYPE_DICTIONARY and str(entrada.get("img", "")) == ruta:
			return
	GestorImagenesScript.borrar(ruta)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" -s tests/test_main_barra.gd`
Expected: 46 líneas `  OK:` y `TESTS OK`.

- [ ] **Step 5: Batería completa (regresión)**

Run (en paralelo desde pwsh):

```pwsh
$godot = "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path "K:\gestor-de-enlaces" -s tests/test_config_store.gd
& $godot --headless --path "K:\gestor-de-enlaces" -s tests/test_gestor_contadores.gd
& $godot --headless --path "K:\gestor-de-enlaces" -s tests/test_gestor_imagenes.gd
& $godot --headless --path "K:\gestor-de-enlaces" -s tests/test_preferencias.gd
& $godot --headless --path "K:\gestor-de-enlaces" -s tests/test_estado_store.gd
& $godot --headless --path "K:\gestor-de-enlaces" -s tests/test_link_checker_timeout.gd
& $godot --headless --path "K:\gestor-de-enlaces" -s tests/test_list_item.gd
& $godot --headless --path "K:\gestor-de-enlaces" -s tests/test_main_barra.gd
& $godot --headless --path "K:\gestor-de-enlaces" -s tests/test_gestor_catalogo.gd
& $godot --headless --path "K:\gestor-de-enlaces" -s tests/test_agregar_enlace.gd
```

Expected: 11 suites terminan cada una con `TESTS OK` (test_main_barra con 46 checks, test_gestor_imagenes con 8, test_agregar_enlace con 19, resto con sus conteos previos). Smokes opcionales:
`& $godot --headless --path "K:\gestor-de-enlaces" --check-only --quit-after 120` (exit 0) y `& $godot --headless --path "K:\gestor-de-enlaces" res://scenes/Main.tscn --quit-after 5` (exit 0).

- [ ] **Step 6: Commit**

```bash
git add scripts/main.gd tests/test_main_barra.gd
git commit -m "feat: main copia o borra la captura al editar y reabre con la original en colisión (#20)"
```

---

## Self-Review (escribir el plan contra la spec)

**Cobertura de la spec:**
- Diálogo modo editar (img original/quitar/img_pendiente, sin `copiar()`) → Task 2.
- `gestor_imagenes.borrar` con convención exacta → Task 1.
- `_on_enlace_editado` pasos 1-8 (colisión sin I/O + reapertura con imagen original, destino por `img_pendiente`, persistencia fallida, borrado si cambió) → Task 3.
- `_borrar_captura_si_huerfana` (convención `res://Assets/png/img_*` + captura compartida) → Task 3c.
- Tabla de errores: caso 1 → Task 3 paso 6 de main + test 6; caso persistencia fallida → código (message) cubierto; compartida → test 5; fuera de convención → guarda en helper; sin tocar → test 3; colisión con imagen nueva → test 4. ✓
- Pruebas spec: gestor_imagenes 5→8 → Task 1; main_barra 34→~40 (46 reales, incluye los 6 bullets del spec; el ~ permitía holgura) → Task 3. test_agregar_enlace pasa de 18 a 19 con un check del CONTRATO nuevo de edición (la spec decía "inalterado" porque el camino de alta no cambia; el check añadido solo cubre el contrato `img_pendiente` que la spec define, no modifica los checks existentes del alta).
- Fuera de alcance (#21/#22, alta duplicada) → no tocado. ✓

**Placeholder scan:** sin TBD/TODO; todo paso lleva código verbatim extraído de los fuentes actuales.

**Consistencia de tipos:** `borrar`/`copiar` → `Dictionary` en ambos usos (Task 1 ≠ Task 3 unificados con `GestorImagenesScript`); clave `img_pendiente` (String) idéntica en Task 2 y 3; `datos_reabrir.erase("img_pendiente")` coherente. `_imagen_original` (String) = precarga de `abrir_edicion`, del cual el test 4 lee `ventana._imagen_original`. ✓