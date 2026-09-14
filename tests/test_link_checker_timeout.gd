extends SceneTree

const LinkChecker := preload("res://scripts/link_checker.gd")

var _fallos := 0
var _emitido_1 := false
var _valido_1 := true
var _mensaje_1 := ""
var _emitido_2 := false


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
