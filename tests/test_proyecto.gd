extends SceneTree

var _fallos := 0


func _initialize() -> void:
	_check(_version_ok(), "project.godot tiene config/version=0.3.0")
	_check(_icon_ok(), "project.godot apunta a Assets/icon/icon.svg")
	_check(_title_ok(), "project.godot tiene título GestorAO v0.3.0")
	_check(_version_un_lugar_ok(), "el rótulo de Main.tscn lleva la misma versión que project.godot")
	_rutas()
	_cache_texturas()
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _rutas() -> void:
	for ruta in ["res://scripts/main.gd", "res://scripts/agregar_enlace.gd", "res://scripts/list_item.gd", "res://scripts/gestor_imagenes.gd"]:
		var sueltas := 0
		for linea in FileAccess.get_file_as_string(ruta).split("\n"):
			if "res://" in linea and "preload(\"res://" not in linea:
				sueltas += 1
		_check(sueltas == 0, "%s solo usa res:// dentro de preload (#50)" % ruta.get_file())
	var rutas_txt := FileAccess.get_file_as_string("res://scripts/rutas.gd")
	_check('const ASSETS_RES := "res://Assets"' in rutas_txt and 'const ASSETS_USER := "user://Assets"' in rutas_txt, "rutas.gd separa la base de lectura de la de escritura (#50)")
	_check(FileAccess.get_file_as_string("res://scripts/main.gd").contains("RutasScript.es_escribible(DATA_RES)"), "main.gd no escribe el catálogo base sin comprobar (#50)")
	var dir := DirAccess.open("res://tests")
	var sueltas_test: Array = []
	if dir != null:
		for f in dir.get_files():
			if f.ends_with(".gd") and f.begins_with("test_"):
				var txt := FileAccess.get_file_as_string("res://tests/%s" % f)
				if txt.contains("MAIN_SCENE.instantiate()") and not txt.contains("ASSETS_BASE"):
					sueltas_test.append(f)
	_check(sueltas_test.is_empty(), "toda suite que instancia Main aísla ASSETS_BASE (#48)" + ("" if sueltas_test.is_empty() else ": %s" % ", ".join(sueltas_test)))


func _cache_texturas() -> void:
	var sueltas: Array = []
	for ruta in ["res://scripts/list_item.gd", "res://scripts/agregar_enlace.gd"]:
		if FileAccess.get_file_as_string(ruta).contains("Image.load_from_file"):
			sueltas.append(ruta.get_file())
	_check(sueltas.is_empty(), "las miniaturas se cargan solo a través de cache_texturas (#52)" + ("" if sueltas.is_empty() else ": %s" % ", ".join(sueltas)))
	_check(FileAccess.get_file_as_string("res://scripts/list_item.gd").contains("CacheTexturasScript.textura("), "list_item.gd usa la caché de texturas (#52)")


func _version_ok() -> bool:
	return ProjectSettings.get_setting("application/config/version") == "0.3.0"


func _version_un_lugar_ok() -> bool:
	# La versión vive en project.godot y todo el código la lee de ahí, pero el
	# rótulo de la barra de estado la lleva como literal en la escena para que el
	# editor y las capturas no muestren la vieja. Son tres sitios y el bump se
	# olvidaba de uno: aquí se comprueba que no se vuelvan a desincronizar.
	var v := str(ProjectSettings.get_setting("application/config/version"))
	return FileAccess.get_file_as_string("res://scenes/Main.tscn").contains("text = \"v%s\"" % v)


func _icon_ok() -> bool:
	return ProjectSettings.get_setting("application/config/icon") == "res://Assets/icon/icon.svg"


func _title_ok() -> bool:
	return ProjectSettings.get_setting("display/window/title") == "GestorAO v0.3.0"


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)