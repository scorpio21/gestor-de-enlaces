# #11 Informe de disponibilidad (CSV/HTML) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir exportar un informe de disponibilidad de todo el catálogo en CSV (Excel) o HTML desde el menú Archivo.

**Architecture:** Nuevo `scripts/informe_store.gd` (RefCounted, estáticas `exportar_csv`/`exportar_html`) que recibe ya la lista de filas y escribe el fichero. `main.gd` orquesta: construye las filas desde `_entradas` + `_estados`, deduce el formato de la extensión elegida en un FileDialog y muestra el resultado en `%Progreso`.

**Tech Stack:** Godot 4.7.2, GDScript, tests SceneTree headless.

## Global Constraints

- Motor local: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/<suite>.gd`
- Tabs, sin comentarios; UI en español; preload-const en lugar de class_name (nuevo código).
- Tests en base `user://__test_<area>__` y se limpian al terminar.
- Batería: `& "C:\Program Files\Git\bin\bash.exe" -c 'cd /k/gestor-de-enlaces && GODOT_BIN="K:/Godot_v4.6.1/Godot_v4.7.2-stable_win64_console.exe" bash tests/run_battery.sh'` (actualmente 18 suites; 19 al añadir `test_informe_store.gd`).
- Workflow del repo: commits directos en `main` y push al final; cerrar la issue con `gh issue close 11`.

---

### Task 1: `informe_store.gd` (CSV y HTML) + `test_informe_store.gd` (TDD)

**Files:**
- Create: `scripts/informe_store.gd`
- Create: `scripts/informe_store.gd.uid` (generado por `--import`, ver Step 5)
- Test: `tests/test_informe_store.gd`
- Test: `tests/test_informe_store.gd.uid`

**Interfaces:**
- Consumes: nada (solo `FileAccess`).
- Produces: `InformeStore.exportar_csv(ruta: String, filas: Array) -> Dictionary` y `InformeStore.exportar_html(ruta: String, filas: Array) -> Dictionary`, con filas `Array[Dictionary]` de `{nombre, url, estado, fecha, mensaje}`. Devuelve `{"ok": true, "total": int}` o `{"ok": false, "error": String}`. Consumido por la Task 2.

- [ ] **Step 1: Escribir el test que falla**

Crear `tests/test_informe_store.gd`:

```gdscript
extends SceneTree

const InformeStoreScript := preload("res://scripts/informe_store.gd")
const BASE := "user://__test_informe__"
const RUTA_CSV := BASE + "/informe.csv"
const RUTA_HTML := BASE + "/informe.html"

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	DirAccess.make_dir_recursive_absolute(BASE)
	var filas := [
		{"nombre": "A", "url": "https://a.test", "estado": "Válido", "fecha": 0, "mensaje": "OK (200)"},
		{"nombre": "B", "url": "https://b.test", "estado": "Caído", "fecha": 1600000000, "mensaje": "Hola; \"mundo\""},
		{"nombre": "C", "url": "https://c.test", "estado": "Sin comprobar", "fecha": 0, "mensaje": "<script>alert(1)</script>"},
	]

	var re_csv := InformeStoreScript.exportar_csv(RUTA_CSV, filas)
	_check(re_csv.get("ok", false) and int(re_csv.get("total", -1)) == 3, "exportar_csv escribe y cuenta filas")
	var texto_csv := FileAccess.get_file_as_string(RUTA_CSV)
	_check(texto_csv.begins_with("Nombre;URL;Estado;Fecha;Mensaje\n"), "CSV tiene la cabecera Nombre;URL;Estado;Fecha;Mensaje")
	_check(texto_csv.contains("\nA;https://a.test;Válido;;OK (200)\n"), "CSV fila válida con fecha 0 deja Fecha vacío")
	_check(texto_csv.contains("\nB;https://b.test;Caído;2020-09-13 14:26\n"), "CSV fila caída formatea la fecha (hora local)")
	_check(texto_csv.contains("\"Hola; \"\"mundo\"\"\""), "CSV escapa el separador y las comillas dobles")
	_check(texto_csv.contains("\nC;https://c.test;Sin comprobar;;<script>alert(1)</script>\n"), "CSV conserva el texto plano del mensaje")

	var re_html := InformeStoreScript.exportar_html(RUTA_HTML, filas)
	_check(re_html.get("ok", false) and int(re_html.get("total", -1)) == 3, "exportar_html escribe y cuenta filas")
	var texto_html := FileAccess.get_file_as_string(RUTA_HTML)
	_check(texto_html.contains("<!DOCTYPE html>") and texto_html.contains("<meta charset=\"utf-8\">"), "HTML es un documento autocontenido con charset utf-8")
	_check(texto_html.contains("<table>") and texto_html.contains("</table>"), "HTML contiene una tabla")
	_check(texto_html.contains("&lt;script&gt;alert(1)&lt;/script&gt;"), "HTML escapa etiquetas del mensaje")
	_check(texto_html.contains("class=\"caido\""), "HTML usa la clase de fila caída")
	_check(texto_html.contains("class=\"valido\"") and texto_html.contains("class=\"sincomprobar\""), "HTML usa las clases de válido y sin comprobar")
	_check(texto_html.contains("<th>Estado</th>") and texto_html.contains("<th>Nombre</th>"), "HTML contiene la cabecera de la tabla")

	var re_err := InformeStoreScript.exportar_csv(BASE + "/nohay/x.csv", [])
	_check(not re_err.get("ok", true) and not str(re_err.get("error", "")).is_empty(), "exportar_csv a una carpeta inexistente falla con error")

	DirAccess.remove_absolute(BASE + "/informe.csv")
	DirAccess.remove_absolute(BASE + "/informe.html")
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

> Nota: `1600000000` epoch UTC = 2020-09-13 14:26:40 hora de Madrid (UTC+2). El check usa `2020-09-13 14:26`. Si la máquina estuviera en otra zona, ajustar el valor esperado al real — lo que se valida es el formato `AAAA-MM-DD HH:MM`, no una zona concreta.

- [ ] **Step 2: Ejecutar y verificar que falla**

Run:
```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_informe_store.gd
```
Expected: parse errors por `informe_store.gd` inexistente (`Preload file ... does not exist`).

- [ ] **Step 3: Implementar `scripts/informe_store.gd`**

```gdscript
class_name InformeStore
extends RefCounted


