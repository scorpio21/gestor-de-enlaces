extends SceneTree

const LinkChecker := preload("res://scripts/link_checker.gd")

var _fallos := 0
var _emitido_1 := false
var _valido_1 := true
var _mensaje_1 := ""
var _emitido_2 := false

var _srv := TCPServer.new()
var _puerto := 0
var _peer: StreamPeerTCP = null
var _peticiones: PackedStringArray = []
var _recibido := ""
var _guion: Array = []
var _servidos := 0
var _espera := 0
var _ritmo := 1
var _ritmo_cont := 0
var _pendientes: Array = []
var _enviados := 0
var _actual := -1
var _fin := false
var _valido := true
var _mensaje := ""
var _leidos := 0
var _evidencia := ""


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
	c1.terminado.connect(func(v: bool, m: String) -> void:
		_emitido_1 = true
		_valido_1 = v
		_mensaje_1 = m)
	c1.comprobar("")
	_check(_emitido_1 and not _valido_1 and _mensaje_1 == "URL inválida" and not c1._activo, "comprobar('') emite terminado(false, 'URL inválida') sin red")

	var c2 := LinkChecker.new()
	_emitido_2 = false
	c2.terminado.connect(func(v: bool, _m: String) -> void:
		_emitido_2 = true)
	c2.comprobar("gopher://x")
	_check(_emitido_2 and not c2._activo, "comprobar('gopher://x') emite terminado sin red")

	await _red()

	_cerrar()


# --- Escenarios con un servidor HTTP local (#53) ---

func _red() -> void:
	if _srv.listen(0, "127.0.0.1") != OK:
		_check(false, "el servidor local escucha")
		return
	_puerto = _srv.get_local_port()

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


func _comprobar(guion: Array, timeout := 10.0) -> Dictionary:
	_guion = guion.duplicate()
	_servidos = 0
	_actual = -1
	_espera = 0
	_enviados = 0
	_fin = false
	_valido = true
	_mensaje = ""
	_leidos = 0
	_evidencia = ""
	_recibido = ""
	_pendientes = []
	_ritmo = 1
	_ritmo_cont = 0
	_peticiones = PackedStringArray()
	_soltar()

	var checker := LinkChecker.new()
	checker.timeout_s = timeout
	root.add_child(checker)
	checker.terminado.connect(func(v: bool, m: String) -> void:
		_fin = true
		_valido = v
		_mensaje = m
		_leidos = checker._leidos
		_evidencia = checker._cuerpo)
	checker.comprobar("http://127.0.0.1:%d/archivo" % _puerto)

	var limite := Time.get_ticks_msec() + 6000
	while not _fin and Time.get_ticks_msec() < limite:
		_paso()
		await process_frame

	var res := {
		"fin": _fin,
		"valido": _valido,
		"mensaje": _mensaje,
		"leidos": _leidos,
		"cuerpo": _evidencia,
		"peticiones": _peticiones,
		"enviados": _enviados,
	}
	if is_instance_valid(checker):
		if checker.get_parent() != null:
			root.remove_child(checker)
		checker.free()
	_soltar()
	return res


func _soltar() -> void:
	if _peer != null:
		_peer.disconnect_from_host()
		_peer = null


func _paso() -> void:
	if _peer == null:
		var c: Variant = _srv.take_connection()
		if c != null:
			_peer = c as StreamPeerTCP
			_recibido = ""
			_actual = -1
			_espera = 0
			_pendientes = []
		return
	_pumpar()
	if _actual < 0:
		if not _recibido.contains("\r\n\r\n"):
			return
		_peticiones.append(_recibido)
		_recibido = ""
		if _servidos >= _guion.size():
			return
		_actual = _servidos
		_servidos += 1
		var paso: Dictionary = _guion[_actual]
		_espera = int(paso.get("espera", 0))
		_ritmo = maxi(1, int(paso.get("ritmo", 1)))
		_ritmo_cont = 0
		_pendientes = _piezas(paso)
		return
	if _espera > 0:
		_espera -= 1
		return
	if not _pendientes.is_empty():
		if _ritmo > 1:
			if _ritmo_cont > 0:
				_ritmo_cont -= 1
				return
			_ritmo_cont = _ritmo - 1
		var trozo: PackedByteArray = _pendientes.pop_front()
		_enviados += trozo.size()
		_peer.put_data(trozo)
		return
	if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	if bool(_guion[_actual].get("cerrar", false)):
		_soltar()


func _pumpar() -> void:
	var disponible := _peer.get_available_bytes()
	if disponible <= 0:
		return
	var leido := _peer.get_data(disponible)
	if int(leido[0]) != OK:
		return
	var buf: PackedByteArray = leido[1]
	_recibido += buf.get_string_from_utf8()


func _piezas(paso: Dictionary) -> Array:
	var estado := str(paso.get("estado", "200 OK"))
	var extra := str(paso.get("extra", ""))
	var cuerpo := str(paso.get("cuerpo", ""))
	var trozos := maxi(1, int(paso.get("trozos", 1)))
	var largo := int(paso.get("longitud", cuerpo.length()))
	var chunked := extra.contains("chunked")
	var cabeceras := "HTTP/1.1 %s\r\n" % estado
	if not chunked:
		cabeceras += "Content-Length: %d\r\n" % largo
	cabeceras += "Content-Type: text/html\r\n" + extra
	if bool(paso.get("cerrar", false)):
		cabeceras += "Connection: close\r\n"
	cabeceras += "\r\n"

	var piezas: Array = [cabeceras.to_utf8_buffer()]
	var tamano := maxi(1, int(ceil(float(cuerpo.length()) / float(trozos))))
	while cuerpo.length() > 0:
		var trozo := cuerpo.substr(0, tamano)
		cuerpo = cuerpo.substr(trozo.length())
		if chunked:
			piezas.append(("%x\r\n%s\r\n" % [trozo.to_utf8_buffer().size(), trozo]).to_utf8_buffer())
		else:
			piezas.append(trozo.to_utf8_buffer())
	if chunked:
		piezas.append("0\r\n\r\n".to_utf8_buffer())
	return piezas


func _check(cond: bool, nombre: String) -> void:
	if nombre.is_empty():
		return
	if cond:
		print("  OK: %s" % nombre)
	else:
		_fallos += 1
		printerr("  check FALLIDO — ", nombre)


func _cerrar() -> void:
	_soltar()
	_srv.stop()
	if _fallos == 0:
		print("TESTS OK")
	else:
		print("TESTS FALLIDOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)
