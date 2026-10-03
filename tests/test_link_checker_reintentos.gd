extends SceneTree

const LinkChecker := preload("res://scripts/link_checker.gd")
const ServidorHttp := preload("res://tests/servidor_http.gd")

var _fallos := 0
var _fin := false
var _valido := true
var _mensaje := ""
var _intentos := 1
var _transitorio := false
var _motivo := ""
var _srv: RefCounted = null
var _emitidas := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	_clasificacion()
	_esperas()
	_fecha_http()
	_srv = ServidorHttp.new()
	if not _srv.arrancar():
		_check(false, "el servidor local escucha")
		_cerrar()
		return
	await _red()
	_cerrar()


func _clasificacion() -> void:
	_check(LinkChecker.es_transitorio(LinkChecker.MOTIVO_RED), "un fallo de red es transitorio")
	_check(LinkChecker.es_transitorio(LinkChecker.MOTIVO_DNS), "un dominio no resuelto es fallo del entorno (#54)")
	_check(not LinkChecker.es_transitorio(LinkChecker.MOTIVO_TLS), "un TLS inválido es definitivo (#54)")
	_check(not LinkChecker.es_transitorio(LinkChecker.MOTIVO_MUERTO, 404), "un 404 es definitivo (#54)")
	_check(not LinkChecker.es_transitorio(LinkChecker.MOTIVO_HTTP, 403), "un 403 no es transitorio")
	_check(LinkChecker.es_transitorio(LinkChecker.MOTIVO_HTTP, 503), "un 503 es transitorio")
	_check(LinkChecker.es_transitorio(LinkChecker.MOTIVO_HTTP, 429), "un 429 es transitorio")
	_check(not LinkChecker.es_transitorio(LinkChecker.MOTIVO_HTTP, 451), "un 451 no es transitorio")
	_check(not LinkChecker.es_transitorio(LinkChecker.MOTIVO_OK, 200), "un 200 no es un fallo transitorio")
	_check(LinkChecker.CODIGOS_TRANSITORIOS.has(502) and LinkChecker.CODIGOS_TRANSITORIOS.has(504), "502 y 504 son transitorios")

	var checker := LinkChecker.new()
	_check(checker.intentos == 1 and not checker.transitorio, "intentos y transitorio arrancan neutros")
	_check(checker.reintentar_transitorios == true, "reintentar los transitorios viene activado (#54)")
	_check(is_equal_approx(checker.timeout_s, 10.0), "el timeout por intento sigue siendo 10 s")
	checker.free()


func _esperas() -> void:
	_check(LinkChecker.ESPERA_REINTENTOS.size() == 2, "hay dos esperas de reintento (#54)")
	_check(is_equal_approx(LinkChecker.espera_reintento(0), 1.0), "el primer reintento espera 1 s")
	_check(is_equal_approx(LinkChecker.espera_reintento(1), 4.0), "el segundo reintento espera 4 s")
	_check(is_equal_approx(LinkChecker.espera_reintento(7), 0.0), "sin reintentos pendientes la espera es 0")
	_check(is_equal_approx(LinkChecker.espera_con_retry_after(1.0, -1.0), 1.0), "sin Retry-After manda la espera base")
	_check(is_equal_approx(LinkChecker.espera_con_retry_after(4.0, 2.0), 2.0), "Retry-After manda sobre la espera base")
	_check(is_equal_approx(LinkChecker.espera_con_retry_after(1.0, 0.0), 0.0), "Retry-After: 0 reintenta al instante")
	_check(is_equal_approx(LinkChecker.espera_con_retry_after(1.0, 600.0), 10.0), "Retry-After se capa a 10 s (#54)")


func _fecha_http() -> void:
	_check(LinkChecker.fecha_http_unix("no es una fecha") < 0, "una fecha ilegible se rechaza")
	_check(LinkChecker.fecha_http_unix("Wed, 21 Oct 2015 07:28:00 GMT") > 0, "se lee una fecha RFC 1123 (#54)")
	var esperado := int(Time.get_unix_time_from_datetime_dict({
		"year": 2015, "month": 10, "day": 21, "hour": 7, "minute": 28, "second": 0,
	}))
	_check(LinkChecker.fecha_http_unix("Wed, 21 Oct 2015 07:28:00 GMT") == esperado, "la fecha RFC 1123 se convierte bien")
	_check(LinkChecker.fecha_http_unix("Wednesday, 21-Oct-15 07:28:00 GMT") == esperado, "se lee una fecha RFC 850 (#54)")
	_check(LinkChecker.fecha_http_unix("Wed Oct 21 07:28:00 2015") == esperado, "se lee una fecha asctime (#54)")
	_check(LinkChecker.fecha_http_unix("21 Oct 2015 07:28:00") == esperado, "una fecha sin zona también vale (#54)")