static func exportar_csv(ruta: String, filas: Array) -> Dictionary:
	var lineas := PackedStringArray(["Nombre;URL;Estado;Fecha;Mensaje"])
	for fila in filas:
		if typeof(fila) != TYPE_DICTIONARY:
			continue
		var f := fila as Dictionary
		lineas.append(
			_escape_csv(str(f.get("nombre", ""))) + ";" +
			_escape_csv(str(f.get("url", ""))) + ";" +
			_escape_csv(str(f.get("estado", ""))) + ";" +
			_escape_csv(_fecha_legible(int(f.get("fecha", 0)))) + ";" +
			_escape_csv(str(f.get("mensaje", "")))
		)
	return _escribir(ruta, "\n".join(lineas) + "\n", lineas.size() - 1)


static func exportar_html(ruta: String, filas: Array) -> Dictionary:
	var cuerpo: String = ""
	for fila in filas:
		if typeof(fila) != TYPE_DICTIONARY:
			continue
		var f := fila as Dictionary
		var estado := str(f.get("estado", ""))
		var clase := "sincomprobar"
		if estado == "Válido":
			clase = "valido"
		elif estado == "Caído":
			clase = "caido"
		cuerpo += "<tr class=\"%s\"><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n" % [
			clase,
			_escape_html(str(f.get("nombre", ""))),
			_escape_html(str(f.get("url", ""))),
			_escape_html(estado),
			_escape_html(_fecha_legible(int(f.get("fecha", 0)))),
			_escape_html(str(f.get("mensaje", ""))),
		]
	var html := "<!DOCTYPE html>\n<html lang=\"es\">\n<head>\n<meta charset=\"utf-8\">\n" \
		+ "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n" \
		+ "<title>Informe de disponibilidad</title>\n<style>\n" \
		+ "table{border-collapse:collapse;width:100%}\nth,td{border:1px solid #ddd;padding:6px 10px;text-align:left}\n" \
		+ "thead th{background:#eee}\n.valido{background:#e8f5e9}\n.caido{background:#ffebee}\n.sincomprobar{background:#f5f5f5}\n" \
		+ "</style>\n</head>\n<body>\n<h1>Informe de disponibilidad</h1>\n" \
		+ "<table>\n<thead><tr><th>Nombre</th><th>URL</th><th>Estado</th><th>Fecha</th><th>Mensaje</th></tr></thead>\n<tbody>\n" \
		+ cuerpo + "</tbody>\n</table>\n</body>\n</html>\n"
	return _escribir(ruta, html, filas.size())


static func _escape_csv(valor: String) -> String:
	if valor.contains(";") or valor.contains("\"") or valor.contains("\n") or valor.contains("\r"):
		return "\"" + valor.replace("\"", "\"\"") + "\""
	return valor


static func _escape_html(valor: String) -> String:
	return valor.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")


