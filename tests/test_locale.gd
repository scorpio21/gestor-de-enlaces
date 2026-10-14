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
	_e_runtime_tr()
	_cerrar()


func _a_cabecera(filas: Array) -> void:
	var cab: Array = filas[0]
	_check(cab.size() == 8 and cab[0] == "keys" and cab[1] == "es" and cab[2] == "en" and cab[3] == "it" and cab[4] == "eu" and cab[5] == "ca" and cab[6] == "gl" and cab[7] == "es_AR", \
		"la cabecera del CSV es keys,es,en,it,eu,ca,gl,es_AR")


func _a_integridad(filas: Array) -> void:
	# Los idiomas completos son todas las columnas menos la clave y el delta
	# final (es_AR, ragged): esos sí pueden faltar. Así, añadir un idioma solo
	# toca la cabecera y su columna, no esta comprobación.
	var cab: Array = filas[0]
	var total := cab.size()
	var col_delta := total - 1
	var repetidas := {}
	var celdas_vacias := 0
	var desbordes := 0
	var redundantes := 0
	var delta_vacias := 0
	for i in range(1, filas.size()):
		var f: Array = filas[i]
		if str(f[0]).is_empty():
			celdas_vacias += 1
		for col in range(1, min(col_delta, f.size())):
			if str(f[col]).is_empty():
				celdas_vacias += 1
		if f.size() < col_delta:
			celdas_vacias += 1
		if f.size() > total:
			desbordes += 1
		if repetidas.has(f[0]):
			_check(false, "clave duplicada: %s" % f[0])
		repetidas[f[0]] = true
		if f.size() == total:
			if str(f[col_delta]).is_empty():
				delta_vacias += 1
			elif str(f[col_delta]) == str(f[1]):
				redundantes += 1
	_check(celdas_vacias == 0, "todas las filas traen la clave y los idiomas completos (menos el delta final)")
	_check(desbordes == 0, "ninguna fila supera las columnas de la cabecera")
	_check(delta_vacias == 0, "los overrides del delta final no quedan vacíos (se omiten si no aportan)")
	_check(redundantes == 0, "todo override del delta final aporta algo distinto al es")
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
	_check(IdiomaScript.aplicar("", "es_AR") == "es_AR", "aplicar autodetecta es_AR")
	_check(IdiomaScript.aplicar("", "es-ar") == "es_AR", "aplicar autodetecta es-ar con guion")
	_check(IdiomaScript.aplicar("", "es_MX") == "es", "aplicar deja el resto de LatAm en es")
	_check(IdiomaScript.aplicar("es_AR", "en_US") == "es_AR", "la config es_AR manda sobre el SO")
	_check(IdiomaScript.aplicar("", "it_IT") == "it", "aplicar autodetecta it_IT")
	_check(IdiomaScript.aplicar("", "it-it") == "it", "aplicar autodetecta it-it con guion")
	_check(IdiomaScript.aplicar("it", "es_ES") == "it", "la config it manda sobre el SO")
	_check(IdiomaScript.aplicar("", "eu_ES") == "eu", "aplicar autodetecta eu_ES")
	_check(IdiomaScript.aplicar("", "eu-es") == "eu", "aplicar autodetecta eu-es con guion")
	_check(IdiomaScript.aplicar("eu", "es_ES") == "eu", "la config eu manda sobre el SO")
	_check(IdiomaScript.aplicar("", "ca_ES") == "ca", "aplicar autodetecta ca_ES")
	_check(IdiomaScript.aplicar("", "ca-es") == "ca", "aplicar autodetecta ca-es con guion")
	_check(IdiomaScript.aplicar("ca", "es_ES") == "ca", "la config ca manda sobre el SO")
	_check(IdiomaScript.aplicar("", "gl_ES") == "gl", "aplicar autodetecta gl_ES")
	_check(IdiomaScript.aplicar("", "gl-es") == "gl", "aplicar autodetecta gl-es con guion")
	_check(IdiomaScript.aplicar("gl", "es_ES") == "gl", "la config gl manda sobre el SO")
	IdiomaScript.cargar_traducciones()
	TranslationServer.set_locale("es")
	_check(tr("Nombre") == "Nombre", "la carga manual registra traducciones es")
	TranslationServer.set_locale("en")
	_check(tr("Nombre") == "Name", "la carga manual registra traducciones en")
	_check(tr("%d enlaces") == "%d links", "el template %d enlaces se traduce en")
	TranslationServer.set_locale("es_AR")
	_check(tr("Ficheros sueltos") == "Archivos sueltos", "la carga manual registra overrides es_AR")
	_check(tr("Nombre") == "Nombre", "es_AR cae a es cuando no hay override")
	_check(tr("%d enlaces") == "%d enlaces", "el template cae a es, no a en")
	TranslationServer.set_locale("it")
	_check(tr("Nombre") == "Nome", "la carga manual registra traducciones it")
	_check(tr("%d enlaces") == "%d link", "el template %d enlaces se traduce en it")
	TranslationServer.set_locale("eu")
	_check(tr("Nombre") == "Izena", "la carga manual registra traducciones eu")
	_check(tr("%d enlaces") == "%d esteka", "el template %d enlaces se traduce en eu")
	TranslationServer.set_locale("ca")
	_check(tr("Nombre") == "Nom", "la carga manual registra traducciones ca")
	_check(tr("%d enlaces") == "%d enllaços", "el template %d enlaces se traduce en ca")
	TranslationServer.set_locale("gl")
	_check(tr("Nombre") == "Nome", "la carga manual registra traducciones gl")
	_check(tr("%d enlaces") == "%d ligazóns", "el template %d enlaces se traduce en gl")
	TranslationServer.set_locale("es")
	TranslationServer.clear()
	IdiomaScript.cargar_importadas()
	TranslationServer.set_locale("en")
	_check(tr("Nombre") == "Name", "el fallback carga los .translation importados")
	TranslationServer.set_locale("es_AR")
	_check(tr("Ficheros sueltos") == "Archivos sueltos", "el fallback importado conserva los overrides es_AR")
	_check(tr("Nombre") == "Nombre", "el fallback importado tambien cae a es")
	TranslationServer.set_locale("it")
	_check(tr("Nombre") == "Nome", "el fallback importado registra el italiano completo")
	TranslationServer.set_locale("eu")
	_check(tr("Nombre") == "Izena", "el fallback importado registra el euskera completo")
	TranslationServer.set_locale("ca")
	_check(tr("Nombre") == "Nom", "el fallback importado registra el catalan completo")
	TranslationServer.set_locale("gl")
	_check(tr("Nombre") == "Nome", "el fallback importado registra el gallego completo")
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


