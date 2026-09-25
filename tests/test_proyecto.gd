extends SceneTree

var _fallos := 0


func _initialize() -> void:
	_check(_version_ok(), "project.godot tiene config/version=0.1.9")
	_check(_icon_ok(), "project.godot apunta a Assets/icon/icon.svg")
	_check(_title_ok(), "project.godot tiene título GestorAO v0.1.9")
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


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