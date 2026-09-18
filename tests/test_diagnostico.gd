extends SceneTree

const DiagnosticoScript := preload("res://scripts/diagnostico.gd")
const BASE := "user://__test_diag__"
const ZIP := BASE + "/diag.zip"

var _fallos := 0


func _initialize() -> void:
	DirAccess.remove_absolute(BASE)
	_plantilla()
	var res: Dictionary = DiagnosticoScript.exportar(ZIP, BASE, "0.1.0", 7)
	_check(res.get("ok", false), "exportar devuelve ok")
	_check(FileAccess.file_exists(ZIP), "el zip se crea")
	_check(_contenidos_si(), "zip incluye app.log, scan.log, enlaces.json, estados.json, config.json")
	_check(_info_ok(), "info.txt incluye App, Version, OS, Entradas=7")
	_check(_omite_inexistentes(), "ficheros inexistentes (borrados.json) se omiten sin error")
	DirAccess.remove_absolute(BASE)
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _plantilla() -> void:
	DirAccess.make_dir_recursive_absolute(BASE + "/logs")
	for nom in ["app.log", "scan.log"]:
		FileAccess.open(BASE + "/logs/" + nom, FileAccess.WRITE).store_string("x")
	for nom in ["enlaces.json", "estados.json", "config.json"]:
		FileAccess.open(BASE + "/" + nom, FileAccess.WRITE).store_string("{}")


func _contenidos_si() -> bool:
	var z := ZIPReader.new()
	if z.open(ZIP) != OK:
		return false
	var nombre := z.get_files()
	var ok := "info.txt" in nombre
	for f in ["app.log", "scan.log", "enlaces.json", "estados.json", "config.json"]:
		ok = ok and f in nombre
	z.close()
	return ok


func _info_ok() -> bool:
	var z := ZIPReader.new()
	if z.open(ZIP) != OK:
		return false
	var txt := z.read_file("info.txt").get_string_from_utf8()
	z.close()
	return "App=GestorAO" in txt and "Version=0.1.0" in txt \
		and "OS=" in txt and "Entradas=7" in txt


func _omite_inexistentes() -> bool:
	var z := ZIPReader.new()
	if z.open(ZIP) != OK:
		return false
	var ok := not ("borrados.json" in z.get_files())
	z.close()
	return ok


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)