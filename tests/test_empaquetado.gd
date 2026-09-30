extends SceneTree

var _fallos := 0


func _initialize() -> void:
	_check(_export_presets_ok(), "export_presets.cfg declara Windows, Linux/X11 y macOS")
	_check(_ci_ok(), ".github/workflows/ci.yml tiene battery y upload-artifact")
	_check(_ci_protegida(), "la CI limita el tiempo del job y ejecuta el paso estatico (#61)")
	_check(FileAccess.file_exists("res://tests/run_battery.sh"), "existe tests/run_battery.sh")
	_check(_bateria_con_timeout(), "run_battery.sh da timeout por suite (#61)")
	_check(FileAccess.file_exists("res://tests/run_estatico.sh"), "existe tests/run_estatico.sh")
	_check(FileAccess.file_exists("res://AGENTS.md"), "existe AGENTS.md")
	_check(_escaneo_extraido(), "la logica del escaneo vive en scan_controller, no en main.gd (#62)")
	_check(_lista_extraida(), "la logica de filas vive en lista_controller, no en main.gd (#62)")
	_check(_config_extraida(), "el guardado de la config vive en config_controller, no en main.gd (#62)")
	_check(_main_no_secha(), "main.gd se ha ido encogiendo con cada entrega de #62")
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _leer(ruta: String) -> String:
	var f := FileAccess.open(ruta, FileAccess.READ)
	return f.get_as_text() if f != null else ""


func _export_presets_ok() -> bool:
	var txt := _leer("res://export_presets.cfg")
	return "name=\"Windows\"" in txt and "name=\"Linux/X11\"" in txt \
		and ("platform=\"Linux/X11\"" in txt or "platform=\"Linux\"" in txt) \
		and "name=\"macOS\"" in txt


func _ci_ok() -> bool:
	var txt := _leer("res://.github/workflows/ci.yml")
	return "run_battery.sh" in txt and "upload-artifact" in txt


func _ci_protegida() -> bool:
	var txt := _leer("res://.github/workflows/ci.yml")
	return "timeout-minutes:" in txt and "run_estatico.sh" in txt


func _bateria_con_timeout() -> bool:
	var txt := _leer("res://tests/run_battery.sh")
	return "TIMEOUT_SUITE" in txt and "--headless" in txt


func _escaneo_extraido() -> bool:
	var main := _leer("res://scripts/main.gd")
	if "scan_controller.gd" not in main or "func _scan_persistir_cola" in main or "func _scan_rearmar_pendientes" in main:
		return false
	return FileAccess.file_exists("res://scripts/scan_controller.gd") \
		and FileAccess.file_exists("res://tests/test_scan_controller.gd")


func _lista_extraida() -> bool:
	var main := _leer("res://scripts/main.gd")
	if "lista_controller.gd" not in main:
		return false
	if "func _pool_devolver" in main or "func _pool_tomar" in main or "func _pool_vaciar" in main:
		return false
	return FileAccess.file_exists("res://scripts/lista_controller.gd") \
		and FileAccess.file_exists("res://tests/test_lista_controller.gd")


func _config_extraida() -> bool:
	var main := _leer("res://scripts/main.gd")
	if "config_controller.gd" not in main:
		return false
	if "func _persistir_orden" in main or "func _persistir_filtros" in main:
		return false
	if main.count("_config_store.guardar(") > 0:
		return false
	return FileAccess.file_exists("res://scripts/config_controller.gd") \
		and FileAccess.file_exists("res://tests/test_config_controller.gd")


func _main_no_secha() -> bool:
	var main := _leer("res://scripts/main.gd")
	return main.split("\n").size() <= 1600


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)