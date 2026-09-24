extends RefCounted

const IDIOMAS := ["es", "en"]


static func aplicar(guardado: String, locale_so: String) -> String:
	if guardado in IDIOMAS:
		return guardado
	var prefijo := locale_so.to_lower().substr(0, 2)
	return "en" if prefijo == "en" else "es"


static func cargar_traducciones() -> void:
	var filas := _leer_csv("res://locale/gestor_es_en.csv")
	if filas.size() < 2:
		return
	var es := Translation.new()
	es.locale = "es"
	var en := Translation.new()
	en.locale = "en"
	for i in range(1, filas.size()):
		var f: Array = filas[i]
		if f.size() < 3:
			continue
		es.add_message(f[0], f[1])
		if not f[2].is_empty():
			en.add_message(f[0], f[2])
	TranslationServer.add_translation(es)
	TranslationServer.add_translation(en)


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