func _red() -> void:
	# Fallo de red: el socket acepta y cierra sin responder → reintenta y avisa (#54)
	var r1: Dictionary = await _comprobar([{"corte": true}, {"corte": true}, {"corte": true}], 0.4, true, 25000)
	_check(bool(r1.get("fin", false)), "un socket que cierra sin responder termina la comprobación (#54)")
	_check(not bool(r1.get("valido", true)), "el fallo de red no marca el enlace como válido")
	_check(int(r1.get("intentos", 0)) == 3, "un fallo de red se intenta 3 veces (1 + 2 reintentos), intentos=%d" % int(r1.get("intentos", 0)))
	_check(int(r1.get("servidas", 0)) == 3, "el servidor ve 3 conexiones, una por intento (#54)")
	_check(bool(r1.get("transitorio", false)), "el fallo de red se marca como transitorio (#54)")
	_check(str(r1.get("motivo", "")) == LinkChecker.MOTIVO_RED, "el motivo del fallo de red es 'red'")

	# Sin reintentos: un solo intento, pero sigue siendo transitorio
	var r2: Dictionary = await _comprobar([{"corte": true}], 0.4, false, 8000)
	_check(bool(r2.get("fin", false)) and int(r2.get("intentos", 0)) == 1, "sin reintentos hay un solo intento (#54)")
	_check(bool(r2.get("transitorio", false)) and str(r2.get("motivo", "")) == LinkChecker.MOTIVO_RED, "el fallo sigue siendo transitorio aunque no se reintente")

	# 503, 503 y luego 200: reintenta y acaba en válido
	var r3: Dictionary = await _comprobar([
		{"estado": "503 Service Unavailable", "cuerpo": "espera"},
		{"estado": "503 Service Unavailable", "cuerpo": "espera"},
		{"estado": "200 OK", "cuerpo": "<html>hola</html>"},
	], 5.0, true, 25000)
	_check(bool(r3.get("fin", false)) and bool(r3.get("valido", false)), "un 503 seguido de 200 acaba en válido (#54)")
	_check(str(r3.get("mensaje", "")) == "OK (200)", "el mensaje final es el del 200, no el del 503")
	_check(int(r3.get("intentos", 0)) == 3, "hubo 3 intentos hasta el 200 (#54)")
	_check(int(r3.get("peticiones", PackedStringArray()).size()) == 3, "el servidor recibió 3 peticiones (#54)")
	_check(int(r3.get("emitidas", 0)) == 1, "los reintentos no emiten terminado hasta el final (#54): el slot de paralelismo no se libera antes de tiempo")
	_check(not bool(r3.get("transitorio", true)), "un 200 tras reintentar no es un fallo transitorio")

	# 404: definitivo, ni un reintento
	var r4: Dictionary = await _comprobar([
		{"estado": "404 Not Found", "cuerpo": "nada"},
		{"estado": "200 OK", "cuerpo": "<html>hola</html>"},
	], 5.0, true, 12000)
	_check(not bool(r4.get("valido", true)) and str(r4.get("mensaje", "")) == "No existe (404)", "un 404 no se reintenta (#54)")
	_check(int(r4.get("intentos", 0)) == 1, "un 404 se queda en 1 intento (#54)")
	_check(int(r4.get("peticiones", PackedStringArray()).size()) == 1, "un 404 no genera una segunda petición (#54)")
	_check(not bool(r4.get("transitorio", true)), "un 404 no es transitorio")
	_check(str(r4.get("motivo", "")) == LinkChecker.MOTIVO_MUERTO, "el motivo del 404 es 'muerto'")

	# 429 con Retry-After: 0 → reintenta sin esperar
	var inicio := Time.get_ticks_msec()
	var r5: Dictionary = await _comprobar([
		{"estado": "429 Too Many Requests", "cuerpo": "demasiado", "extra": "Retry-After: 0\r\n"},
		{"estado": "200 OK", "cuerpo": "<html>hola</html>"},
	], 5.0, true, 12000)
	var duracion := Time.get_ticks_msec() - inicio
	_check(bool(r5.get("valido", false)) and int(r5.get("intentos", 0)) == 2, "un 429 con Retry-After: 0 reintenta y acaba válido (#54)")
	_check(duracion < 900, "Retry-After: 0 evita la espera de 1 s (tardó %d ms)" % duracion)

	# Un 503 con Retry-After enorme se capa: el escaneo no se queda colgado
	var inicio_largo := Time.get_ticks_msec()
	var r5b: Dictionary = await _comprobar([
		{"estado": "503 Service Unavailable", "cuerpo": "espera", "extra": "Retry-After: 600\r\n"},
		{"estado": "200 OK", "cuerpo": "<html>hola</html>"},
	], 5.0, true, 25000)
	var duracion_larga := Time.get_ticks_msec() - inicio_largo
	_check(bool(r5b.get("valido", false)) and int(r5b.get("intentos", 0)) == 2, "un 503 con Retry-After enorme acaba en válido (#54)")
	_check(duracion_larga < int(LinkChecker.MAX_RETRY_AFTER * 1000.0) + 4000, "Retry-After se capa a 10 s aunque el servidor pida 600 (tardó %d ms)" % duracion_larga)

	# El reintento vuelve a la URL inicial, no al último redirect
	var r6: Dictionary = await _comprobar([
		{"estado": "302 Found", "cuerpo": "", "extra": "Location: /final\r\n"},
		{"estado": "503 Service Unavailable", "cuerpo": "espera"},
		{"estado": "200 OK", "cuerpo": "<html>hola</html>"},
	], 5.0, true, 25000)
	_check(bool(r6.get("valido", false)) and int(r6.get("intentos", 0)) == 2, "el reintento tras un 503 en un redirect acaba válido (#54)")
	var pets: PackedStringArray = r6.get("peticiones", PackedStringArray())
	_check(pets.size() == 3 and pets[2].contains("/archivo") and not pets[2].contains("/final"), "el reintento repite la URL inicial (#54)")

	# 503 hasta agotar los reintentos: 3 intentos y ningún más
	var r7: Dictionary = await _comprobar([
		{"estado": "503 Service Unavailable", "cuerpo": "a"},
		{"estado": "503 Service Unavailable", "cuerpo": "b"},
		{"estado": "503 Service Unavailable", "cuerpo": "c"},
		{"estado": "200 OK", "cuerpo": "<html>hola</html>"},
	], 5.0, true, 25000)
	_check(not bool(r7.get("valido", true)) and str(r7.get("mensaje", "")) == "Error HTTP 503", "el mensaje final es el del último 503 (#54)")
	_check(int(r7.get("intentos", 0)) == 3 and int(r7.get("peticiones", PackedStringArray()).size()) == 3, "no se pasa de 3 intentos (#54)")
	_check(bool(r7.get("transitorio", false)) and str(r7.get("motivo", "")) == LinkChecker.MOTIVO_HTTP, "el 503 agotado sigue siendo transitorio (#54)")


