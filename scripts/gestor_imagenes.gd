extends RefCounted


static func copiar(origen: String) -> Dictionary:
	if origen.is_empty():
		return {"ok": true, "destino": "", "error": ""}

	var carpeta := ProjectSettings.globalize_path("res://Assets/png")
	var err := DirAccess.make_dir_recursive_absolute(carpeta)
	if err != OK:
		return {"ok": false, "destino": "", "error": "No se pudo crear la carpeta de imágenes."}

	var destino := "res://Assets/png/img_%d.png" % int(Time.get_unix_time_from_system())
	var img: Image = Image.load_from_file(origen)
	if img == null or img.is_empty():
		return {"ok": false, "destino": "", "error": "No se pudo copiar la imagen."}
	const ANCHO_MAX := 800
	if img.get_width() > ANCHO_MAX:
		var alto := maxi(1, int(float(img.get_height()) * ANCHO_MAX / float(img.get_width())))
		img.resize(ANCHO_MAX, alto, Image.INTERPOLATE_CUBIC)
	if img.save_png(ProjectSettings.globalize_path(destino)) != OK:
		return {"ok": false, "destino": "", "error": "No se pudo copiar la imagen."}
	return {"ok": true, "destino": destino, "error": ""}


static func borrar(ruta: String) -> Dictionary:
	if ruta.is_empty():
		return {"ok": false, "error": "Ruta vacía."}
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	if err == OK:
		return {"ok": true, "error": ""}
	return {"ok": false, "error": "No se pudo borrar la captura."}


static func limpiar_huerfanas(referidas: Array) -> Dictionary:
	var carpeta := DirAccess.open("res://Assets/png")
	if carpeta == null:
		return {"ok": false, "borradas": 0, "errores": 0, "error": "No se pudo abrir la carpeta de imágenes."}
	var referidas_str: Array = []
	for r in referidas:
		referidas_str.append(str(r))
	var borradas := 0
	var errores := 0
	for f in carpeta.get_files():
		if not (f.begins_with("img_") and f.ends_with(".png")):
			continue
		var ruta := "res://Assets/png/%s" % f
		if ruta in referidas_str:
			continue
		if borrar(ruta).get("ok", false):
			borradas += 1
		else:
			errores += 1
	return {"ok": true, "borradas": borradas, "errores": errores}
