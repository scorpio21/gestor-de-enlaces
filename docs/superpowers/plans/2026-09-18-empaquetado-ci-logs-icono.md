# Empaquetado, CI, Logs y Diagnóstico — Plan de Implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convertir GestorAO en producto empaquetable: presets de exportación (Windows/Linux/macOS), CI con tests headless que exporta los 3 ejecutables, logs persistentes rotativos en `user://logs/` con exportación de diagnóstico en ZIP, e icono propio con versión legible en la ventana.

**Architecture:** Un Logger GDScript (`scripts/logger.gd`) con rotación por tamaño inyecta mensajes `[APP]`/`[SCAN]` en `user://logs/`; `scripts/diagnostico.gd` empaqueta logs+datos con `ZIPPacker`; `scripts/generar_iconos.gd` genera el icono Apache SVG→PNG→ICO/ICNS en Godot puro; `export_presets.cfg` + `.github/workflows/ci.yml` + `tests/run_battery.sh` hacen el producto entregable. Todo testeable headless con el harness `extends SceneTree` existente.

**Tech Stack:** Godot 4.7.2 (GDScript, `ZIPPacker`, `Image.load_svg_from_buffer`, `FileAccess`), GitHub Actions (ubuntu-latest, `actions/checkout@v4`, `actions/cache@v4`, `actions/upload-artifact@v4`), bash (batería CI).

## Global Constraints

(Se asume que el implementador conoce las reglas del repo; se repiten las críticas.)

- Sin comentarios en el código. Tabs para indentar. Cadenas de UI en español.
- Sin `class_name` nuevo: usar `const X := preload("res://scripts/x.gd")` en el consumidor.
- Tests `extends SceneTree`, método `_initialize()`, `print("TESTS OK")` + `quit(0)` al final, o `print("TESTS FALLIDOS: %d" % _fallos)` + `quit(1)`.
- Los tests usan bases temporales `user://__test_<nom>__` y se limpian solos.
- Motor local: `K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe`. Shell `pwsh`; comando suite:
  `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/<archivo>.gd`
- Batería actual 12 suites / 296 checks; `project.godot` se reordena solo al correr Godot → restaurar tras cada run con `git checkout -- project.godot` si no se toca deliberadamente.
- `user://` en headless de escritorio = `%APPDATA%\Godot\app_userdata\GestorAO\`; los tests usan SIEMPRE `user://__test_*__` y borran al final.
- Los `.tscn` edits manuales: `scenes/Main.tscn` (añadir nodo FileDialog). No reordenar `project.godot` manualmente; solo editar las claves marcadas.
- La app no escribe logs en headless (protector `_es_headless()`).

---

### Task 1: Logger rotativo

**Files:**
- Create: `scripts/logger.gd`
- Test: `tests/test_logger.gd`

**Interfaces:**
- Produces:
  - `func _init(base := "user://", max_bytes := 512 * 1024) -> void` — crea `base/logs/`, abre `app.log` y `scan.log` (append), no falla si ya existe.
  - `func app(tipo: String, msg: String) -> void` — escribe `[APP][<tipo>] <ts> msg\n` en `app.log`.
  - `func scan(url: String, resultado: String, detalle := "") -> void` — escribe `[SCAN] <ts> url resultado detalle\n` en `scan.log`.
  - `func flush() -> void` — fuerza escritura a disco (para que los tests puedan releer).
  - Las instancias son RefCounted (preload-const, sin class_name).

- [ ] **Step 1: Escribe test_logger.gd**

```gdscript
extends SceneTree

const LoggerScript := preload("res://scripts/logger.gd")
const BASE := "user://__test_logger__"

var _fallos := 0


func _initialize() -> void:
	_limpiar()
	DirAccess.make_dir_recursive_absolute("user://")
	_check(inicia_crea_ficheros(), "iniciar crea logs/app.log y logs/scan.log")
	_check(app_escribe_linea(), "app() escribe línea [APP] en app.log")
	_check(scan_escribe_linea(), "scan() escribe línea [SCAN] en scan.log")
	_check(rotacion_genera_log1(), "al superar max_bytes rota a .log.1")
	_check(sin_sobreescribir_al_reabrir(), "iniciar sobre base existente no borra el contenido previo")
	_limpiar()
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func inicia_crea_ficheros() -> bool:
	var l := LoggerScript.new(BASE)
	return FileAccess.file_exists(BASE + "/logs/app.log") \
		and FileAccess.file_exists(BASE + "/logs/scan.log")


func app_escribe_linea() -> bool:
	var l := LoggerScript.new(BASE)
	l.app("error", "fallo de prueba")
	l.flush()
	var txt := FileAccess.open(BASE + "/logs/app.log", FileAccess.READ).get_as_text()
	return txt.begins_with("[APP][error]") and txt.ends_with("fallo de prueba\n")


func scan_escribe_linea() -> bool:
	var l := LoggerScript.new(BASE)
	l.scan("https://ejemplo.test", "valido", "OK (200)")
	l.flush()
	var txt := FileAccess.open(BASE + "/logs/scan.log", FileAccess.READ).get_as_text()
	return txt.begins_with("[SCAN] ") and "https://ejemplo.test" in txt \
		and "valido" in txt and "OK (200)" in txt


func rotacion_genera_log1() -> bool:
	DirAccess.remove_absolute(BASE + "/logs/app.log.1")
	var l := LoggerScript.new(BASE, 200)
	for i in range(10):
		l.app("error", "linea de relleno %d para forzar rotacion" % i)
	l.flush()
	return FileAccess.file_exists(BASE + "/logs/app.log.1") \
		and FileAccess.file_exists(BASE + "/logs/app.log")


func sin_sobreescribir_al_reabrir() -> bool:
	var l := LoggerScript.new(BASE)
	l.app("error", "primera")
	l.flush()
	var l2 := LoggerScript.new(BASE)
	l2.app("error", "segunda")
	l2.flush()
	var txt := FileAccess.open(BASE + "/logs/app.log", FileAccess.READ).get_as_text()
	return "primera" in txt and "segunda" in txt


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)


func _limpiar() -> void:
	DirAccess.remove_absolute(BASE)
```

