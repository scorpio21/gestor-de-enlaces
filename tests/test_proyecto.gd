extends SceneTree

var _fallos := 0


func _initialize() -> void:
	_check(_version_ok(), "project.godot tiene config/version=0.1.9")
	_check(_icon_ok(), "project.godot apunta a Assets/icon/icon.svg")
	_check(_title_ok(), "project.godot tiene título GestorAO v0.1.9")
	_a_assets()
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _a_assets() -> void:
	var permitidas := [
		'var ASSETS_BASE := "res://Assets"',
		'const PLACEHOLDER := preload("res://Assets/png/no-disponible.png")',
	]
	for ruta in ["res://scripts/main.gd", "res://scripts/agregar_enlace.gd"]:
		var limpio := FileAccess.get_file_as_string(ruta)
		for decl in permitidas:
			limpio = limpio.replace(decl, "")
		_check(limpio.count("res://Assets") == 0, "%s no vuelve a escribir res://Assets a pelo (#48)" % ruta.get_file())
	var dir := DirAccess.open("res://tests")
	var sueltas: Array = []
	if dir != null:
		for f in dir.get_files():
			if f.ends_with(".gd") and f.begins_with("test_"):
				var txt := FileAccess.get_file_as_string("res://tests/%s" % f)
				if txt.contains("MAIN_SCENE.instantiate()") and not txt.contains("ASSETS_BASE"):
					sueltas.append(f)
	_check(sueltas.is_empty(), "toda suite que instancia Main aísla ASSETS_BASE (#48)" + ("" if sueltas.is_empty() else ": %s" % ", ".join(sueltas)))


func _version_ok() -> bool:
	return ProjectSettings.get_setting("application/config/version") == "0.1.9"


func _icon_ok() -> bool:
	return ProjectSettings.get_setting("application/config/icon") == "res://Assets/icon/icon.svg"


func _title_ok() -> bool:
	return ProjectSettings.get_setting("display/window/title") == "GestorAO v0.1.9"


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)