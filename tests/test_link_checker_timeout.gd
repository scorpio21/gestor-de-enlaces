extends SceneTree

const LinkChecker := preload("res://scripts/link_checker.gd")
const ServidorHttp := preload("res://tests/servidor_http.gd")

var _fallos := 0
var _emitido_1 := false
var _valido_1 := true
var _mensaje_1 := ""
var _emitido_2 := false

var _srv: RefCounted = null
var _fin := false
var _valido := true
var _mensaje := ""
var _leidos := 0
var _evidencia := ""
var _intentos := 1
var _transitorio := false
var _motivo := ""
var _codigo := 0
var _url_final := ""


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	# Defaults
	var checker := LinkChecker.new()
	_check(is_equal_approx(checker.timeout_s, 10.0), "timeout_s tiene default 10.0")
	checker.timeout_s = 25.0
	_check(is_equal_approx(checker.timeout_s, 25.0), "timeout_s es asignable")
	_check(checker.codigo == 0, "codigo tiene default 0")
	checker.codigo = 404
	_check(checker.codigo == 404, "codigo es asignable")
	checker.free()

	# Presupuesto de cuerpo (#53)
	_check(LinkChecker.LIMITE_CUERPO == 65536, "LIMITE_CUERPO son 64 KB")
	_check(LinkChecker.ESPERA_CUERPO > 0.0 and LinkChecker.ESPERA_CUERPO < 1.0, "ESPERA_CUERPO es una fracción de segundo")

	# Marcadores de página muerta (#31)
	var marcas: PackedStringArray = LinkChecker.MARCAS_MUERTO
	_check(marcas.size() > 0, "MARCAS_MUERTO no está vacío")
	var todas_ok := true
	for m in marcas:
		if String(m).strip_edges().is_empty():
			todas_ok = false
	_check(todas_ok, "ninguna marca está vacía")

	var cpm := LinkChecker.new()
	_check(cpm._parece_muerto(404, "") == true, "_parece_muerto: 404 siempre muerto")
	_check(cpm._parece_muerto(410, "<html>hola</html>") == true, "_parece_muerto: 410 siempre muerto")
	_check(cpm._parece_muerto(200, "") == false, "_parece_muerto: 200 sin html no es muerto")
	_check(cpm._parece_muerto(200, "page not found") == true, "_parece_muerto: 200 con marcador es muerto")
	_check(cpm._parece_muerto(200, "<html>normal</html>") == false, "_parece_muerto: 200 sin marcador no es muerto")
	cpm.free()

	# Marcas por host (#12)
	var mh := LinkChecker.new()
	var marcas_mega: PackedStringArray = mh._marcas_para_host("mega.nz")
	_check(marcas_mega.has("this file is no longer available"), "_marcas_para_host('mega.nz') incluye marca específica")
	_check(marcas_mega.has("page not found"), "_marcas_para_host('mega.nz') conserva genéricas (unión)")
	_check(marcas_mega.size() == LinkChecker.MARCAS_MUERTO.size() + 3, "_marcas_para_host('mega.nz') suma 3 específicas a las genéricas")

	var marcas_drive: PackedStringArray = mh._marcas_para_host("www.drive.google.com")
	_check(marcas_drive.has("the file you have selected does not exist"), "_marcas_para_host con subdominio resuelve por sufijo")

	var marcas_otro: PackedStringArray = mh._marcas_para_host("otro.host")
	_check(marcas_otro == LinkChecker.MARCAS_MUERTO, "_marcas_para_host host desconocido devuelve solo genéricas")
	_check(mh._marcas_para_host("") == LinkChecker.MARCAS_MUERTO, "_marcas_para_host('') devuelve genéricas")
	mh.free()

	# _parece_muerto con host (#12)
	var cpi := LinkChecker.new()
	cpi._host_actual = "mega.nz"
	_check(cpi._parece_muerto(200, "note: this file is no longer available") == true, "_parece_muerto host conocido con marca específica es muerto")
	_check(cpi._parece_muerto(200, "<html>normal</html>") == false, "_parece_muerto host conocido sin marcas no es muerto")
	_check(cpi._parece_muerto(200, "page not found") == true, "_parece_muerto host conocido con marca genérica es muerto (unión)")
	_check(cpi._parece_muerto(200, "this transfer has expired") == false, "_parece_muerto marca específica de otro host no aplica")
	cpi.free()

	# Parseo de URL (#31)
	var cp := LinkChecker.new()
	var p1 := cp._parsear_url("https://example.com")
	_check(str(p1.get("host", "")) == "example.com" and int(p1.get("port", 0)) == 443 and str(p1.get("path", "")) == "/" and p1.get("tls", false) == true, "_parsear_url: https estándar")
	var p2 := cp._parsear_url("http://ej.com:8080/x")
	_check(str(p2.get("host", "")) == "ej.com" and int(p2.get("port", 0)) == 8080 and str(p2.get("path", "")) == "/x" and p2.get("tls", false) == false, "_parsear_url: http con puerto y path")
	_check(cp._parsear_url("ftp://x.com").is_empty(), "_parsear_url: esquema no http(s) es inválido")
	_check(cp._parsear_url("ejemplo.com/ruta").is_empty(), "_parsear_url: sin esquema es inválido")
	var p6 := cp._parsear_url("https://[::1]/")
	_check(str(p6.get("host", "")) == "[::1]" and int(p6.get("port", 0)) == 443, "_parsear_url: IPv6 en corchetes conserva host")
	cp.free()

	# Resolución de redirecciones (#31)
	var cr := LinkChecker.new()
	_check(cr._resolver_redirect("https://a.test/origen", "http://otro.test/x") == "http://otro.test/x", "_resolver_redirect: destino absoluto intacto")
	_check(cr._resolver_redirect("https://a.test/origen", "/nuevo") == "https://a.test:443/nuevo", "_resolver_redirect: destino relativo usa host y puerto")
	cr.free()

	# comprobar sin red: URLs inválidas emiten terminado síncrono (#31)
	var c1 := LinkChecker.new()
	_emitido_1 = false
	_valido_1 = true
	_mensaje_1 = ""
	c1.terminado.connect(func(v: bool, m: String, _c: int, _d: String) -> void:
		_emitido_1 = true
		_valido_1 = v
		_mensaje_1 = m)
	c1.comprobar("")
	_check(_emitido_1 and not _valido_1 and _mensaje_1 == "URL inválida" and not c1._activo, "comprobar('') emite terminado(false, 'URL inválida') sin red")

	var c2 := LinkChecker.new()
	_emitido_2 = false
	c2.terminado.connect(func(v: bool, _m: String, _c: int, _d: String) -> void:
		_emitido_2 = true)
	c2.comprobar("gopher://x")
	_check(_emitido_2 and not c2._activo, "comprobar('gopher://x') emite terminado sin red")

	await _red()

	_cerrar()


