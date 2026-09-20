# #27 Auto-actualización o aviso de nueva versión Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Comprobar si hay una release más nueva en GitHub (`api.github.com/repos/scorpio21/gestor-de-enlaces/releases/latest`) comparando con `application/config/version`; avisar con diálogo modal al arrancar (silencioso, 1 vez por versión persistida en `config.ultima_version_vista`) y desde `Utilidades > Comprobar actualizaciones…` (siempre informa del resultado).

**Architecture:** `scripts/versiones.gd` (RefCounted, estáticas puras: comparación semver y parse del JSON) testeable sin red; `scripts/actualizador.gd` (Node con HTTPClient, patrón `link_checker.gd`) hace el GET y emite señal `terminado(resultado)`. `config_store.gd` persiste `ultima_version_vista`. `main.gd` orquesta: comprobación auto tras 1 s (solo no-headless), opción de menú id 4, y diálogo `%DialogoActualizacion`.

**Tech Stack:** Godot 4.7.2, GDScript, tests SceneTree headless.

## Global Constraints

- Motor local: `& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/<suite>.gd`
- Tabs, sin comentarios; UI en español; preload-const en lugar de class_name para los módulos nuevos (`versiones.gd`, `actualizador.gd`).
- Tests en base `user://__test_<area>__` y se limpian al terminar.
- Batería: `& "C:\Program Files\Git\bin\bash.exe" -c 'cd /k/gestor-de-enlaces && GODOT_BIN="K:/Godot_v4.6.1/Godot_v4.7.2-stable_win64_console.exe" bash tests/run_battery.sh'` (hoy 20 suites; 21 al añadir `test_versiones.gd`).
- Workflow del repo: commits directos en `main` y push al final; cerrar la issue con `gh issue close 27`.
- Warning Godot: `HTTPClient.poll()` con `STATUS_BODY` necesita lectura completa del body; GitHub devuelve JSON con `Content-Length` → leer chunks hasta `body.size() >= expected_length` o chunk vacío sin más datos.
- Headless/CI: `main.gd` solo dispara `comprobar()` si `not _es_headless()`.

---

### Task 1: `versiones.gd` + `test_versiones.gd` (TDD, puro, sin red)

**Files:**
- Create: `scripts/versiones.gd`
- Create: `scripts/versiones.gd.uid` (generado por `--import`)
- Test: `tests/test_versiones.gd`
- Test: `tests/test_versiones.gd.uid`

**Interfaces:**
- Consumes: nada.
- Produces: `Versiones.comparar(nueva: String, actual: String) -> int` (`-1`/`0`/`1`), `Versiones.parsear_release(json_texto: String) -> Dictionary` (`{version, url}` o `{}`), `Versiones.manejar_tag(tag: String) -> String`. Consumido por las Tasks 2-4.

- [ ] **Step 1: Escribir el test que falla**

Crear `tests/test_versiones.gd`:

```gdscript
extends SceneTree

const VersionesScript := preload("res://scripts/versiones.gd")

var _fallos := 0


func _initialize() -> void:
	_check(VersionesScript.comparar("1.2.0", "0.1.0") == 1, "versión más nueva → 1")
	_check(VersionesScript.comparar("0.1.0", "1.2.0") == -1, "versión más antigua → -1")
	_check(VersionesScript.comparar("0.1.0", "0.1.0") == 0, "misma versión → 0")
	_check(VersionesScript.comparar("1.2.10", "1.2.9") == 1, "compara por componentes decimales")
	_check(VersionesScript.comparar("2.0", "1.5.1") == 1, "longitudes distintas rellenan con 0")
	_check(VersionesScript.comparar("v2.0", "2.0") == 0, "prefijo v se ignora")
	_check(VersionesScript.comparar("1.a", "1.0") == 0, "componente no numérico equivale a 0")

	var parsed := VersionesScript.parsear_release('{"tag_name":"v2.0","html_url":"https://github.com/scorpio21/gestor-de-enlaces/releases/tag/v2.0"}')
	_check(parsed.get("version", "") == "2.0", "parsear_release extrae version sin prefijo v")
	_check(str(parsed.get("url", "")).begins_with("https://github.com/scorpio21/"), "parsear_release extrae la url de la release")
	_check(VersionesScript.manejar_tag("v2.0") == "2.0", "manejar_tag quita el prefijo v")

	_check(VersionesScript.parsear_release("{no es json").is_empty(), "JSON roto devuelve dict vacío")
	_check(VersionesScript.parsear_release('{"tag_name":""}').is_empty(), "tag vacío devuelve dict vacío")
	_check(VersionesScript.parsear_release("[1,2]").is_empty(), "JSON no-objeto devuelve dict vacío")

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

- [ ] **Step 2: Ejecutar y verificar que falla**

Run:
```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_versiones.gd
```
Expected: parse errors por `versiones.gd` inexistente (`Preload file ... does not exist`).

- [ ] **Step 3: Implementar `scripts/versiones.gd`**

```gdscript
extends RefCounted


