extends SceneTree

const ContadoresScript := preload("res://scripts/gestor_contadores.gd")

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	var vacio := ContadoresScript.contar([], {})
	_check(vacio.get("total", -1) == 0, "catálogo vacío → total 0")
	_check(vacio.get("activos", -1) == 0, "catálogo vacío → activos 0")
	_check(vacio.get("rotos", -1) == 0, "catálogo vacío → rotos 0")

	var estados := {
		"a.com": {"valido": false, "mensaje": "No existe (404)"},
		"b.com": {"valido": true, "mensaje": "OK (200)"},
		"d.com": {"valido": null, "mensaje": "Sin respuesta", "intentos": 3, "motivo": "red"},
	}
	var entradas := [
		{"nombre": "A", "url": "https://a.com"},
		{"nombre": "B", "url": "https://b.com"},
		{"nombre": "C", "url": "https://c.com"},
		"basura",
	]
	var r := ContadoresScript.contar(entradas, estados)
	_check(r.get("total", -1) == 3, "total cuenta solo entradas con formato correcto")
	_check(r.get("activos", -1) == 1, "activos = entradas con estado valido true")
	_check(r.get("rotos", -1) == 1, "rotos = entradas con estado valido false")

	var con_red := ContadoresScript.contar([{"url": "https://d.com"}], estados)
	_check(con_red.get("activos", -1) == 0 and con_red.get("rotos", -1) == 0, "un fallo de red (valido null) no cuenta ni como activo ni como roto (#54)")
	_check(con_red.get("total", -1) == 1, "un enlace sin comprobar sigue sumando al total (#54)")

	var con_tls := ContadoresScript.contar(
		[{"url": "https://e.com"}, {"url": "https://f.com"}],
		{
			"e.com": {"valido": true, "motivo": "tls", "mensaje": "OK (200)"},
			"f.com": {"valido": false, "motivo": "tls", "mensaje": "Certificado no válido (rechazado)"},
		}
	)
	_check(con_tls.get("activos", -1) == 1 and con_tls.get("rotos", -1) == 1, "un certificado aceptado cuenta como activo y el rechazado como roto (#56)")

	var repetida := ContadoresScript.contar([
		{"url": "https://a.com"},
		{"url": "https://a.com"},
	], estados)
	_check(repetida.get("total", -1) == 2, "dos entradas con la misma URL se cuentan dos veces")

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

	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)