- [ ] **Step 2: Córrelo y comprueba que falla**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_logger.gd`
Expected: `TESTS FALLIDOS` (no existe `logger.gd`).

- [ ] **Step 3: Implementa scripts/logger.gd**

```gdscript
extends RefCounted

var _base := "user://"
var _max_bytes := 512 * 1024
var _app: FileAccess = null
var _scan: FileAccess = null


func _init(base := "user://", max_bytes := 512 * 1024) -> void:
	_base = base
	_max_bytes = max_bytes
	DirAccess.make_dir_recursive_absolute(_base + "/logs")
	_app = _abrir("app")
	_scan = _abrir("scan")


func app(tipo: String, msg: String) -> void:
	if _app == null:
		return
	if _app.get_length() >= _max_bytes:
		_rotar(_app, "app")
		_app = _abrir("app")
		if _app == null:
			return
	_app.store_string("[APP][%s] %s %s\n" % [tipo, Time.get_datetime_string_from_system(), msg])


func scan(url: String, resultado: String, detalle := "") -> void:
	if _scan == null:
		return
	if _scan.get_length() >= _max_bytes:
		_rotar(_scan, "scan")
		_scan = _abrir("scan")
		if _scan == null:
			return
	_scan.store_string("[SCAN] %s %s %s %s\n" % [Time.get_datetime_string_from_system(), url, resultado, detalle.strip_edges()])


func flush() -> void:
	if _app != null:
		_app.flush()
	if _scan != null:
		_scan.flush()


func _abrir(especie: String) -> FileAccess:
	var f := FileAccess.open(_base + "/logs/" + especie + ".log", FileAccess.READ_WRITE)
	if f == null:
		return null
	f.seek_end()
	return f


func _rotar(f: FileAccess, especie: String) -> void:
	f.close()
	DirAccess.remove_absolute(_base + "/logs/" + especie + ".log.1")
	DirAccess.rename_absolute(_base + "/logs/" + especie + ".log", _base + "/logs/" + especie + ".log.1")
```

Nota: `FileAccess` usa `READ_WRITE` + `seek_end()` para append sin truncar; `get_length()` mide el tamaño actual antes de escribir la línea.

- [ ] **Step 4: Córrelo y comprueba que pasa**

Run: mismo comando del Step 2.
Expected: `TESTS OK`.

- [ ] **Step 5: Commit**

```bash
git add scripts/logger.gd tests/test_logger.gd
git commit -m "feat(logs): logger rotativo app/scan en user://logs (#28)"
```

---

### Task 2: Generador de iconos + metadatos del proyecto

**Files:**
- Create: `scripts/generar_iconos.gd`
- Create: `Assets/icon/icon.svg`, `Assets/icon/icon_256.png`, `Assets/icon/icon.ico`, `Assets/icon/icon.icns` (salida del script)
- Modify: `project.godot` (claves `config/version`, `config/icon`, nueva `display/window/title`)
- Test: `tests/test_iconos.gd`, `tests/test_proyecto.gd`

**Interfaces:**
- Produces:
  - `scripts/generar_iconos.gd` — script `extends SceneTree` autocontenido con **funciones `static`** (el test llama `GenerarIconos.generar(...)`; los scripts SceneTree no se instancian): const `CONST_SVG` con el icono, `static func generar(destino := "res://Assets/icon") -> Dictionary` y `_initialize()` para ejecución directa (`--script`) que genera en `res://Assets/icon` y `quit(0)`. Devuelve `{"ok": bool, "total": int}`.
  - Formato interno: los archivos se escriben con `FileAccess.open(..., WRITE).store_buffer(...)`.
  - `project.godot`: `config/version="0.1.0"`, `config/icon="res://Assets/icon/icon.svg"`, nueva clave `display/window/title="GestorAO v0.1.0"`.
- Consumes: nada (task 1 no hace falta).

- [ ] **Step 1: Escribe tests (test_iconos.gd y test_proyecto.gd)**

test_iconos.gd (genera en `user://__test_iconos__`):

