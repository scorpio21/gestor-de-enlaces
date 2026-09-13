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
