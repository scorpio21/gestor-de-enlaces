extends SceneTree

const RUTA_CSV := "res://locale/gestor_es_en.csv"
const Extraer := preload("res://scripts/extraer_cadenas.gd")
const IdiomaScript := preload("res://scripts/idioma.gd")

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
	_c_idioma()
	_d_templates()
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


func _c_idioma() -> void:
	_check(IdiomaScript.aplicar("", "en_US") == "en", "aplicar autodetecta en_US")
	_check(IdiomaScript.aplicar("", "es_ES") == "es", "aplicar autodetecta es_ES")
	_check(IdiomaScript.aplicar("", "fr_FR") == "es", "aplicar cae a es con locale ajeno")
	_check(IdiomaScript.aplicar("en", "es_ES") == "en", "la config en manda sobre el SO")
	_check(IdiomaScript.aplicar("es", "en_US") == "es", "la config es manda sobre el SO")
	IdiomaScript.cargar_traducciones()
	TranslationServer.set_locale("es")
	_check(tr("Nombre") == "Nombre", "la carga manual registra traducciones es")
	TranslationServer.set_locale("en")
	_check(tr("Nombre") == "Name", "la carga manual registra traducciones en")
	_check(tr("%d enlaces") == "%d links", "el template %d enlaces se traduce en")
	TranslationServer.set_locale("es")


func _d_templates() -> void:
	var regex := RegEx.create_from_string(r'\.(?:text|dialog_text|ok_button_text)\s*=\s*"([^"]*%[^"]*)"')
	var pendientes := 0
	for ruta in Extraer.SCRIPTS_UI:
		var src := FileAccess.get_file_as_string(ruta)
		for m in regex.search_all(src):
			var fin := m.get_end(0)
			var ini := src.rfind("\n", fin - 1) + 1
			var linea := src.substr(ini, fin - ini)
			if not linea.contains("tr("):
				pendientes += 1
				push_error("FALLO: template sin tr(): %s" % linea.strip_edges())
	_check(pendientes == 0, "todo texto con %% de scripts de UI está envuelto en tr()")


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