```gdscript
extends SceneTree

const GenerarIconos := preload("res://scripts/generar_iconos.gd")
const BASE := "user://__test_iconos__"

var _fallos := 0


func _initialize() -> void:
	DirAccess.remove_absolute(BASE)
	var res: Dictionary = GenerarIconos.generar(BASE)
	_check(res.get("ok", false) and int(res.get("total", -1)) == 4, "generar produce 4 ficheros")
	_check(_cabeza_icns_ok(), "icon.icns empieza por la cabecera icns")
	_check(_cabeza_ico_ok(), "icon.ico empieza por la cabecera ICO (00 00 01 00)")
	_check(_png_valido(), "icon_256.png es PNG válido (cabecera PNG + dimensión 256)")
	_check(FileAccess.file_exists(BASE + "/icon.svg"), "icon.svg se genera")
	DirAccess.remove_absolute(BASE)
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _cabeza_icns_ok() -> bool:
	var f := FileAccess.open(BASE + "/icon.icns", FileAccess.READ)
	if f == null:
		return false
	var cab := f.get_buffer(4).get_string_from_ascii()
	return cab == "icns"


func _cabeza_ico_ok() -> bool:
	var f := FileAccess.open(BASE + "/icon.ico", FileAccess.READ)
	if f == null:
		return false
	var b := f.get_buffer(4)
	return b[0] == 0 and b[1] == 0 and b[2] == 1 and b[3] == 0


func _png_valido() -> bool:
	var f := FileAccess.open(BASE + "/icon_256.png", FileAccess.READ)
	if f == null:
		return false
	var cab := f.get_buffer(8)
	var ok_cab := cab[0] == 0x89 and cab[1] == 0x50 and cab[2] == 0x4e and cab[3] == 0x47
	var im := Image.new()
	var err := im.load_png_from_buffer(f.get_buffer(f.get_length() - 8))
	return ok_cab and err == OK and im.get_width() == 256 and im.get_height() == 256


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)
```

test_proyecto.gd:

```gdscript
extends SceneTree

var _fallos := 0


func _initialize() -> void:
	_check(_version_ok(), "project.godot tiene config/version=0.1.0")
	_check(_icon_ok(), "project.godot apunta a Assets/icon/icon.svg")
	_check(_title_ok(), "project.godot tiene display/window/title = GestorAO v0.1.0")
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _leer() -> String:
	var f := FileAccess.open("res://project.godot", FileAccess.READ)
	return f.get_as_text() if f != null else ""


func _version_ok() -> bool:
	return "config/version=\"0.1.0\"" in _leer()


func _icon_ok() -> bool:
	return "config/icon=\"res://Assets/icon/icon.svg\"" in _leer()


func _title_ok() -> bool:
	return "display/window/title=\"GestorAO v0.1.0\"" in _leer()


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)
```

- [ ] **Step 2: Córrelos y comprueba que fallan**

Run: `test_iconos.gd` y `test_proyecto.gd` con el motor headless.
Expected: ambos `TESTS FALLIDOS` (generador inexistente; project.godot aún `0.0.1`).

- [ ] **Step 3: Implementa scripts/generar_iconos.gd**

```gdscript
extends SceneTree

const CONST_SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 120 120">
<defs>
<linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#ffc46b"/>
<stop offset="1" stop-color="#e8862a"/>
</linearGradient>
</defs>
<rect x="6" y="6" width="108" height="108" rx="24" fill="#10141c"/>
<rect x="26" y="30" width="34" height="20" rx="6" fill="none" stroke="url(#g)" stroke-width="6"/>
<rect x="56" y="56" width="34" height="20" rx="6" fill="none" stroke="url(#g)" stroke-width="6"/>
<path d="M60 40 H78 a9 9 0 0 1 0 18l-6-20z" fill="url(#g)" opacity="0.9"/>
<path d="M50 76 a9 9 0 0 1-8-18h4" stroke="url(#g)" stroke-width="6" fill="none" stroke-linecap="round"/>
<circle cx="93" cy="92" r="8" fill="none" stroke="#3ddc84" stroke-width="5"/>
<path d="M90 92 l2.5 2.5 l4-4" stroke="#3ddc84" stroke-width="3" fill="none"/>
</svg>
"""


static func generar(destino := "res://Assets/icon") -> Dictionary:
	DirAccess.make_dir_recursive_absolute(destino)
	var svg_bytes := CONST_SVG.to_utf8_buffer()
	var im := Image.new()
	var err := im.load_svg_from_buffer(svg_bytes, 4.0)
	if err != OK:
		return {"ok": false, "total": 0}
	im.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	Var.write_bytes(destino + "/icon.svg", svg_bytes)
	Var.write_bytes(destino + "/icon_256.png", im.save_png_to_buffer())
	Var.write_bytes(destino + "/icon.ico", _fichero_ico(im))
	Var.write_bytes(destino + "/icon.icns", _fichero_icns(im))
	return {"ok": true, "total": 4}


class Var:
	static func write_bytes(ruta: String, data: PackedByteArray) -> void:
		var f := FileAccess.open(ruta, FileAccess.WRITE)
		if f != null:
			f.store_buffer(data)


static func _png_en(tam: int) -> PackedByteArray:
	var base := Image.new()
	var err := base.load_svg_from_buffer(CONST_SVG.to_utf8_buffer(), float(tam) / 256.0)
	if err != OK:
		return PackedByteArray()
	return base.save_png_to_buffer()


static func _fichero_ico(im: Image) -> PackedByteArray:
	var tam := PackedInt32Array([16, 32, 48, 256])
	var blobs: Array[PackedByteArray] = []
	for t in tam:
		var capa := Image.new()
		capa.copy_from(im)
		capa.resize(t, t, Image.INTERPOLATE_LANCZOS)
		blobs.append(capa.save_png_to_buffer())
	var salida := PackedByteArray([0, 0, 1, 0])
	salida.append(0); salida.append(tam.size())  # count (u16 LE)
	var offset: int = 6 + tam.size() * 16
	for i in range(tam.size()):
		var t := tam[i]
		salida.append(0 if t >= 256 else t)  # width (0 = 256)
		salida.append(0 if t >= 256 else t)  # height
		salida.append(0)  # paleta
		salida.append(0)  # reservado
		salida.append(1); salida.append(0)  # planes
		salida.append(32); salida.append(0)  # bpp
		salida.append(blobs[i].size() & 0xFF); salida.append((blobs[i].size() >> 8) & 0xFF)
		salida.append((blobs[i].size() >> 16) & 0xFF); salida.append((blobs[i].size() >> 24) & 0xFF)
		salida.append(offset & 0xFF); salida.append((offset >> 8) & 0xFF)
		salida.append((offset >> 16) & 0xFF); salida.append((offset >> 24) & 0xFF)
		offset += blobs[i].size()
	for b in blobs:
		salida.append_array(b)
	return salida


static func _fichero_icns(im: Image) -> PackedByteArray:
	var entradas := [
		["icp4", 16], ["icp5", 32], ["ic07", 128], ["ic08", 256], ["ic09", 512],
	]
	var salida := "icns".to_ascii_buffer()
	var tam_total := PackedByteArray([0, 0, 0, 0])
	salida.append_array(tam_total)
	var acumulado: int = 8
	for e in entradas:
		var png := _png_en(e[1])
		salida.append_array(e[0].to_ascii_buffer())
		var largo := 8 + png.size()
		salida.append((largo >> 24) & 0xFF); salida.append((largo >> 16) & 0xFF)
		salida.append((largo >> 8) & 0xFF); salida.append(largo & 0xFF)
		salida.append_array(png)
		acumulado += largo
	salida[4] = (acumulado >> 24) & 0xFF
	salida[5] = (acumulado >> 16) & 0xFF
	salida[6] = (acumulado >> 8) & 0xFF
	salida[7] = acumulado & 0xFF
	return salida


func _initialize() -> void:
	var res := generar()
	if not res.get("ok", false):
		push_error("No se pudieron generar los iconos")
		quit(1)
		return
	print("Iconos generados (%d)." % int(res.get("total", 0)))
	quit(0)
```