# --- Escenarios con un servidor HTTP local (#53) ---

func _red() -> void:
	_srv = ServidorHttp.new()
	if not _srv.arrancar():
		_check(false, "el servidor local escucha")
		return

	# 200 con la página de "no existe" repartida en 4 trozos: el marcador llega tarde
	var relleno := "x".repeat(3800)
	var cuerpo_muerto := "<html><head><title>Error</title></head><body>" + relleno + "PAGE NOT FOUND</body></html>"
	var r1: Dictionary = await _comprobar([{
		"estado": "200 OK", "cuerpo": cuerpo_muerto, "trozos": 4, "espera": 2,
	}])
	_check(bool(r1.get("fin", false)), "un 200 con cuerpo troceado termina la comprobación")
	_check(not bool(r1.get("valido", true)), "un 200 cuya página de error llega tarde se marca muerto (#53)")
	_check(str(r1.get("mensaje", "")) == "No existe (200)", "el mensaje del 200 con marcador es 'No existe (200)'")
	_check(str(r1.get("cuerpo", "")).contains("page not found"), "el cuerpo se acumula entre trozos hasta encontrar la marca")

	# Petición con Range para no bajar el archivo entero
	var r2: Dictionary = await _comprobar([{"estado": "200 OK", "cuerpo": "<html>hola</html>"}])
	_check(bool(r2.get("valido", false)) and str(r2.get("mensaje", "")) == "OK (200)", "un 200 normal se da por válido")
	var peticiones: PackedStringArray = r2.get("peticiones", PackedStringArray())
	_check(peticiones.size() == 1 and peticiones[0].to_lower().contains("range: bytes=0-65535"), "la petición pide solo los primeros 64 KB con Range (#53)")
	_check(str(r2.get("url_final", "")).is_empty(), "sin redirecciones no hay URL final que proponer (#59)")

	# 206 (respuesta parcial) se reporta como 200
	var r3: Dictionary = await _comprobar([{
		"estado": "206 Partial Content", "cuerpo": "<html>hola</html>",
		"extra": "Content-Range: bytes 0-14/15\r\n",
	}])
	_check(bool(r3.get("valido", false)) and str(r3.get("mensaje", "")) == "OK (200)", "un 206 con Range se reporta como OK (200)")

	# Archivo vacío: 416 y reintento sin Range
	var r4: Dictionary = await _comprobar([
		{"estado": "416 Range Not Satisfiable", "cerrar": true},
		{"estado": "200 OK", "cuerpo": ""},
	])
	_check(bool(r4.get("valido", false)) and str(r4.get("mensaje", "")) == "OK (200)", "un 416 se reintenta sin Range y no marca el enlace como caído (#53)")
	var pet4: PackedStringArray = r4.get("peticiones", PackedStringArray())
	_check(pet4.size() == 2 and not pet4[1].to_lower().contains("range:"), "el reintento tras un 416 va sin Range")

	# Presupuesto: no se baja un archivo grande entero
	var r5: Dictionary = await _comprobar([{
		"estado": "200 OK", "longitud": 5000000, "cuerpo": "A".repeat(200000), "trozos": 100,
	}])
	_check(bool(r5.get("valido", false)), "un archivo grande con 200 sigue siendo válido")
	_check(int(r5.get("leidos", 0)) <= LinkChecker.LIMITE_CUERPO, "se leen como mucho 64 KB del cuerpo (#53)")
	_check(int(r5.get("leidos", 0)) > 0, "se lee algo de cuerpo antes de decidir")
	_check(int(r5.get("enviados", 0)) < 150000, "el servidor no llega a mandar el archivo entero (%d bytes)" % int(r5.get("enviados", 0)))

	# Cuerpo sin Content-Length (chunked): el cliente no lo expone, pero decide igual
	var r6: Dictionary = await _comprobar([{
		"estado": "200 OK", "cuerpo": "<html>hola</html>", "trozos": 2,
		"extra": "Transfer-Encoding: chunked\r\n",
	}])
	_check(bool(r6.get("fin", false)) and bool(r6.get("valido", false)), "una respuesta chunked sin Content-Length no deja la comprobación colgada (#53)")
	_check(int(r6.get("leidos", -1)) == 17, "una respuesta chunked también aporta evidencia de cuerpo (17 bytes)")

	# El servidor manda 17 de los 5000 bytes anunciados y cierra: tampoco es error
	var r7: Dictionary = await _comprobar([{
		"estado": "200 OK", "longitud": 5000, "cuerpo": "<html>hola</html>", "cerrar": true,
	}])
	_check(bool(r7.get("valido", false)) and str(r7.get("mensaje", "")) == "OK (200)", "un cuerpo cortado por el servidor se da por válido, no por error (#53)")

	# El cuerpo llega a goteo hasta agotar el timeout
	var r8: Dictionary = await _comprobar([{
		"estado": "200 OK", "longitud": 5000000, "cuerpo": "B".repeat(400), "trozos": 400, "ritmo": 4,
	}], 0.3)
	_check(bool(r8.get("fin", false)), "un cuerpo que no termina agota el timeout")
	_check(not bool(r8.get("valido", true)) and str(r8.get("mensaje", "")) == "Sin respuesta (tiempo agotado)", "el timeout cubre también la lectura del cuerpo (#53)")

	# 404 sigue decidiéndose por el código, sin esperar al cuerpo
	var r9: Dictionary = await _comprobar([{"estado": "404 Not Found", "cuerpo": "nada", "espera": 30}])
	_check(not bool(r9.get("valido", true)) and str(r9.get("mensaje", "")) == "No existe (404)", "un 404 se decide por el código sin esperar al cuerpo")

	# Cadena de redirecciones: la URL final que se guarda (#59)
	var base := "http://127.0.0.1:%d" % int(_srv.puerto)
	var r10: Dictionary = await _comprobar([
		{"estado": "301 Moved Permanently", "cuerpo": "", "extra": "Location: /viejo/foto.png\r\n"},
		{"estado": "302 Found", "cuerpo": "", "extra": "Location: /nuevo/foto.png\r\n"},
		{"estado": "200 OK", "cuerpo": "<html>hola</html>"},
	])
	_check(bool(r10.get("valido", false)) and int(r10.get("codigo", 0)) == 200, "una cadena de 301 y 302 termina en el 200 del destino")
	_check(str(r10.get("url_final", "")) == "%s/nuevo/foto.png" % base, "la URL final es el último destino, no el de partida (#59)")
	var pet10: PackedStringArray = r10.get("peticiones", PackedStringArray())
	_check(pet10.size() == 3 and pet10[2].contains("GET /nuevo/foto.png"), "sigue la redirección hasta el final (#59)")

	var r11: Dictionary = await _comprobar([
		{"estado": "301 Moved Permanently", "cuerpo": "", "extra": "Location: /otro/foto.png\r\n"},
		{"estado": "410 Gone", "cuerpo": "nada"},
	])
	_check(not bool(r11.get("valido", true)), "un enlace reubicado que además está caído se marca caído (#59)")
	_check(str(r11.get("url_final", "")) == "%s/otro/foto.png" % base, "también se guarda el destino cuando el final es un error (#59)")