static func _fecha_legible(unix: int) -> String:
	if unix <= 0:
		return ""
	var t := Time.get_datetime_dict_from_unix_time(unix)
	return "%04d-%02d-%02d %02d:%02d" % [int(t.year), int(t.month), int(t.day), int(t.hour), int(t.minute)]


static func _escribir(ruta: String, contenido: String, total: int) -> Dictionary:
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		return {"ok": false, "error": "No se pudo escribir el archivo."}
	archivo.store_string(contenido)
	archivo.close()
	return {"ok": true, "total": total}
```

- [ ] **Step 4: Ejecutar el test y verificar que pasa**

Run el mismo comando del Step 2.
Expected: `TESTS OK`. Si solo falla el check de la fecha por zona horaria, ajusta el literal `2020-09-13 14:26` al valor real impreso (el objetivo es el formato `AAAA-MM-DD HH:MM`).

- [ ] **Step 5: Generar `.gd.uid` y commit**

Run:
```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --import
```
- Verifica que existe `scripts/informe_store.gd.uid`.
- Comprueba `git status --porcelain` y que `project.godot` NO aparezca modificado.
Commit:
```bash
git -C "K:\gestor-de-enlaces" add scripts/informe_store.gd scripts/informe_store.gd.uid tests/test_informe_store.gd tests/test_informe_store.gd.uid
git -C "K:\gestor-de-enlaces" commit -m "feat(informe): store CSV/HTML con exportar_csv/exportar_html y tests (TDD)"
```

---

### Task 2: Integración en `main.gd` (menú, FileDialog, `_on_informe_elegido`, `_formato_informe`) + checks

**Files:**
- Modify: `scripts/main.gd` (preload ~15, `_ready` ~95, `_configurar_menus` ~108, `_on_file_id` ~127, nuevo método tras `_on_exportar_elegido` ~167)
- Modify: `scenes/Main.tscn` (`%DialogoInforme` tras `%DialogoExportar` ~212)
- Test: `tests/test_main_barra.gd`

**Interfaces:**
- Consumes: `InformeStoreScript.exportar_csv/exportar_html` (Task 1); `_entradas`, `_estados`, `GestorCatalogoScript.clave_unica`, `%Progreso`.
- Produces: `_on_informe_elegido(ruta: String)`, `_formato_informe(ruta: String) -> String`, ítem de menú id 5, nodo `%DialogoInforme`. Verificado en esta misma task.

- [ ] **Step 1: Escribir los checks de integración (rojo) en `tests/test_main_barra.gd`**

Añadir tras el bloque del diálogo de exportación (tras la línea ~359, `diag_exp.hide()`):

```gdscript
	# Informe de disponibilidad (#11)
	var menu_file_inf: PopupMenu = main.get_node("%File")
	var hay_informe := false
	for i in menu_file_inf.get_item_count():
		if menu_file_inf.get_item_id(i) == 5 and menu_file_inf.get_item_text(i) == "Informe de disponibilidad…":
			hay_informe = true
	_check(hay_informe, "Archivo > Informe de disponibilidad… está en el menú")
	_check(main.has_node("%DialogoInforme"), "el diálogo DialogoInforme existe en Main.tscn")
	main_script._on_file_id(5)
	_check(main.get_node("%DialogoInforme").visible, "Archivo > Informe de disponibilidad… abre el diálogo de guardado")
	main.get_node("%DialogoInforme").hide()
	_check(main_script._formato_informe("informe.html") == "html", "_formato_informe deduce html por extensión")
	_check(main_script._formato_informe("informe.csv") == "csv", "_formato_informe deduce csv por extensión")
	_check(main_script._formato_informe("informe") == "csv", "_formato_informe asume csv sin extensión")
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run:
```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd
```
Expected: SCRIPT ERROR por `_formato_informe` / `%DialogoInforme` inexistentes (el test cortará en el primer fallo; es el rojo esperado).

- [ ] **Step 3: Añadir `%DialogoInforme` en `scenes/Main.tscn`**

Tras el nodo `DialogoExportar` (línea ~216):

```text
[node name="DialogoInforme" type="FileDialog" parent="."]
unique_name_in_owner = true
title = "Guardar informe de disponibilidad"
file_mode = 4
filters = PackedStringArray("*.csv ; Archivo CSV (*.csv)", "*.html ; Archivo HTML (*.html)")
```

- [ ] **Step 4: Implementar en `scripts/main.gd`**

1. Preload tras `ColaStoreScript`:
```gdscript
const InformeStoreScript := preload("res://scripts/informe_store.gd")
```