Nota: GDScript estático apoya `class Var` interno con `static func write_bytes`. Los números LE se añaden byte a byte (append de 8 bits). `im.load_svg_from_buffer(buffer, scale)` escala el SVG completo a escala `tam/256.0` (el `width`/`height` del SVG es 256, no el viewBox 120); para `_png_en` se re-renderiza desde el SVG a la escala exacta. Escribimos `icon_256.png` desde `im` (256 px). Todos los helpers (`generar`, `_png_en`, `_fichero_ico`, `_fichero_icns`) deben ser `static`: el test llama `GenerarIconos.generar(...)` sin instanciar el script, y `static` no puede llamar a `func` de instancia.

- [ ] **Step 4: Modifica project.godot**

Modify `project.godot`:
- Línea `config/version="0.0.1"` → `config/version="0.1.0"`
- Línea `config/icon="res://icon.svg"` → `config/icon="res://Assets/icon/icon.svg"`
- En la sección `[display]`, tras `window/subwindows/embed_subwindows=false`, añadir: `window/title="GestorAO v0.1.0"`

Usa el editor del proyecto (Edit) sobre esas tres claves exactas. No reordenar claves.

- [ ] **Step 5: Genera los iconos y córrelos**

Run: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://scripts/generar_iconos.gd`
Expected: `Iconos generados (4).` y existen `Assets/icon/icon.svg`, `icon_256.png`, `icon.ico`, `icon.icns`.
Verifica con `git status` que los 4 iconos están como untracked.

- [ ] **Step 6: Corre las suites nuevas**

Run: `test_iconos.gd` y `test_proyecto.gd` headless.
Expected: ambas `TESTS OK`. (Restaura `project.godot` con `git checkout -- project.godot` si Godot lo reordenó, SIN perder las 3 claves editadas — verificar con `git diff` antes de descartar nada.)

- [ ] **Step 7: Commit**

```bash
git add scripts/generar_iconos.gd Assets/icon tests/test_iconos.gd tests/test_proyecto.gd project.godot
git commit -m "feat(empaquetado): generador de iconos, icono y metadatos de proyecto 0.1.0 (#29)"
```

---

### Task 3: Diagnóstico ZIP

**Files:**
- Create: `scripts/diagnostico.gd`
- Test: `tests/test_diagnostico.gd`

**Interfaces:**
- Produces:
  - `func exportar(zip_ruta: String, base := "user://", version := "0.1.0", entradas := 0) -> Dictionary`
    - Crea `zip_ruta` con `ZIPPacker`; dentro: `app.log`, `scan.log` (si existen en `base/logs/`), `enlaces.json`, `estados.json`, `borrados.json`, `config.json` (si existen en `base/`) y `info.txt`.
    - `info.txt` líneas: `App=GestorAO`, `Version=<version>`, `Godot=<Engine.get_version_info().string>`, `OS=<OS.get_name()>`, `Fecha=<Time.get_datetime_string_from_system()>`, `Entradas=<entradas>`.
    - Devuelve `{"ok": bool, "errores": int, "total": int}`. Los ficheros inexistentes se omiten sin marcar error.
  - Los ficheros base se copian con `FileAccess` a los buffers y `ZIPPacker.start_file(name)` + `store_buffer`.

- [ ] **Step 1: Escribe test_diagnostico.gd**

