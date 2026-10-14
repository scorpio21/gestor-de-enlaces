extends RefCounted

const BASE := "res://locale/gestor_es_en"
const RUTA_CSV := BASE + ".csv"
const IDIOMAS := ["es", "en", "es_AR", "it", "eu"]
const IDIOMA_BASE := "es"


static func aplicar(guardado: String, locale_so: String) -> String:
	if guardado in IDIOMAS:
		return guardado
	var locale := locale_so.replace("-", "_").to_lower()
	if locale.begins_with("en"):
		return "en"
	if locale.begins_with("it"):
		return "it"
	if locale.begins_with("eu"):
		return "eu"
	if locale == "es_ar":
		return "es_AR"
	return IDIOMA_BASE


static func cargar_traducciones() -> void:
	var filas: Array = []
	if FileAccess.file_exists(RUTA_CSV):
		filas = _leer_csv(RUTA_CSV)
	if filas.size() >= 2:
		_cargar_columnas(filas)
		return
	cargar_importadas()


static func _cargar_columnas(filas: Array) -> void:
	var cabecera: Array = filas[0]
	for col in range(1, cabecera.size()):
		var locale := str(cabecera[col]).strip_edges()
		if locale.is_empty():
			continue
		var traduccion := Translation.new()
		traduccion.locale = locale
		for i in range(1, filas.size()):
			var f: Array = filas[i]
			if f.size() <= col:
				continue
			var valor := str(f[col])
			if not valor.is_empty():
				traduccion.add_message(str(f[0]), valor)
		TranslationServer.add_translation(traduccion)


# El .csv crudo no viaja en el pck: con export_filter="all_resources" solo entran
# recursos, y del .csv queda unicamente el .translation que genera el importador.
# En el editor se lee el .csv (fuente de verdad); en el binario exportado se
# cargan los .translation importados, que si van empaquetados.
static func cargar_importadas() -> void:
	for idioma in IDIOMAS:
		var ruta := "%s.%s.translation" % [BASE, idioma]
		if ResourceLoader.exists(ruta):
			TranslationServer.add_translation(load(ruta))


static func _leer_csv(path: String) -> Array:
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