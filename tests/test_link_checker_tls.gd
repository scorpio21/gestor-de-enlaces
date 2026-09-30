extends SceneTree

const Servidor := preload("res://tests/servidor_http.gd")
const LinkChecker := preload("res://scripts/link_checker.gd")
const CERT := "res://tests/fixtures/cert_prueba.pem"
const CLAVE := "res://tests/fixtures/clave_prueba.pem"

var _srv: RefCounted = null
var _fallos := 0
var _fin := false
var _valido := true
var _mensaje := ""
var _intentos := 1
var _transitorio := false
var _motivo := ""
var _codigo := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	_srv = Servidor.new()
	if not _srv.arrancar_tls(CERT, CLAVE):
		_check(false, "el servidor de tests arranca con el certificado de prueba")
		_cerrar()
		return
	_check(int(_srv.puerto) > 0, "el servidor TLS escucha en un puerto efimero")

	# Con la preferencia activa el handshake sin validacion debe pasar
	var r1: Dictionary = await _comprobar(_srv, true)
	_check(bool(r1.get("fin", false)), "con la preferencia activa el handshake termina (#56)")
	_check(bool(r1.get("valido", false)), "un certificado autofirmado con la preferencia activa da el enlace por valido (#56)")
	_check(str(r1.get("motivo", "")) == LinkChecker.MOTIVO_TLS, "el motivo es 'tls' aunque el enlace sea valido (#56)")
	_check(str(r1.get("mensaje", "")) == "OK (200)", "un certificado aceptado se guarda con el codigo real (#56)")
	_check(int(r1.get("intentos", 0)) == 1, "el TLS no se reintenta (#56)")
	_check(not bool(r1.get("transitorio", true)), "el TLS no se marca transitorio (#56)")

	# Con la preferencia desactivada el certificado se rechaza
	var r2: Dictionary = await _comprobar(_srv, false)
	_check(bool(r2.get("fin", false)), "sin la preferencia el handshake tambien termina (#56)")
	_check(not bool(r2.get("valido", true)), "sin la preferencia el enlace no es valido (#56)")
	_check(str(r2.get("motivo", "")) == LinkChecker.MOTIVO_TLS, "el rechazo de certificado es motivo 'tls' (#56)")
	_check(str(r2.get("mensaje", "")) == "Certificado no válido (rechazado)", "el rechazo tiene su propio mensaje (#56)")
	_check(not bool(r2.get("transitorio", true)), "un certificado rechazado no se reintenta (#56)")
	_check(int(r2.get("codigo", 1)) == 0, "un fallo de TLS no inventa un codigo HTTP (#56)")

	# Un servidor TLS que no responde HTTP no debe colgarse: mismo camino de error
	var r3: Dictionary = await _comprobar(_srv, true, "https", [{"corte": true, "intento": 1}])
	_check(bool(r3.get("fin", false)), "el handshake con la preferencia activa no se cuelga (#56)")
	_check(not bool(r3.get("valido", true)), "el corte tras el handshake no da el enlace por valido (#56)")
	_check(str(r3.get("mensaje", "")) == "Sin conexión segura", "el corte con la preferencia activa da su propio mensaje (#56)")
	_check(str(r3.get("motivo", "")) == LinkChecker.MOTIVO_TLS, "el corte tras el handshake sigue siendo motivo 'tls' (#56)")

	# Un enlace http normal no lleva aviso aunque la preferencia este activa
	var srv_plano: RefCounted = Servidor.new()
	if srv_plano.arrancar():
		var r4: Dictionary = await _comprobar(srv_plano, true, "http")
		_check(bool(r4.get("valido", false)), "un enlace http con la preferencia activa sigue valido (#56)")
		_check(str(r4.get("motivo", "")) == LinkChecker.MOTIVO_OK, "un enlace http no se marca como tls (#56)")
		srv_plano.parar()

	# El aviso solo aparece si el certificado fue rechazado de verdad
	_check(_sin_aviso_sin_certificado_rechazado(), "sin certificado rechazado no se avisa aunque la preferencia este activa (#56)")

	_srv.parar()
	_cerrar()


func _comprobar(srv: RefCounted, aceptar: bool, esquema := "https", guion := [{"estado": "200 OK", "cuerpo": "<html>hola</html>"}]) -> Dictionary:
	srv.preparar(guion)
	_fin = false
	_valido = true
	_mensaje = ""
	_intentos = 1
	_transitorio = false
	_motivo = ""
	_codigo = 0

	var checker := LinkChecker.new()
	checker.timeout_s = 5.0
	checker.aceptar_certificados = aceptar
	root.add_child(checker)
	checker.terminado.connect(func(v: bool, m: String) -> void:
		_fin = true
		_valido = v
		_mensaje = m
		_intentos = int(checker.intentos)
		_transitorio = bool(checker.transitorio)
		_motivo = str(checker.motivo)
		_codigo = int(checker.codigo))
	checker.comprobar("%s://127.0.0.1:%d/archivo" % [esquema, int(srv.puerto)])

	var limite := Time.get_ticks_msec() + 20000
	while not _fin and Time.get_ticks_msec() < limite:
		srv.paso()
		await process_frame

	var res := {
		"fin": _fin,
		"valido": _valido,
		"mensaje": _mensaje,
		"intentos": _intentos,
		"transitorio": _transitorio,
		"motivo": _motivo,
		"codigo": _codigo,
	}
	if is_instance_valid(checker):
		if checker.get_parent() != null:
			checker.get_parent().remove_child(checker)
		checker.free()
	return res


func _sin_aviso_sin_certificado_rechazado() -> bool:
	var checker := LinkChecker.new()
	checker._certificado_rechazado = false
	var motivo_ok := checker._motivo_exito()
	checker._certificado_rechazado = true
	var motivo_aviso := checker._motivo_exito()
	checker.free()
	return motivo_ok == LinkChecker.MOTIVO_OK and motivo_aviso == LinkChecker.MOTIVO_TLS


func _cerrar() -> void:
	if _fallos == 0:
		print("TESTS OK")
	else:
		print("TESTS FALLIDOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)


func _check(cond: bool, nombre: String) -> void:
	if cond:
		print("  OK: %s" % nombre)
	else:
		_fallos += 1
		printerr("  check FALLIDO — ", nombre)