```gdscript
extends SceneTree

const DiagnosticoScript := preload("res://scripts/diagnostico.gd")
const BASE := "user://__test_diag__"
const ZIP := BASE + "/diag.zip"

var _fallos := 0


func _initialize() -> void:
	DirAccess.remove_absolute(BASE)
	_plantilla()
	var res: Dictionary = DiagnosticoScript.exportar(ZIP, BASE, "0.1.0", 7)
	_check(res.get("ok", false), "exportar devuelve ok")
	_check(FileAccess.file_exists(ZIP), "el zip se crea")
	_check(_contenidos_si(), "zip incluye app.log, scan.log, enlaces.json, estados.json, config.json")
	_check(_info_ok(), "info.txt incluye App, Version, OS, Entradas=7")
	_check(_omite_inexistentes(), "ficheros inexistentes (borrados.json) se omiten sin error")
	DirAccess.remove_absolute(BASE)
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _plantilla() -> void:
	DirAccess.make_dir_recursive_absolute(BASE + "/logs")
	for nom in ["app.log", "scan.log"]:
		FileAccess.open(BASE + "/logs/" + nom, FileAccess.WRITE).store_string("x")
	for nom in ["enlaces.json", "estados.json", "config.json"]:
		FileAccess.open(BASE + "/" + nom, FileAccess.WRITE).store_string("{}")


func _contenidos_si() -> bool:
	var z := ZIPReader.new()
	if z.open(ZIP) != OK:
		return false
	var nombre := z.get_files()
	var ok := "info.txt" in nombre
	for f in ["app.log", "scan.log", "enlaces.json", "estados.json", "config.json"]:
		ok = ok and f in nombre
	z.close()
	return ok


func _info_ok() -> bool:
	var z := ZIPReader.new()
	if z.open(ZIP) != OK:
		return false
	var txt := z.read_file("info.txt").get_string_from_utf8()
	z.close()
	return "App=GestorAO" in txt and "Version=0.1.0" in txt \
		and "OS=" in txt and "Entradas=7" in txt


func _omite_inexistentes() -> bool:
	var z := ZIPReader.new()
	if z.open(ZIP) != OK:
		return false
	var ok := not ("borrados.json" in z.get_files())
	z.close()
	return ok


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)
```

- [ ] **Step 2: Córrelo y comprueba que falla**

Run: test_diagnostico.gd headless.
Expected: `TESTS FALLIDOS` (falta `diagnostico.gd`).

- [ ] **Step 3: Implementa scripts/diagnostico.gd**

```gdscript
extends RefCounted


const INFO_NOMBRES := [
	["enlaces.json", "enlaces.json"],
	["estados.json", "estados.json"],
	["borrados.json", "borrados.json"],
	["config.json", "config.json"],
]

const LOG_NOMBRES := [
	["app.log", "logs/app.log"],
	["scan.log", "logs/scan.log"],
]


static func exportar(zip_ruta: String, base := "user://", version := "0.1.0", entradas := 0) -> Dictionary:
	var zip := ZIPPacker.new()
	if zip.open(zip_ruta) != OK:
		return {"ok": false, "errores": 1, "total": 0}
	var errores := 0
	var total := 0
	for par in INFO_NOMBRES:
		if _copia_si_existe(zip, base + "/" + par[1], par[0]):
			total += 1
	for par in LOG_NOMBRES:
		if _copia_si_existe(zip, base + "/" + par[1], par[0]):
			total += 1
	var info := "App=GestorAO\nVersion=%s\nGodot=%s\nOS=%s\nFecha=%s\nEntradas=%d\n" % [
		version,
		Engine.get_version_info().get("string", "desconocido"),
		OS.get_name(),
		Time.get_datetime_string_from_system(),
		entradas,
	]
	if _escribe(zip, "info.txt", info.to_utf8_buffer()):
		total += 1
	else:
		errores += 1
	zip.close()
	return {"ok": errores == 0, "errores": errores, "total": total}


static func _copia_si_existe(zip: ZIPPacker, origen: String, nombre: String) -> bool:
	if not FileAccess.file_exists(origen):
		return false
	var f := FileAccess.open(origen, FileAccess.READ)
	if f == null:
		return false
	return _escribe(zip, nombre, f.get_buffer(f.get_length()))


static func _escribe(zip: ZIPPacker, nombre: String, data: PackedByteArray) -> bool:
	if zip.start_file(nombre) != OK:
		return false
	zip.write_file(data)
	zip.close_file()
	return true


func _init() -> void:
	pass
```

Nota: el test llama a `DiagnosticoScript.exportar(...)` — debe ser `static func` para no requerir instancia. `ZIPPacker.write_file` espera `PackedByteArray`; `close()` cierra el zip. Al estar `static`, el `_init` vacío se mantiene por convención GoTo (opcional).

- [ ] **Step 4: Córrelo y comprueba que pasa**

Run: test_diagnostico.gd headless.
Expected: `TESTS OK`.

- [ ] **Step 5: Commit**

```bash
git add scripts/diagnostico.gd tests/test_diagnostico.gd
git commit -m "feat(diagnostico): exportar ZIP de logs y datos con info.txt (#28)"
```

---

### Task 4: Integración en main.gd (menú + logger + diagnóstico)

**Files:**
- Modify: `scripts/main.gd`
- Modify: `scenes/Main.tscn` (nuevo nodo `DialogoDiagnostico` FileDialog)
- Test: `tests/test_main_barra.gd` (añadir checks)

**Interfaces:**
- Consumes: `LoggerScript` (Task 1), `DiagnosticoScript` (Task 3).
- Produces:
-   `var _logger: RefCounted` — creado en `_ready()` si `not _es_headless()`: `_logger = LoggerScript.new("user://")`; si headless queda `null` y las llamadas `_log_app`/`_log_scan` no-op.
  - `func _log_app(tipo: String, msg: String) -> void` / `func _log_scan(url: String, resultado: String, detalle := "") -> void` — wrappers con guarda.
  - Menú Utilidades: id 3 = `"Exportar diagnóstico…"`, handler `_on_diag_elegido(ruta: String)`.
  - login en `_on_item_terminado` y `_persistir_recompra`: `_log_scan(item.url, "valido" if item.valido == true else "caido", item.mensaje)`.
  - `_on_exportar_diagnostico()` → `%DialogoDiagnostico.popup_centered()`.
  - `main.gd _ready`: `%DialogoDiagnostico.file_selected.connect(_on_diag_elegido)` y `_log_app("inicio", "aplicación iniciada")` (no headless).

