extends SceneTree

const LoggerScript := preload("res://scripts/logger.gd")
const BASE := "user://__test_logger__"

var _fallos := 0


func _initialize() -> void:
	_limpiar()
	DirAccess.make_dir_recursive_absolute("user://")
	_check(inicia_crea_ficheros(), "iniciar crea logs/app.log y logs/scan.log")
	_check(app_escribe_linea(), "app() escribe línea [APP] en app.log")
	_check(scan_escribe_linea(), "scan() escribe línea [SCAN] en scan.log")
	_check(rotacion_genera_log1(), "al superar max_bytes rota a .log.1")
	_check(sin_sobreescribir_al_reabrir(), "iniciar sobre base existente no borra el contenido previo")
	_limpiar()
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func inicia_crea_ficheros() -> bool:
	var l := LoggerScript.new(BASE)
	return FileAccess.file_exists(BASE + "/logs/app.log") \
		and FileAccess.file_exists(BASE + "/logs/scan.log")


func app_escribe_linea() -> bool:
	var l := LoggerScript.new(BASE)
	l.app("error", "fallo de prueba")
	l.flush()
	var txt := FileAccess.open(BASE + "/logs/app.log", FileAccess.READ).get_as_text()
	return txt.begins_with("[APP][error]") and txt.ends_with("fallo de prueba\n")


func scan_escribe_linea() -> bool:
	var l := LoggerScript.new(BASE)
	l.scan("https://ejemplo.test", "valido", "OK (200)")
	l.flush()
	var txt := FileAccess.open(BASE + "/logs/scan.log", FileAccess.READ).get_as_text()
	return txt.begins_with("[SCAN] ") and "https://ejemplo.test" in txt \
		and "valido" in txt and "OK (200)" in txt


func rotacion_genera_log1() -> bool:
	DirAccess.remove_absolute(BASE + "/logs/app.log.1")
	var l := LoggerScript.new(BASE, 200)
	for i in range(10):
		l.app("error", "linea de relleno %d para forzar rotacion" % i)
	l.flush()
	return FileAccess.file_exists(BASE + "/logs/app.log.1") \
		and FileAccess.file_exists(BASE + "/logs/app.log")


func sin_sobreescribir_al_reabrir() -> bool:
	var l := LoggerScript.new(BASE)
	l.app("error", "primera")
	l.flush()
	var l2 := LoggerScript.new(BASE)
	l2.app("error", "segunda")
	l2.flush()
	var txt := FileAccess.open(BASE + "/logs/app.log", FileAccess.READ).get_as_text()
	return "primera" in txt and "segunda" in txt


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)


func _limpiar() -> void:
	DirAccess.remove_absolute(BASE)