func _comprobar(guion: Array, timeout := 10.0, reintentar := true, limite_ms := 20000) -> Dictionary:
	_srv.preparar(guion)
	_fin = false
	_valido = true
	_mensaje = ""
	_intentos = 1
	_transitorio = false
	_motivo = ""
	_emitidas = 0

	var checker := LinkChecker.new()
	checker.timeout_s = timeout
	checker.reintentar_transitorios = reintentar
	root.add_child(checker)
	checker.terminado.connect(func(v: bool, m: String, _c: int, _d: String) -> void:
		_emitidas += 1
		_fin = true
		_valido = v
		_mensaje = m
		_intentos = int(checker.intentos)
		_transitorio = bool(checker.transitorio)
		_motivo = str(checker.motivo))
	checker.comprobar("http://127.0.0.1:%d/archivo" % int(_srv.puerto))

	var limite := Time.get_ticks_msec() + limite_ms
	while not _fin and Time.get_ticks_msec() < limite:
		_srv.paso()
		await process_frame

	var res := {
		"fin": _fin,
		"valido": _valido,
		"mensaje": _mensaje,
		"intentos": _intentos,
		"transitorio": _transitorio,
		"motivo": _motivo,
		"peticiones": _srv.peticiones,
		"servidas": int(_srv.servir()),
		"emitidas": _emitidas,
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