- [ ] **Step 1: Añade el nodo DialogoDiagnostico a Main.tscn**

Append al final de `scenes/Main.tscn` (tras `DialogoExportar`):

```
[node name="DialogoDiagnostico" type="FileDialog" parent="."]
unique_name_in_owner = true
title = "Exportar diagnóstico"
file_mode = 4
filters = PackedStringArray("*.zip ; Archivo ZIP")
```

- [ ] **Step 2: Añade los checks al test_main_barra.gd**

Añade al final de `_arrancar()` (antes de que el test cierre) dentro del bloque de checks existente del menú (busca el `_check` del menú Utilidades y añade tras él):

```gdscript
	_check(main.get_node("%DialogoDiagnostico") != null, "existe el diálogo DialogoDiagnostico")
	var menu_util: PopupMenu = main.get_node("%Utilidades")
	var tiene_diag := false
	for i in range(menu_util.item_count):
		if menu_util.get_item_text(i) == "Exportar diagnóstico…":
			tiene_diag = true
	_check(tiene_diag, "el menú Utilidades tiene la opción Exportar diagnóstico…")
	if main_script.has_method("_on_diag_elegido"):
		var ruta_zip := "user://__test_diag_main__.zip"
		var l := (load("res://scripts/logger.gd") as GDScript).new("user://__test_diag_main__")
		l.app("inicio", "arranque de prueba")
		l.scan("https://a.test", "valido", "OK (200)")
		l.flush()
		main_script._logger = l
		main_script._entradas = [{"nombre": "A", "url": "https://a.test"}]
		main_script._on_diag_elegido(ruta_zip)
		var z := ZIPReader.new()
		var ok_zip := z.open(ruta_zip) == OK
		if ok_zip:
			ok_zip = ("info.txt" in z.get_files()) and ("app.log" in z.get_files()) and ("scan.log" in z.get_files())
			z.close()
		_check(ok_zip, "_on_diag_elegido genera zip con info.txt y logs")
		DirAccess.remove_absolute("user://__test_diag_main__")
		DirAccess.remove_absolute(ruta_zip)
```

Nota: si `load("res://scripts/logger.gd")` falla al no existir en una vieja revisión, el check de `has_method` lo protege. Revisa que en el `_arrancar()` exista `var main_script = main.get_node(".")` con ese nombre (ya está en el test, línea ~46).

- [ ] **Step 3: Implementa los cambios en main.gd**

Edita `scripts/main.gd`:

1. Añadir al bloque de consts (junto a las otras preload de arriba):

```gdscript
const LoggerScript := preload("res://scripts/logger.gd")
const DiagnosticoScript := preload("res://scripts/diagnostico.gd")
```

2. Añadir `var _logger = null` junto al resto de `var` de estado (`_config_store`). (Sin tipo: el script preload no es un tipo; llamar `.app()` sobre `RefCounted` daría error estático.)

3. En `_ready()`, tras la creación de `_config_store` (línea ~79) y antes de `_refrescar_vista()`, añadir:

```gdscript
	if not _es_headless():
		_logger = LoggerScript.new("user://")
		_log_app("inicio", "aplicación iniciada")
	%DialogoDiagnostico.file_selected.connect(_on_diag_elegido)
```

4. Verificar que `_configurar_menus()` add_item del menú Utilidades añada:

```gdscript
	menu_util.add_item("Exportar diagnóstico…", 3)
```

(también actualiza los ids: "Limpiar capturas huérfanas…" sigue en 2; no hay conflicto.)

5. `_on_utilidades_id(id)`:

```gdscript
	elif id == 3:
		%DialogoDiagnostico.popup_centered()
```

6. Añadir funciones nuevas (tras `_on_exportar_elegido` o cerca de los otros handlers):

```gdscript
func _on_diag_elegido(ruta: String) -> void:
	var base := "user://"
	if _logger != null:
		base = _logger_base()
	var res := DiagnosticoScript.exportar(ruta, base, str(ProjectSettings.get_setting("application/config/version", "0.0.1")), _entradas.size())
	if not res.get("ok", false):
		progreso.text = "No se pudo exportar el diagnóstico (%d errores)." % int(res.get("errores", 0))
		return
	_log_app("diagnostico", "diagnóstico exportado a " + ruta)
	progreso.text = "Diagnóstico guardado en %s." % ruta


func _logger_base() -> String:
	return _logger.get("_base") if _logger != null else "user://"


func _log_app(tipo: String, msg: String) -> void:
	if _logger != null:
		_logger.app(tipo, msg)


func _log_scan(url: String, resultado: String, detalle := "") -> void:
	if _logger != null:
		_logger.scan(url, resultado, detalle)
```

7. En `_on_item_terminado` (tras `progreso.text = ...` de la línea ~601) añadir `_log_scan(item.url, "valido" if item.valido == true else "caido", item.mensaje)`. Ídem en `_persistir_recompra` (tras el `_estados[...] = ...`).

Verifica que `_es_headless()` ya existe (sí, definido en `main.gd` línea 731).