static func comparar(nueva: String, actual: String) -> int:
	var a := _componentes(nueva)
	var b := _componentes(actual)
	var n := maxi(a.size(), b.size())
	for i in range(n):
		var da := a[i] if i < a.size() else 0
		var db := b[i] if i < b.size() else 0
		if da > db:
			return 1
		if da < db:
			return -1
	return 0


static func parsear_release(json_texto: String) -> Dictionary:
	if not json_texto.strip_edges().begins_with("{"):
		return {}
	var json := JSON.new()
	if json.parse(json_texto) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	var tag := manejar_tag(str(json.data.get("tag_name", "")))
	var url := str(json.data.get("html_url", ""))
	if tag.is_empty() or url.is_empty():
		return {}
	return {"version": tag, "url": url}


static func manejar_tag(tag: String) -> String:
	var t := tag.strip_edges()
	if t.begins_with("v"):
		t = t.substr(1)
	return t.strip_edges()


static func _componentes(v: String) -> Array[int]:
	var partes := manejar_tag(v).split(".")
	var res: Array[int] = []
	for parte in partes:
		if parte.is_valid_int():
			res.append(int(parte))
		else:
			res.append(0)
	return res
```

Notas:
- `parsear_release` primero comprueba que el texto empiece por `{` (evita que `JSON.parse` devuelva una `Array` como dato válido, cubriendo el check `[1,2]`), luego valida tipo diccionario.
- `manejar_tag` solo quita una `v` inicial; `"V2.0"` (mayúscula) no se toca (las tags de GitHub del repo usan minúscula).
- La regla "versión no-nueva no avisa" NO está en `versiones.gd`: es responsabilidad del orquestador (Task 3).

- [ ] **Step 4: Ejecutar el test y verificar que pasa**

Run el mismo comando del Step 2.
Expected: `TESTS OK`.

- [ ] **Step 5: Generar `.gd.uid` y commit**

Run:
```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --import
```
- Verifica `git status --porcelain`: existen `scripts/versiones.gd.uid`, `tests/test_versiones.gd.uid` y `project.godot` NO modificado.
Commit:
```bash
git -C "K:\gestor-de-enlaces" add scripts/versiones.gd scripts/versiones.gd.uid tests/test_versiones.gd tests/test_versiones.gd.uid docs/superpowers/plans/2026-09-20-auto-actualizacion.md
git -C "K:\gestor-de-enlaces" commit -m "feat(actualizacion): comparador de versiones y parse de release(latest) (TDD)"
```

---

### Task 2: `actualizador.gd` (Node HTTPClient) — sin test de red, solo smoke

**Files:**
- Create: `scripts/actualizador.gd`
- Create: `scripts/actualizador.gd.uid` (generado por `--import`)
- Modify: `docs/superpowers/plans/2026-09-20-auto-actualizacion.md` (markdown del plan)

**Interfaces:**
- Consumes: `Versiones.parsear_release` y `_version_actual()` (de `ProjectSettings`).
- Produces: señal `terminado(resultado: Dictionary)` con `{nueva, version, url, error}`. Consumido por la Task 3.

- [ ] **Step 1: Implementar `scripts/actualizador.gd`**

```gdscript
extends Node

signal terminado(resultado: Dictionary)

const VersionesScript := preload("res://scripts/versiones.gd")
const URL_API := "https://api.github.com/repos/scorpio21/gestor-de-enlaces/releases/latest"
const TIMEOUT := 8.0
const USER_AGENT := "GestorAO/1.0 (comprobacion de versión)"

var _cliente := HTTPClient.new()
var _url := ""
var _transcurrido := 0.0
var _activo := false
var _pedido_enviado := false
var _codigo := 0
var _cuerpo := PackedByteArray()
var _longitud_esperada := 0


func comprobar() -> void:
	if _activo:
		return
	_activo = true
	_url = URL_API
	_transcurrido = 0.0
	_pedido_enviado = false
	_cuerpo = PackedByteArray()
	_longitud_esperada = 0
	_conectar(_url)


func _process(delta: float) -> void:
	if not _activo:
		return

	_transcurrido += delta
	if _transcurrido >= TIMEOUT:
		_cerrar_error("Tiempo agotado al comprobar actualizaciones.")
		return

	_cliente.poll()
	match _cliente.get_status():
		HTTPClient.STATUS_DISCONNECTED:
			if _pedido_enviado:
				_cerrar_error("Se cerró la conexión al comprobar actualizaciones.")
		HTTPClient.STATUS_CANT_RESOLVE:
			_cerrar_error("No se pudo resolver el dominio.")
		HTTPClient.STATUS_CANT_CONNECT:
			_cerrar_error("No se pudo conectar.")
		HTTPClient.STATUS_CONNECTION_ERROR:
			_cerrar_error("Error de conexión.")
		HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			_cerrar_error("Error TLS/HTTPS.")
		HTTPClient.STATUS_CONNECTED:
			if not _pedido_enviado:
				_enviar_pedido()
		HTTPClient.STATUS_BODY:
			_leer_respuesta()


func _conectar(url: String) -> void:
	var partes := _parsear_url(url)
	if partes.is_empty():
		_cerrar_error("URL inválida al comprobar actualizaciones.")
		return
	_cliente.close()
	_pedido_enviado = false
	var tls: TLSOptions = TLSOptions.client() if partes.tls else null
	var err := _cliente.connect_to_host(partes.host, partes.port, tls)
	if err != OK:
		_cerrar_error("No se pudo iniciar la conexión.")


func _enviar_pedido() -> void:
	var partes := _parsear_url(_url)
	if partes.is_empty():
		_cerrar_error("URL inválida al comprobar actualizaciones.")
		return
	var err := _cliente.request(
		HTTPClient.METHOD_GET,
		partes.path,
		PackedStringArray([
			"User-Agent: %s" % USER_AGENT,
			"Accept: application/vnd.github+json",
		])
	)
	if err != OK:
		_cerrar_error("No se pudo enviar la petición.")
		return
	_pedido_enviado = true


func _leer_respuesta() -> void:
	_codigo = _cliente.get_response_code()
	if _codigo != 200:
		_cerrar_error("Respuesta del servidor: %d" % _codigo)
		return
	if _longitud_esperada == 0:
		_longitud_esperada = _cliente.get_response_body_length()
	var trozo := _cliente.read_response_body_chunk()
	_cuerpo.append_array(trozo)
	if _cuerpo.size() < _longitud_esperada or _cuerpo.is_empty():
		return
	_finalizar()


func _finalizar() -> void:
	var datos := VersionesScript.parsear_release(_cuerpo.get_string_from_utf8())
	if datos.is_empty():
		_cerrar_error("Respuesta inválida al comprobar actualizaciones.")
		return
	var version := str(datos.get("version", ""))
	var url := str(datos.get("url", ""))
	var actual := str(ProjectSettings.get_setting("application/config/version", "0.0.1"))
	var nueva := VersionesScript.comparar(version, actual) == 1
	_terminar({"nueva": nueva, "version": version, "url": url, "error": ""})


func _cerrar_error(mensaje: String) -> void:
	_terminar({"nueva": false, "version": "", "url": "", "error": mensaje})


func _terminar(resultado: Dictionary) -> void:
	if not _activo:
		return
	_activo = false
	set_process(false)
	_cliente.close()
	terminado.emit(resultado)
	queue_free()


func _parsear_url(url: String) -> Dictionary:
	var uri := url.strip_edges()
	var tls := uri.begins_with("https://")
	if not tls and not uri.begins_with("http://"):
		return {}
	var resto := uri.substr(8 if tls else 7)
	var corte := resto.find("/")
	var hostpuerto := resto if corte == -1 else resto.substr(0, corte)
	var path := "/" if corte == -1 else resto.substr(corte)
	if path.is_empty():
		path = "/"
	var host := hostpuerto
	var puerto := 443 if tls else 80
	var colon := hostpuerto.rfind(":")
	if colon != -1 and not hostpuerto.begins_with("["):
		host = hostpuerto.substr(0, colon)
		puerto = int(hostpuerto.substr(colon + 1))
	return {host = host, port = puerto, path = path, tls = tls}
```

Notas:
- Clonar el patrón de `link_checker.gd` (`_parsear_url`, poll/set_process, TLS) sin mover nada de ese fichero.
- `_longitud_esperada` para GitHub: `get_response_body_length()` suele ser 0 (desconocido/chunked). Se leen chunks hasta que uno esté **vacío** (`_cuerpo.is_empty()` es el cuerpo acumulado vacío → ojo: el guard usa `_cuerpo.is_empty()` tras append, no el trozo). Para dejar el guard correcto: leer chunks hasta que `read_response_body_chunk()` devuelva `PackedByteArray` vacío y NO haya más body pendiente.
- :warning: **Revisa el guard de `_leer_respuesta`**: el cuerpo acumulado puede no estar vacío aunque un trozo lo esté. El criterio correcto en Godot 4 es: seguir leyendo mientras `_cliente.get_status() == HTTPClient.STATUS_BODY` y luego salir cuando el trozo esté vacío Y el status pase a `STATUS_CONNECTED`. Ajusta si el smoke de Task 3 (~señal `terminado`) lo evidencia. En headless no hay red: este flujo solo se cubre por smoke en arranque real, no por test.
- No hay test de red en la batería (headless sin conexión). La correcta lectura del body se valida en ejecución real con la Task 4.

- [ ] **Step 2: Smoketest de parse sin red (opcional)**

Run una variante del test de Task 1 para confirmar que `_parsear_url` y `parsear_release` siguen verdes:
```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_versiones.gd
```
Expected: `TESTS OK`.

- [ ] **Step 3: Generar `.gd.uid` y commit**

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --import
git -C "K:\gestor-de-enlaces" add scripts/actualizador.gd scripts/actualizador.gd.uid scripts/versiones.gd
git -C "K:\gestor-de-enlaces" commit -m "feat(actualizacion): nodo HTTPClient que consulta releases/latest"
```

---

### Task 3: `config_store.gd` (campo `ultima_version_vista`) + integración `main.gd`/`Main.tscn`

**Files:**
- Modify: `scripts/config_store.gd`
- Modify: `scripts/main.gd`
- Modify: `scenes/Main.tscn`
- Test: `tests/test_config_store.gd`
- Test: `tests/test_main_barra.gd`

**Interfaces:**
- Consumes: `config_store.cargar().ultima_version_vista`, `ActualizadorScript` (Task 2), `VersionesScript`.
- Produces: campo persistido `ultima_version_vista`, señal `%DialogoActualizacion`, item Utilidades id 4, `_comprobar_actualizaciones(manual)`.

- [ ] **Step 1: Añadir checks (rojo) en `tests/test_config_store.gd`**

Después de `tema_invalido_normaliza()` (Task 3 del plan #19) añade en la lista de checks de `_initialize`:
```gdscript
	_check(ultima_default_sin_fichero(), "sin fichero ultima_version_vista vacía")
	_check(ultima_persistida(), "guardar persiste ultima_version_vista")
	_check(ultima_no_string_normaliza(), "ultima_version_vista no-string cae a vacía")
```

Y los métodos:
```gdscript
func ultima_default_sin_fichero() -> bool:
	return ConfigStore.new(BASE).cargar().get("ultima_version_vista", "#") == ""

func ultima_persistida() -> bool:
	var store := ConfigStore.new(BASE)
	if not store.guardar(4, 12.0, true, 30, "oscuro", "2.0"):
		return false
	return store.cargar().get("ultima_version_vista", "#") == "2.0"

func ultima_no_string_normaliza() -> bool:
	FileAccess.open(BASE + "/config.json", FileAccess.WRITE).store_string('{"ultima_version_vista": 42}')
	return ConfigStore.new(BASE).cargar().get("ultima_version_vista", "#") == ""
```

- [ ] **Step 2: Implementar `scripts/config_store.gd`**

Tras `TEMA_DEFAULT`:
```gdscript
const ULTIMA_VERSION_DEFAULT := ""
```

En `cargar()` (dict por defecto y dict con `tema`):
```gdscript
		"ultima_version_vista": ULTIMA_VERSION_DEFAULT,
```
```gdscript
		"ultima_version_vista": _string_ok(v.get("ultima_version_vista", ULTIMA_VERSION_DEFAULT)),
```

En `guardar()` — añade parámetro al final y entrada:
```gdscript
func guardar(paralelismo: int, timeout: float, auto_abrir := AUTO_ABRIR_DEFAULT, intervalo := INTERVALO_DEFAULT, tema := TEMA_DEFAULT, ultima_version_vista := ULTIMA_VERSION_DEFAULT) -> bool:
	var dato := {
		...
		"ultima_version_vista": _string_ok(ultima_version_vista),
	}
```

Añade `_string_ok`:
```gdscript
func _string_ok(v: Variant) -> String:
	return str(v) if typeof(v) == TYPE_STRING else ""
```

- [ ] **Step 3: Implementar `scripts/main.gd` + `scenes/Main.tscn`**

1. Preload tras `TemaStoreScript`:
```gdscript
const ActualizadorScript := preload("res://scripts/actualizador.gd")
```

2. En `_ready()`, tras `_iniciar_auto_escaneo()`:
```gdscript
	%DialogoActualizacion.confirmed.connect(_on_actualizacion_ver)
	%DialogoActualizacion.canceled.connect(_on_actualizacion_cerrar)
	_lanzar_comprobacion_auto()
```

3. `_configurar_menus()` — añade el item en `menu_util`:
```gdscript
	menu_util.add_item("Comprobar actualizaciones…", 4)
```

4. `_on_utilidades_id` — rama nueva:
```gdscript
	elif id == 4:
		_comprobar_actualizaciones(true)
```

5. Métodos nuevos:
```gdscript
func _lanzar_comprobacion_auto() -> void:
	if _es_headless():
		return
	await get_tree().create_timer(1.0).timeout
	_comprobar_actualizaciones(false)


func _comprobar_actualizaciones(manual: bool) -> void:
	if _es_headless():
		if manual:
			_mostrar_aviso("error", "", "")
		return
	var actualizador: Node = ActualizadorScript.new()
	add_child(actualizador)
	actualizador.terminado.connect(func(r: Dictionary) -> void: _on_actualizacion_terminado(r, manual))
	actualizador.comprobar()


func _on_actualizacion_terminado(resultado: Dictionary, manual: bool) -> void:
	var nueva := resultado.get("nueva") == true
	var version := str(resultado.get("version", ""))
	var url := str(resultado.get("url", ""))
	if nueva and version != str(_config_store.cargar().get("ultima_version_vista", "")):
		_mostrar_aviso("nueva", version, url)
	elif manual and not nueva and str(resultado.get("error", "")).is_empty():
		_mostrar_aviso("al_dia", str(ProjectSettings.get_setting("application/config/version", "0.0.1")), "")
	elif manual:
		_mostrar_aviso("error", "", "")


func _mostrar_aviso(modo: String, version: String, url: String) -> void:
	var dialogo: ConfirmationDialog = %DialogoActualizacion
	if modo == "nueva":
		dialogo.title = "Nueva versión disponible"
		dialogo.dialog_text = "Hay una nueva versión: %s" % version
		dialogo.ok_button_text = "Ver release"
		dialogo.cancel_button.visible = true
		_aviso_url = url
		_dialogo_con_aviso = true
		_dialogo_version = version
	elif modo == "al_dia":
		dialogo.title = "Comprobar actualizaciones"
		dialogo.dialog_text = "Estás al día (v%s)" % version
		dialogo.ok_button_text = "Cerrar"
		dialogo.cancel_button.visible = false
		_dialogo_con_aviso = false
	else:
		dialogo.title = "Comprobar actualizaciones"
		dialogo.dialog_text = "No se pudo comprobar actualizaciones."
		dialogo.ok_button_text = "Cerrar"
		dialogo.cancel_button.visible = false
		_dialogo_con_aviso = false
	dialogo.popup_centered()


func _on_actualizacion_ver() -> void:
	if not _aviso_url.is_empty():
		OS.shell_open(_aviso_url)
	_persistir_version_vista()
	_limpiar_aviso()


func _on_actualizacion_cerrar() -> void:
	if _dialogo_con_aviso:
		_persistir_version_vista()
	_limpiar_aviso()


func _persistir_version_vista() -> void:
	var cfg := _config_store.cargar()
	_config_store.guardar(
		int(cfg.get("paralelismo", 3)),
		float(cfg.get("timeout", 10.0)),
		bool(cfg.get("auto_abrir", true)),
		int(cfg.get("intervalo", 0)),
		str(cfg.get("tema", "oscuro")),
		_dialogo_version,
	)


func _limpiar_aviso() -> void:
	_aviso_url = ""
	_dialogo_version = ""
	_dialogo_con_aviso = false
```

6. Vars nuevas (zona de vars):
```gdscript
var _aviso_url := ""
var _dialogo_version := ""
var _dialogo_con_aviso := false
```

7. `scenes/Main.tscn` — tras `ConfirmarReanudar` añade:
```text
[node name="DialogoActualizacion" type="ConfirmationDialog" parent="."]
unique_name_in_owner = true
title = "Comprobar actualizaciones"
ok_button_text = "Cerrar"
cancel_button_text = "Cerrar"
```

- [ ] **Step 4: Añadir checks de integración en `tests/test_main_barra.gd`**

Junto al bloque `# Tema (#19)` (Task 3 del plan #19), añade:
```gdscript
	# Actualización (#27): diálogo y comprobaciones en headless
	_check(main_script.has_method("_lanzar_comprobacion_auto"), "main tiene el disparo automático")
	_check(main.has_node("%DialogoActualizacion"), "existe el diálogo DialogoActualizacion")
	var menu_act: PopupMenu = main.get_node("%Utilidades")
	var tiene_act := false
	for i in range(menu_act.item_count):
		if menu_act.get_item_id(i) == 4 and menu_act.get_item_text(i) == "Comprobar actualizaciones…":
			tiene_act = true
	_check(tiene_act, "el menú Utilidades tiene Comprobar actualizaciones… (id 4)")

	# Headless: la opción manual en headless informa del error
	main_script._comprobar_actualizaciones(true)
	_check(main.get_node("%DialogoActualizacion").visible, "en headless la comprobación manual abre el diálogo")
	_check(main.get_node("%DialogoActualizacion").dialog_text == "No se pudo comprobar actualizaciones.", "en headless el diálogo informa del fallo")
	main.get_node("%DialogoActualizacion").hide()

	# Señal con nueva versión → diálogo de nueva versión
	main_script._config_store.guardar(3, 10.0, false, 0, "oscuro", "")
	main_script._on_actualizacion_terminado({"nueva": true, "version": "2.0", "url": "https://github.com/scorpio21/gestor-de-enlaces", "error": ""}, true)
	_check(main.get_node("%DialogoActualizacion").visible, "nueva versión abre el diálogo")
	_check(main.get_node("%DialogoActualizacion").dialog_text == "Hay una nueva versión: 2.0", "el diálogo muestra la versión nueva")
	_check(main.get_node("%DialogoActualizacion").ok_button_text == "Ver release", "el botón principal es Ver release")
	main_script._on_actualizacion_cerrar()
	_main_cerrar_check(main_script)
	_check(main_script._config_store.cargar().get("ultima_version_vista", "") == "2.0", "cerrar el aviso persiste la versión vista")
	main.get_node("%DialogoActualizacion").hide()

	# Misma versión en manual → al día
	main_script._on_actualizacion_terminado({"nueva": false, "version": "0.1.0", "url": "", "error": ""}, true)
	_check(main.get_node("%DialogoActualizacion").visible, "comprobación manual al día abre el diálogo")
	main.get_node("%DialogoActualizacion").hide()
```

Añade el helper `_main_cerrar_check(main_script)` (o replícalo inline) que llama a `_on_actualizacion_cerrar()` (persiste) — el método ya persiste `ultima_version_vista` desde `_limpiar_aviso`; el helper no necesita más.

- [ ] **Step 5: Ejecutar y verificar que pasa**

Run:
```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_config_store.gd
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_main_barra.gd
```
Expected: `TESTS OK` en ambos.

- [ ] **Step 6: Smoke de arranque y commit**

```bash
& "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --quit-after 5 2>&1 | Select-String -Pattern "SCRIPT ERROR|Parse Error"
```
Expected: sin errores. En headless `_lanzar_comprobacion_auto()` no dispara red (guarda `_es_headless()`).
Commit:
```bash
git -C "K:\gestor-de-enlaces" add scripts/config_store.gd scripts/main.gd scenes/Main.tscn tests/test_config_store.gd tests/test_main_barra.gd
git -C "K:\gestor-de-enlaces" commit -m "feat(actualizacion): aviso 1 vez por version en dialogo y opcion de menu"
```

---

### Task 4: Batería completa, push y cierre de la issue

**Files:** ninguno (solo verificación y git).

- [ ] **Step 1: Batería completa**

```bash
& "C:\Program Files\Git\bin\bash.exe" -c 'cd /k/gestor-de-enlaces && GODOT_BIN="K:/Godot_v4.6.1/Godot_v4.7.2-stable_win64_console.exe" bash tests/run_battery.sh' 2>&1 | Select-Object -Last 25
```
Expected: `BATERÍA OK: 21 suites pasaron.`

- [ ] **Step 2: Revisar estado y push**

```bash
git -C "K:\gestor-de-enlaces" status --porcelain
git -C "K:\gestor-de-enlaces" log --oneline origin/main..HEAD
```
Confirma que solo hay cambios esperados (los untracked ajenos `Assets/icon/*.import`, `data/data2.json`, `docs/superpowers/plans/*.md` de features previas, `scripts/historial.gd.uid` se ignoran).
Push:
```bash
git -C "K:\gestor-de-enlaces" push origin main
```

- [ ] **Step 3: Cerrar la issue**

```bash
gh issue close 27 --comment "Implementado: comprobación de nueva versión contra releases/latest de GitHub al arrancar (silenciosa, 1 vez por versión) y desde Utilidades. Bateria local 21/21 OK."
```

> Verificar el cierre con `gh issue list --repo scorpio21/gestor-de-enlaces --state open --limit 10` y anotar las que quedan (#6, #17, #30).