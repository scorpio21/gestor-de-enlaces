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
	_check(_catalogo_extraido(), "el alta, edicion y borrado viven en catalogo_controller, no en main.gd (#62)")
	_check(_main_no_secha(), "main.gd se ha ido encogiendo con cada entrega de #62 y #57")
	_check(_cambios_extraidos(), "el calculo de cambios vive en cambios_controller y cambios_store, no en main.gd (#57)")
	_check(_seleccion_extraida(), "la seleccion multiple vive en seleccion_controller, no en main.gd (#58)")
	_check(_informe_extraido(), "el armado del informe vive en informe_controller, no en main.gd (#58)")
	_check(_marca_cambio_segura(), "list_item no busca %MarcaCambio a saco: la grilla no lo tiene (#58)")
	_check(_reubicar_extraido(), "el criterio de reubicacion vive en redirecciones.gd, no en main.gd (#59)")
	_check(_url_final_propaga(), "la URL final viaja del checker al estado y se persiste (#59)")
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


func _catalogo_extraido() -> bool:
	var main := _leer("res://scripts/main.gd")
	if "catalogo_controller.gd" not in main or "_catalogo." not in main:
		return false
	var fuera_de_main := [
		"for u in nuevas:",
		'datos["tags"] = EtiquetasScript.parsear',
		"for i in range(entradas.size() - 1, -1, -1):",
		"var canónicas",
	]
	for marca in fuera_de_main:
		if marca in main:
			return false
	return FileAccess.file_exists("res://scripts/catalogo_controller.gd") \
		and FileAccess.file_exists("res://tests/test_catalogo_controller.gd")


func _main_no_secha() -> bool:
	var main := _leer("res://scripts/main.gd")
	return main.split("\n").size() <= 1700


func _seleccion_extraida() -> bool:
	var main := _leer("res://scripts/main.gd")
	var prohibidas := [
		"func alternar(",
		"func seleccionar_todo(",
		"func limpiar(",
		"func conservar(",
		"func interse",
		"func ancla(",
		"func atajo_de(",
		"func filas_de(",
		"func texto_urls(",
		"func texto_contador(",
		"func texto_copiadas(",
		"func texto_borrados(",
		"func texto_eliminar(",
	]
	for prohibida in prohibidas:
		if main.contains(prohibida):
			return false
	if not main.contains("SeleccionControllerScript.atajo_de("):
		return false
	return FileAccess.file_exists("res://scripts/seleccion_controller.gd") \
		and FileAccess.file_exists("res://tests/test_seleccion_controller.gd") \
		and FileAccess.file_exists("res://tests/test_main_seleccion.gd")


func _informe_extraido() -> bool:
	var main := _leer("res://scripts/main.gd")
	var prohibidas := ["informe_store.gd", "exportar_csv(", "exportar_html(", "func _formato_informe("]
	for prohibida in prohibidas:
		if main.contains(prohibida):
			return false
	return FileAccess.file_exists("res://scripts/informe_controller.gd") \
		and FileAccess.file_exists("res://tests/test_informe_controller.gd")


func _marca_cambio_segura() -> bool:
	var item := _leer("res://scripts/list_item.gd")
	if not item.contains("get_node_or_null(\"%MarcaCambio\")"):
		return false
	return not item.contains("%MarcaCambio.")


func _reubicar_extraido() -> bool:
	var main := _leer("res://scripts/main.gd")
	var prohibidas := [
		"func normalizada(",
		"func reubicable(",
		"func clasificar(",
		"func texto_actualizar_uno(",
		"func texto_actualizar_varios(",
		"func texto_confirmar(",
		"\"Redirige a: %s\"",
		"\"¿Actualizar «%s» a %s?\"",
	]
	for texto in prohibidas:
		if main.contains(texto):
			return false
	if not main.contains("RedireccionesScript.reubicables_de("):
		return false
	return FileAccess.file_exists("res://scripts/redirecciones.gd") \
		and FileAccess.file_exists("res://tests/test_redirecciones.gd")


func _url_final_propaga() -> bool:
	var checker := _leer("res://scripts/link_checker.gd")
	if not checker.contains("signal terminado(valido: bool, mensaje: String, codigo: int, url_final: String)"):
		return false
	var store := _leer("res://scripts/estado_store.gd")
	if not store.contains("\"url_final\": url_final"):
		return false
	return _leer("res://scripts/main.gd").contains("item.url_final")


func _cambios_extraidos() -> bool:
	var main := _leer("res://scripts/main.gd")
	if main.contains("cambios_store.gd"):
		return false
	return FileAccess.file_exists("res://scripts/cambios_controller.gd") \
		and FileAccess.file_exists("res://scripts/cambios_store.gd") \
		and FileAccess.file_exists("res://tests/test_cambios_controller.gd")


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)