- [ ] **Step 4: Corre la suite de main y la nueva batería**

Run: `test_main_barra.gd` headless.
Expected: `TESTS OK` (93 + 3 checks nuevos ≈ 96). También corre `test_diagnostico.gd` y `test_logger.gd` → `TESTS OK`.

- [ ] **Step 5: Commit**

```bash
git add scripts/main.gd scenes/Main.tscn tests/test_main_barra.gd
git commit -m "feat(empaquetado): menú Exportar diagnóstico, logs de app y scan en main (#28)"
```

---

### Task 5: Presets de exportación, CI y batería compartida

**Files:**
- Create: `export_presets.cfg`
- Create: `.github/workflows/ci.yml`
- Create: `tests/run_battery.sh`
- Create: `AGENTS.md`
- Test: `tests/test_empaquetado.gd` (batería de assertions sobre archivos de config)

**Interfaces:**
- Produces:
  - `export_presets.cfg` con 3 presets (`Windows`, `Linux/X11`, `macOS`) — nombres exactos de las plataformas Godot.
  - `tests/run_battery.sh` — script bash: recorre `tests/test_*.gd`, ejecuta con GODOT_BIN + --headless, falla si cualquier suite no termina con exit 0 o imprime "TESTS FALLIDOS". `GODOT_BIN` env var o fallback `godot`.
  - `.github/workflows/ci.yml` — 1 job ubuntu, checkout, cache de Godot+templates, download Godot 4.7.2, download export_templates 4.7.2, batería, export de 3 presets, upload-artifact de los 3 ejecutables.
  - `AGENTS.md` — instrucciones: regenerar export_presets desde editor, batería local, generar iconos.

- [ ] **Step 1: Escribe test_empaquetado.gd**

```gdscript
extends SceneTree

var _fallos := 0


func _initialize() -> void:
	_check(_export_presets_ok(), "export_presets.cfg declara Windows, Linux/X11 y macOS")
	_check(_ci_ok(), ".github/workflows/ci.yml tiene battery y upload-artifact")
	_check(FileAccess.file_exists("res://tests/run_battery.sh"), "existe tests/run_battery.sh")
	_check(FileAccess.file_exists("res://AGENTS.md"), "existe AGENTS.md")
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _leer(ruta: String) -> String:
	var f := FileAccess.open(ruta, FileAccess.READ)
	return f.get_as_text() if f != null else ""


func _export_presets_ok() -> bool:
	var txt := _leer("res://export_presets.cfg")
	return "name=\"Windows\"" in txt and "name=\"Linux/X11\"" in txt and "platform=\"Linux/X11\"" in txt \
		and "name=\"macOS\"" in txt


func _ci_ok() -> bool:
	var txt := _leer("res://.github/workflows/ci.yml")
	return "run_battery.sh" in txt and "upload-artifact" in txt


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)
```

- [ ] **Step 2: Córrelo y comprueba que falla**

Run: test_empaquetado.gd headless.
Expected: `TESTS FALLIDOS` (archivos no existen).

- [ ] **Step 3: Crea export_presets.cfg**

Contenido mínimo con los 3 presets (estructura tipo Godot 4):

```
[preset.0]

name="Windows"
platform="Windows Desktop"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/gestor-de-enlaces.exe"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=1
binary_format/embed_pck=true
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
binary_format/architecture="x86_64"
codesign/enable=false
application/icon="res://Assets/icon/icon.ico"
application/console_wrapper_icon=""
application/icon_interpolation=4
application/file_version=""
application/product_name=""
application/file_description=""
application/copyright=""
application/trademarks=""
application/export_angle=0
application/export_d3d12=0
application/direct3d12_agility_sdk_multiarch=false
ssh_remote_deploy/enabled=false

[preset.1]

name="Linux/X11"
platform="Linux/X11"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/gestor-de-enlaces.x86_64"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.1.options]

custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=1
binary_format/embed_pck=true
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
binary_format/architecture="x86_64"
codesign/enable=false
application/icon=""
ssh_remote_deploy/enabled=false

[preset.2]

name="macOS"
platform="macOS"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/gestor-de-enlaces_macos.app"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.2.options]

custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=1
binary_format/embed_pck=true
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
binary_format/architecture="x86_64"
application/icon="res://Assets/icon/icon.icns"
application/icon_interpolation=4
application/bundle_identifier="com.gestor.gestorao"
application/bundle_version="0.1.0"
application/bundle_short_version="0.1.0"
application/bundle_name="GestorAO"
application/copyright=""
application/signature=""
application/category="public.app-category.utilities"
application/app_store_category="public.app-category.utilities"
codesign/enable=false
codesign/identity=""
codesign/installer_identity=""
notarization/enabled=false
ssh_remote_deploy/enabled=false
```

Nota: si el editor regenera el archivo (campo a campo) al abrirse, el contenido cambiará; eso es aceptable y se documenta en AGENTS.md. Lo esencial:

- Los 3 presets presentes con `platform=` correctos.
- Windows exporta `.exe`, Linux binario, macOS `.app` (la tpz no genera `.dmg`; CI lo comprime, ver workflow).
- La tpz de export templates se extrae directamente en `~/.local/share/godot/export_templates/4.7.2.stable/` (no hay subcarpeta `templates/` dentro).

- [ ] **Step 4: Crea tests/run_battery.sh**