func _comprobar(guion: Array, timeout := 10.0, reintentar := false) -> Dictionary:
	_srv.preparar(guion)
	_fin = false
	_valido = true
	_mensaje = ""
	_leidos = 0
	_evidencia = ""
	_intentos = 1
	_transitorio = false
	_motivo = ""
	_codigo = 0
	_url_final = ""

	var checker := LinkChecker.new()
	checker.timeout_s = timeout
	checker.reintentar_transitorios = reintentar
	root.add_child(checker)
	checker.terminado.connect(func(v: bool, m: String, c: int, d: String) -> void:
		_fin = true
		_valido = v
		_mensaje = m
		_codigo = c
		_url_final = d
		_leidos = checker._leidos
		_evidencia = checker._cuerpo
		_intentos = int(checker.intentos)
		_transitorio = bool(checker.transitorio)
		_motivo = str(checker.motivo))
	checker.comprobar("http://127.0.0.1:%d/archivo" % int(_srv.puerto))

	var limite := Time.get_ticks_msec() + 6000
	while not _fin and Time.get_ticks_msec() < limite:
		_srv.paso()
		await process_frame

	var res := {
		"fin": _fin,
		"valido": _valido,
		"mensaje": _mensaje,
		"leidos": _leidos,
		"cuerpo": _evidencia,
		"peticiones": _srv.peticiones,
		"enviados": _srv.enviados,
		"intentos": _intentos,
		"transitorio": _transitorio,
		"motivo": _motivo,
		"codigo": _codigo,
		"url_final": _url_final,
	}
	if is_instance_valid(checker):
		if checker.get_parent() != null:
			root.remove_child(checker)
		checker.free()
	_srv.soltar()
	return res


func _check(cond: bool, nombre: String) -> void:
	if nombre.is_empty():
		return
	if cond:
		print("  OK: %s" % nombre)
	else:
		_fallos += 1
		printerr("  check FALLIDO — ", nombre)


func _cerrar() -> void:
	if _srv != null:
		_srv.parar()
	if _fallos == 0:
		print("TESTS OK")
	else:
		print("TESTS FALLIDOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)
