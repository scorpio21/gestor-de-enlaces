extends RefCounted


static func copiar(origen: String) -> Dictionary:
	if origen.is_empty():
		return {"ok": true, "destino": "", "error": ""}

	var ext := origen.get_extension().to_lower()
	var carpeta: String
	var sufijo: String
	match ext:
		"png", "webp":
			carpeta = "res://Assets/png"
			sufijo = ".png"
		"jpg", "jpeg":
			carpeta = "res://Assets/jpg"
			sufijo = ".jpg"
		_:
			return {"ok": false, "destino": "", "error": "Formato no soportado."}

	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta))
	if err != OK:
		return {"ok": false, "destino": "", "error": "No se pudo crear la carpeta de imágenes."}

	var destino := "%s/img_%d%s" % [carpeta, int(Time.get_unix_time_from_system()), sufijo]
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
	var f := FileAccess.open(ProjectSettings.globalize_path(destino), FileAccess.WRITE)
	if f == null:
		return {"ok": false, "destino": "", "error": "No se pudo copiar la imagen."}
	f.store_buffer(bytes)
	f.close()
	return {"ok": true, "destino": destino, "error": "", "reutilizada": false}


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
		if not (f.begins_with("img_") and f.ends_with(sufijo)):
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


static func limpiar_huerfanas(referidas: Array) -> Dictionary:
	var referidas_str: Array = []
	for r in referidas:
		referidas_str.append(str(r))
	var borradas := 0
	var errores := 0
	for patron in [["res://Assets/png", "png"], ["res://Assets/jpg", "jpg"]]:
		var carpeta_patron: String = patron[0]
		var ext: String = patron[1]
		var carpeta := DirAccess.open(carpeta_patron)
		if carpeta == null:
			continue
		for f in carpeta.get_files():
			if not (f.begins_with("img_") and f.ends_with(".%s" % ext)):
				continue
			var ruta := "%s/%s" % [carpeta_patron, f]
			if ruta in referidas_str:
				continue
			if borrar(ruta).get("ok", false):
				borradas += 1
			else:
				errores += 1
	return {"ok": true, "borradas": borradas, "errores": errores}