2. En `_ready()` tras `%DialogoExportar.file_selected.connect(_on_exportar_elegido)`:
```gdscript
	%DialogoInforme.file_selected.connect(_on_informe_elegido)
```

3. En `_configurar_menus()` (menú File), tras el ítem "Exportar…":
```gdscript
	menu_file.add_item("Informe de disponibilidad…", 5)
```

4. En `_on_file_id(id)` añadir el caso:
```gdscript
		5:
			%DialogoInforme.popup_centered()
```

5. Tras `_on_exportar_elegido`, añadir `_on_informe_elegido` y `_formato_informe`:

```gdscript
func _on_informe_elegido(ruta: String) -> void:
	var formato := _formato_informe(ruta)
	if not ruta.to_lower().ends_with(".csv") and not ruta.to_lower().ends_with(".html"):
		ruta += ".csv"
	var filas: Array = []
	for entrada in _entradas:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		var url := str(entrada.get("url", ""))
		var estado: Dictionary = _estados.get(GestorCatalogoScript.clave_unica(url), {})
		var estado_texto := "Sin comprobar"
		var fecha := 0
		var mensaje := ""
		if not estado.is_empty():
			estado_texto = "Válido" if estado.get("valido") == true else "Caído"
			fecha = int(estado.get("fecha", 0))
			mensaje = str(estado.get("mensaje", ""))
		filas.append({
			"nombre": str(entrada.get("nombre", "")),
			"url": url,
			"estado": estado_texto,
			"fecha": fecha,
			"mensaje": mensaje,
		})
	var res: Dictionary = InformeStoreScript.exportar_html(ruta, filas) if formato == "html" else InformeStoreScript.exportar_csv(ruta, filas)
	if not res.get("ok", false):
		progreso.text = str(res.get("error", "No se pudo guardar el informe."))
		return
	progreso.text = "Informe %s guardado (%d enlaces)." % [formato.to_upper(), int(res.get("total", 0))]


func _formato_informe(ruta: String) -> String:
	if ruta.to_lower().ends_with(".html"):
		return "html"
	return "csv"
```

> Nota: `_formato_informe` devuelve `csv` para cualquier extensión distinta de `.html`, cumpliendo "sin extensión → csv". El propio `_on_informe_elegido` añade `.csv` al path solo si no acaba en `.csv` ni `.html`, cubriendo el nombre sin extensión.

- [ ] **Step 5: Ejecutar el test y verificar que pasa**

Run:
```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd
```
Expected: `TESTS OK` (con los nuevos checks "Informe de disponibilidad…", "DialogoInforme existe" y los 3 de `_formato_informe`).

- [ ] **Step 6: Smoke de arranque y commit**

Run:
```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --quit-after 5 2>&1 | Select-String -Pattern "SCRIPT ERROR|Parse Error"
```
Expected: sin errores.
Commit:
```bash
git -C "K:\gestor-de-enlaces" add scripts/main.gd scenes/Main.tscn tests/test_main_barra.gd
git -C "K:\gestor-de-enlaces" commit -m "feat(informe): menu Archivo + FileDialog + _on_informe_elegido (CSV/HTML) con checks de integracion"
```

---

### Task 3: Batería completa, push y cierre de la issue

**Files:** ninguno (solo verificación y git).

- [ ] **Step 1: Batería completa**

Run:
```bash
& "C:\Program Files\Git\bin\bash.exe" -c 'cd /k/gestor-de-enlaces && GODOT_BIN="K:/Godot_v4.6.1/Godot_v4.7.2-stable_win64_console.exe" bash tests/run_battery.sh' 2>&1 | Select-Object -Last 25
```
Expected: `BATERÍA OK: 19 suites pasaron.` (las 18 anteriores + `test_informe_store.gd`).

- [ ] **Step 2: Revisar estado y push**

Run:
```bash
git -C "K:\gestor-de-enlaces" status --porcelain
git -C "K:\gestor-de-enlaces" log --oneline origin/main..HEAD
```
Confirma que solo hay cambios esperados (los untracked ajenos `Assets/icon/*.import`, `data/data2.json`, `docs/superpowers/plans/*.md`, `scripts/historial.gd.uid` se ignoran).
Push:
```bash
git -C "K:\gestor-de-enlaces" push origin main
```

- [ ] **Step 3: Cerrar la issue**

```bash
gh issue close 11 --comment "Implementado: informe de disponibilidad en CSV (Excel, separador ;) y HTML autocontenido desde el menu Archivo. Bateria local 19/19 OK."
```

> Verificar el cierre con `gh issue list --repo scorpio21/gestor-de-enlaces --state open --limit 10` y anotar las que quedan (#6, #17, #19, #27, #30).