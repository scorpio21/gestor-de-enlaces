extends SceneTree

const RUTA_CSV := "res://locale/gestor_es_en.csv"
const Extraer := preload("res://scripts/extraer_cadenas.gd")

var _fallos := 0


func _initialize() -> void:
	var filas := _leer_csv(RUTA_CSV)
	if filas.is_empty():
		_check(false, "el CSV existe y se puede leer")
		_cerrar()
		return
	_a_cabecera(filas)
	_a_integridad(filas)
	_b_cobertura(filas)
	_cerrar()


func _a_cabecera(filas: Array) -> void:
	var cab: Array = filas[0]
	_check(cab.size() >= 3 and cab[0] == "keys" and cab[1] == "es" and cab[2] == "en", \
		"la cabecera del CSV es keys,es,en")


func _a_integridad(filas: Array) -> void:
	var repetidas := {}
	var celdas_vacias := 0
	for i in range(1, filas.size()):
		var f: Array = filas[i]
		if f.size() < 3 or f[0].is_empty() or f[1].is_empty() or f[2].is_empty():
			celdas_vacias += 1
		if repetidas.has(f[0]):
			_check(false, "clave duplicada: %s" % f[0])
		repetidas[f[0]] = true
	_check(celdas_vacias == 0, "todas las filas tienen keys,es,en no vacías")
	_check(filas.size() > 1, "el CSV tiene filas de traducción")


func _b_cobertura(filas: Array) -> void:
	var claves := {}
	for i in range(1, filas.size()):
		claves[filas[i][0]] = true
	var ausentes := []
	for cadena in Extraer.ui_strings():
		if not claves.has(cadena):
			ausentes.append(cadena)
	if ausentes.is_empty():
		_check(true, "todas las cadenas de UI extraídas son claves del CSV")
	else:
		for a in ausentes:
			_check(false, "falta clave: %s" % a)


func _leer_csv(path: String) -> Array:
	var src := FileAccess.get_file_as_string(path)
	var filas: Array = []
	var campos: Array = []
	var buf := ""
	var entre := false
	var i := 0
	while i < src.length():
		var c: String = src[i]
		if entre:
			if c == '"':
				if i + 1 < src.length() and src[i + 1] == '"':
					buf += '"'
					i += 1
				else:
					entre = false
			else:
				buf += c
		elif c == '"':
			entre = true
		elif c == ",":
			campos.append(buf)
			buf = ""
		elif c == "\n":
			campos.append(buf)
			filas.append(campos)
			campos = []
			buf = ""
		else:
			buf += c
		i += 1
	if not buf.is_empty() or not campos.is_empty():
		campos.append(buf)
		filas.append(campos)
	return filas


func _cerrar() -> void:
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