func _e_runtime_tr() -> void:
	var regex_llamada := RegEx.create_from_string(r'(?:add_item|add_icon_item|_pintar_estado|_cerrar)\(\s*"([^"]+)"')
	var regex_asig := RegEx.create_from_string(r'\.(?:text|title|tooltip_text|dialog_text|ok_button_text|cancel_button_text)\s*=\s*"([^"]+)"')
	var regex_mensaje := RegEx.create_from_string(r'mensaje\s*=\s*"([^"]+)"')
	var regex_linea := RegEx.create_from_string(r'lineas\.append\(\s*"([^"]+)"')
	var pendientes := 0
	for ruta in Extraer.SCRIPTS_UI:
		var src := FileAccess.get_file_as_string(ruta)
		for regex in [regex_llamada, regex_asig, regex_mensaje, regex_linea]:
			pendientes += _contar_sin_tr(src, regex, ruta)
		pendientes += _tooltips_sin_tr(src, ruta)
	var src_checker := FileAccess.get_file_as_string("res://scripts/link_checker.gd")
	pendientes += _contar_sin_tr(src_checker, regex_llamada, "res://scripts/link_checker.gd")
	var src_cat := FileAccess.get_file_as_string("res://scripts/gestor_catalogo.gd")
	if not src_cat.contains("tr(etiquetas.get("):
		pendientes += 1
		push_error("FALLO: categoria_display no traduce sus etiquetas en runtime")
	_check(pendientes == 0, "todo texto UI asignado por código está envuelto en tr()")


func _contar_sin_tr(src: String, regex: RegEx, ruta: String) -> int:
	var pendientes := 0
	for linea in src.split("\n"):
		for m in regex.search_all(linea):
			var literal := m.get_string(1)
			if not _traducible_simple(literal):
				continue
			var ini := m.get_start(1)
			if not linea.substr(0, ini).contains("tr("):
				pendientes += 1
				push_error("FALLO: texto runtime sin tr(): %s (%s)" % [literal, ruta])
	return pendientes


func _tooltips_sin_tr(src: String, ruta: String) -> int:
	var pendientes := 0
	var regex := RegEx.create_from_string(r'"([^"]+)"')
	for linea in src.split("\n"):
		if not linea.contains("tooltip_text"):
			continue
		for m in regex.search_all(linea):
			var literal := m.get_string(1)
			if literal == "\\n" or literal.strip_edges().is_empty():
				continue
			var ini := m.get_start(1)
			if not linea.substr(0, ini).contains("tr("):
				pendientes += 1
				push_error("FALLO: tooltip sin tr(): %s (%s)" % [literal, ruta])
	return pendientes


func _traducible_simple(txt: String) -> bool:
	var limpio := txt.strip_edges()
	if limpio.is_empty():
		return false
	if limpio == "v" or limpio.begins_with("v0") or limpio.begins_with("https"):
		return false
	return limpio.length() <= 200


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