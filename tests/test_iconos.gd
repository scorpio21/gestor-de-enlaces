extends SceneTree

const GenerarIconos := preload("res://scripts/generar_iconos.gd")
const BASE := "user://__test_iconos__"

var _fallos := 0


func _initialize() -> void:
	DirAccess.remove_absolute(BASE)
	var res: Dictionary = GenerarIconos.generar(BASE)
	_check(res.get("ok", false) and int(res.get("total", -1)) == 6, "generar produce 6 ficheros")
	_check(_cabeza_icns_ok(), "icon.icns empieza por la cabecera icns")
	_check(_cabeza_ico_ok(), "icon.ico empieza por la cabecera ICO (00 00 01 00)")
	_check(_png_valido(), "icon_256.png es PNG válido (cabecera PNG + dimensión 256)")
	_check(FileAccess.file_exists(BASE + "/icon.svg"), "icon.svg se genera")
	_check(FileAccess.file_exists(BASE + "/flag_es.svg"), "flag_es.svg se genera")
	_check(FileAccess.file_exists(BASE + "/flag_gb.svg"), "flag_gb.svg se genera")
	_check(_svg_valido(BASE + "/flag_es.svg"), "flag_es.svg es SVG válido (<svg ...>...)</svg>)")
	_check(_svg_valido(BASE + "/flag_gb.svg"), "flag_gb.svg es SVG válido (<svg ...>...)</svg>)")
	DirAccess.remove_absolute(BASE)
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _cabeza_icns_ok() -> bool:
	var f := FileAccess.open(BASE + "/icon.icns", FileAccess.READ)
	if f == null:
		return false
	var cab := f.get_buffer(4).get_string_from_ascii()
	return cab == "icns"


func _cabeza_ico_ok() -> bool:
	var f := FileAccess.open(BASE + "/icon.ico", FileAccess.READ)
	if f == null:
		return false
	var b := f.get_buffer(4)
	return b[0] == 0 and b[1] == 0 and b[2] == 1 and b[3] == 0


func _png_valido() -> bool:
	var f := FileAccess.open(BASE + "/icon_256.png", FileAccess.READ)
	if f == null:
		return false
	var cab := f.get_buffer(8)
	var ok_cab := cab[0] == 0x89 and cab[1] == 0x50 and cab[2] == 0x4e and cab[3] == 0x47
	f.seek(0)
	var im := Image.new()
	var err := im.load_png_from_buffer(f.get_buffer(f.get_length()))
	return ok_cab and err == OK and im.get_width() == 256 and im.get_height() == 256


func _svg_valido(ruta: String) -> bool:
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return false
	var s := f.get_as_text()
	return s.strip_edges().begins_with("<svg ") and s.count("</svg>") == 1


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)