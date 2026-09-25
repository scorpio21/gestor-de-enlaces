extends RefCounted

const ARCHIVOS_FIJOS := ["no-disponible.png"]
const CARACTERES_INVALIDOS := ["<", ">", ":", "\"", "/", "\\", "|", "?", "*"]
const LONGITUD_MAX := 60


static func copiar(origen: String, nombre_base := "", base := "res://Assets") -> Dictionary:
	if origen.is_empty():
		return {"ok": true, "destino": "", "error": ""}

	var ext := origen.get_extension().to_lower()
	var carpeta: String
	var sufijo: String
	match ext:
		"png", "webp":
			carpeta = "%s/png" % base
			sufijo = ".png"
		"jpg", "jpeg":
			carpeta = "%s/jpg" % base
			sufijo = ".jpg"
		_:
			return {"ok": false, "destino": "", "error": "Formato no soportado."}

	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta))
	if err != OK:
		return {"ok": false, "destino": "", "error": "No se pudo crear la carpeta de imágenes."}

	var img: Image = Image.load_from_file(origen)
	if img == null or img.is_empty():
		return {"ok": false, "destino": "", "error": "No se pudo copiar la imagen."}
	const ANCHO_MAX := 800
	if img.get_width() > ANCHO_MAX:
		var alto := maxi(1, int(float(img.get_height()) * ANCHO_MAX / float(img.get_width())))
		img.resize(ANCHO_MAX, alto, Image.INTERPOLATE_CUBIC)
	var bytes: PackedByteArray = img.save_png_to_buffer() if ext in ["png", "webp"] else img.save_jpg_to_buffer(0.9)
	if bytes.is_empty():
		return {"ok": false, "destino": "", "error": "No se pudo copiar la imagen."}

	var digesto := _sha256(bytes)
	var existente := _captura_con_hash(digesto, carpeta, sufijo)
	if not existente.is_empty():
		return {"ok": true, "destino": existente, "error": "", "reutilizada": true}

	var destino := _destino(carpeta, sufijo, _slug(nombre_base))
	var f := FileAccess.open(ProjectSettings.globalize_path(destino), FileAccess.WRITE)
	if f == null:
		return {"ok": false, "destino": "", "error": "No se pudo copiar la imagen."}
	f.store_buffer(bytes)
	f.close()
	return {"ok": true, "destino": destino, "error": "", "reutilizada": false}


static func _destino(carpeta: String, sufijo: String, base: String) -> String:
	var nombre := base if base != "" else "img_%d" % int(Time.get_unix_time_from_system())
	var ruta := "%s/%s%s" % [carpeta, nombre, sufijo]
	if not FileAccess.file_exists(ProjectSettings.globalize_path(ruta)):
		return ruta
	var n := 1
	while FileAccess.file_exists(ProjectSettings.globalize_path("%s/%s-%d%s" % [carpeta, nombre, n, sufijo])):
		n += 1
	return "%s/%s-%d%s" % [carpeta, nombre, n, sufijo]


static func _slug(nombre: String) -> String:
	var base := nombre.strip_edges()
	if base.is_empty():
		return ""
	for c in CARACTERES_INVALIDOS:
		base = base.replace(c, "_")
	var salida := ""
	var separador := false
	for j in base.length():
		var c: String = base[j]
		if c == "\n" or c == "\t" or c == "\r":
			c = " "
		var es_separador: bool = c == "_" or c == " "
		if es_separador and separador:
			continue
		salida += c
		separador = es_separador
	while salida.begins_with("_") or salida.begins_with(" "):
		salida = salida.substr(1)
	while salida.ends_with("_") or salida.ends_with(" "):
		salida = salida.substr(0, salida.length() - 1)
	if salida.length() > LONGITUD_MAX:
		salida = salida.substr(0, LONGITUD_MAX)
		while salida.ends_with("_") or salida.ends_with(" "):
			salida = salida.substr(0, salida.length() - 1)
	return salida


static func _sha256(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


static func _captura_con_hash(digesto: String, carpeta: String, sufijo: String) -> String:
	var dir := DirAccess.open(carpeta)
	if dir == null:
		return ""
	for f in dir.get_files():
		if ARCHIVOS_FIJOS.has(f) or not f.ends_with(sufijo):
			continue
		var ruta := "%s/%s" % [carpeta, f]
		if FileAccess.get_sha256(ProjectSettings.globalize_path(ruta)) == digesto:
			return ruta
	return ""


static func borrar(ruta: String) -> Dictionary:
	if ruta.is_empty():
		return {"ok": false, "error": "Ruta vacía."}
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	if err == OK:
		return {"ok": true, "error": ""}
	return {"ok": false, "error": "No se pudo borrar la captura."}


static func limpiar_huerfanas(referidas: Array, base := "res://Assets") -> Dictionary:
	var referidas_str: Array = []
	for r in referidas:
		referidas_str.append(str(r))
	var borradas := 0
	var errores := 0
	for patron in [[base + "/png", "png"], [base + "/jpg", "jpg"]]:
		var carpeta_patron: String = patron[0]
		var sufijo_patron := ".%s" % patron[1]
		var carpeta := DirAccess.open(carpeta_patron)
		if carpeta == null:
			continue
		for f in carpeta.get_files():
			if ARCHIVOS_FIJOS.has(f) or not f.ends_with(sufijo_patron):
				continue
			var ruta := "%s/%s" % [carpeta_patron, f]
			if ruta in referidas_str:
				continue
			if borrar(ruta).get("ok", false):
				borradas += 1
			else:
				errores += 1
	return {"ok": true, "borradas": borradas, "errores": errores}