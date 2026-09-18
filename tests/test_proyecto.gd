extends SceneTree

var _fallos := 0


func _initialize() -> void:
	_check(_version_ok(), "project.godot tiene config/version=0.1.0")
	_check(_icon_ok(), "project.godot apunta a Assets/icon/icon.svg")
	_check(_title_ok(), "project.godot tiene display/window/title = GestorAO v0.1.0")
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _leer() -> String:
	var f := FileAccess.open("res://project.godot", FileAccess.READ)
	return f.get_as_text() if f != null else ""


func _version_ok() -> bool:
	return "config/version=\"0.1.0\"" in _leer()


func _icon_ok() -> bool:
	return "config/icon=\"res://Assets/icon/icon.svg\"" in _leer()


func _title_ok() -> bool:
	return "display/window/title=\"GestorAO v0.1.0\"" in _leer()


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)