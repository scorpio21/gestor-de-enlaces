extends RefCounted


static func borrar_arbol(ruta: String) -> void:
	var abs := ProjectSettings.globalize_path(ruta)
	var carpeta := DirAccess.open(ruta)
	if carpeta == null:
		if DirAccess.dir_exists_absolute(abs):
			DirAccess.remove_absolute(abs)
		return
	for f in carpeta.get_files():
		DirAccess.remove_absolute(abs.path_join(f))
	for sub in carpeta.get_directories():
		borrar_arbol(ruta.path_join(sub))
	DirAccess.remove_absolute(abs)