```bash
#!/usr/bin/env bash
# Batería de tests headless de GestorAO.
# Uso: GODOT_BIN=/ruta/a/godot bash tests/run_battery.sh
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FALLOS=0
TOTAL=0

for suite in "$PROJECT_DIR"/tests/test_*.gd; do
	nombre="$(basename "$suite")"
	salida="$("$GODOT_BIN" --headless --path "$PROJECT_DIR" --script "res://tests/$nombre" 2>&1)"
	estado=$?
	if [ "$estado" -ne 0 ] || ! printf '%s' "$salida" | grep -q "TESTS OK"; then
		echo "FALLO: $nombre (exit=$estado)"
		printf '%s\n' "$salida"
		FALLOS=$((FALLOS + 1))
	else
		echo "OK: $nombre"
		TOTAL=$((TOTAL + 1))
	fi
done

if [ "$FALLOS" -ne 0 ]; then
	echo "BATERÍA FALLIDA: $FALLOS suite(s) fallaron, $TOTAL pasaron."
	exit 1
fi
echo "BATERÍA OK: $TOTAL suites pasaron."
```

- [ ] **Step 5: Crea .github/workflows/ci.yml**

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test-export:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Cache Godot
        id: cache-godot
        uses: actions/cache@v4
        with:
          path: |
            ~/godot-bin
            ~/.local/share/godot/export_templates
          key: godot-4.7.2

      - name: Download Godot and export templates
        if: steps.cache-godot.outputs.cache-hit != 'true'
        run: |
          set -euxo pipefail
          mkdir -p ~/godot-bin
          curl -L -o /tmp/godot.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
          unzip -o /tmp/godot.zip -d ~/godot-bin
          mv ~/godot-bin/Godot_v4.7.2-stable_linux.x86_64 ~/godot-bin/godot
          chmod +x ~/godot-bin/godot
          curl -L -o /tmp/templates.tpz https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz
          mkdir -p ~/.local/share/godot/export_templates/4.7.2.stable
          unzip -o /tmp/templates.tpz -d ~/.local/share/godot/export_templates/4.7.2.stable/

      - name: Run headless battery
        run: |
          export GODOT_BIN="$HOME/godot-bin/godot"
          bash tests/run_battery.sh

      - name: Export bundles
        run: |
          set -euxo pipefail
          G="$HOME/godot-bin/godot"
          mkdir -p build
          "$G" --headless --path . --export-release "Windows" build/gestor-de-enlaces.exe
          "$G" --headless --path . --export-release "Linux/X11" build/gestor-de-enlaces.x86_64
          "$G" --headless --path . --export-release "macOS" build/gestor-de-enlaces_macos.app
          (cd build && zip -r gestor-de-enlaces-macos.zip gestor-de-enlaces_macos.app)

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: gestor-de-enlaces-builds
          path: build/
```

Nota de mantenimiento: la tpz de export templates se extrae directamente a `~/.local/share/godot/export_templates/4.7.2.stable/`; Godot solo acepta templates si esa estructura es exacta — `--export-release` fallaría en CI si la estructura no está bien puesta. La exportación de macOS produce un `.app` (en Linux no se genera `.dmg`); el workflow lo comprime a zip.

- [ ] **Step 6: Crea AGENTS.md**

```markdown
# GestorAO — Guía del repo

Proyecto Godot 4.7.2 (GDScript). Motor local: `K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe`.

## Batería de tests (headless)

Cada suite: `tests/test_<area>.gd` (extends SceneTree; imprime `TESTS OK` y `quit(0)`).

Pwsh (Windows):

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_<area>.gd
```

Suites completas (Linux/CI):

```bash
GODOT_BIN=/ruta/a/godot bash tests/run_battery.sh
```

## Regenerar export_presets.cfg

1. Abre el proyecto en el editor Godot (`godot --path . -e`).
2. Proyecto → Exportar… → reconfigura los 3 presets (Windows, Linux/X11, macOS).
3. cierra el editor; `export_presets.cfg` se reescribe. Comitea el cambio.
   Nota: el editor reescribe el fichero a su formato; los cambios manuales se pierden.

## Generar iconos

```bash
godot --headless --path . --script res://scripts/generar_iconos.gd
```

Regenera `Assets/icon/*` (svg/png/ico/icns) desde el SVG incrustado en el script.

## Convenciones

- Sin comentarios; tabs; UI en español; preload-const en lugar de class_name (nuevo código).
- `main.gd` es el punto de integración; los stores viven en `scripts/` con test propio.
- Los tests usan bases `user://__test_*__` y se limpian.
```

- [ ] **Step 7: Corre la batería completa**

Run: `pwsh` — para cada suite `& "...Godot...exe" --headless --path ... --script res://tests/test_X.gd` con grep `TESTS OK`.
Expected: **17 suites** (12 + test_logger + test_iconos + test_proyecto + test_diagnostico + test_empaquetado) todas `TESTS OK`, exit 0.

Nota: `test_proyecto.gd` lee `res://project.godot` — correlo al final, tras restaurar `project.godot` con sus 3 claves.

- [ ] **Step 8: Commit**

```bash
git add export_presets.cfg .github/workflows/ci.yml tests/run_battery.sh AGENTS.md tests/test_empaquetado.gd
git commit -m "feat(ci/empaquetado): presets de exportación, workflow CI y batería compartida (#26)"
```

---

## Verificación final (tras la tarea 5)

- Batería **17 suites** en local, todas `TESTS OK`.
- Smoke: `Main.tscn --quit-after 90` exit 0 sin `SCRIPT ERROR`.
- `git log --oneline` con los 5 commits tickeando.
- Push a `origin/main` y cerrar #26/#28/#29 (decisión del usuario según finished).