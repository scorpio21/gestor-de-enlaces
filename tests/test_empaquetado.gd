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


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)