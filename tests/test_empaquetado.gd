extends SceneTree

var _fallos := 0


func _initialize() -> void:
	_check(_export_presets_ok(), "export_presets.cfg declara Windows, Linux/X11 y macOS")
	_check(_macos_version_ok(), "la version del bundle macOS iguala config/version")
	_check(_ci_ok(), ".github/workflows/ci.yml tiene battery y upload-artifact")
	_check(_ci_protegida(), "la CI limita el tiempo del job y ejecuta el paso estatico (#61)")
	_check(_ci_matriz_windows(), "la CI corre la bateria tambien en Windows (#61)")
	_check(_ci_cache_importacion(), "la CI cachea .godot/imported y uid_cache.bin (#61)")
	_check(_ci_smoke(), "la CI arranca el binario exportado (#61)")
	_check(_ci_pasos_bash(), "todo paso que toca Godot va con shell: bash (#61)")
	_check(_godot_action_curl_falla(), "las descargas de la accion de Godot usan curl -f (#61)")
	_check(FileAccess.file_exists("res://tests/run_battery.sh"), "existe tests/run_battery.sh")
	_check(_bateria_con_timeout(), "run_battery.sh da timeout por suite (#61)")
	_check(FileAccess.file_exists("res://tests/run_estatico.sh"), "existe tests/run_estatico.sh")
	_check(FileAccess.file_exists("res://tests/run_smoke.sh"), "existe tests/run_smoke.sh (#61)")
	_check(_smoke_exige_marca(), "run_smoke.sh no se conforma con un codigo de salida (#61)")
	_check(_smoke_wiring(), "el binario sabe ejecutarse a si mismo en modo smoke (#61)")
	_check(FileAccess.file_exists("res://AGENTS.md"), "existe AGENTS.md")
	_check(_escaneo_extraido(), "la logica del escaneo vive en scan_controller, no en main.gd (#62)")
	_check(_lista_extraida(), "la logica de filas vive en lista_controller, no en main.gd (#62)")
	_check(_config_extraida(), "el guardado de la config vive en config_controller, no en main.gd (#62)")
	_check(_catalogo_extraido(), "el alta, edicion y borrado viven en catalogo_controller, no en main.gd (#62)")
	_check(_main_no_secha(), "main.gd se ha ido encogiendo con cada entrega (#66: dialogos fuera)")
	_check(_cambios_extraidos(), "el calculo de cambios vive en cambios_controller y cambios_store, no en main.gd (#57)")
	_check(_seleccion_extraida(), "la seleccion multiple vive en seleccion_controller, no en main.gd (#58)")
	_check(_informe_extraido(), "el armado del informe vive en informe_controller, no en main.gd (#58)")
	_check(_marca_cambio_segura(), "list_item no busca %MarcaCambio a saco: la grilla no lo tiene (#58)")
	_check(_reubicar_extraido(), "el criterio de reubicacion vive en redirecciones.gd, no en main.gd (#59)")
	_check(_url_final_propaga(), "la URL final viaja del checker al estado y se persiste (#59)")
	_check(_almacen_antes_de_stores(), "el almacenamiento se abre antes de crear los stores (#63)")
	_check(_almacen_no_preload_circular(), "almacen.gd no preloadea sus backends: seria circular (#63)")
	_check(_preferencias_enseña_almacen(), "Preferencias tiene seccion de almacenamiento (#63)")
	_check(_escritura_atomica_compartida(), "config y cola usan la escritura atomica compartida (#63)")
	_check(_dialogos_extraido(), "la logica de los dialogos vive en dialogos_controller, no en main.gd (#66)")
	_check(FileAccess.file_exists("res://tests/test_actualizador.gd"), "existe tests/test_actualizador.gd")
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


func _macos_version_ok() -> bool:
	# La version del bundle macOS se escribe a mano y el editor reescribe el
	# preset al guardar: si se queda atras, el .app miente (llego a decir 0.1.0
	# con el proyecto en 0.3.0). Se exige que las cuatro claves de version del
	# preset macOS igualen config/version de project.godot.
	var version := ""
	for linea in _leer("res://project.godot").split("\n"):
		var limpia := linea.strip_edges()
		if limpia.begins_with("config/version="):
			version = limpia.split("=", true, 1)[1].strip_edges().replace("\"", "")
	if version.is_empty():
		return false
	# Las claves de version estan en [preset.N.options], no en el [preset.N] que
	# lleva la plataforma: hay que agrupar los dos sub-bloques por numero.
	var bloques := {}
	var actual := ""
	for linea in _leer("res://export_presets.cfg").split("\n"):
		var limpia := linea.strip_edges()
		if limpia.begins_with("[preset."):
			var resto := limpia.trim_prefix("[preset.").trim_suffix("]")
			var punto := resto.find(".")
			actual = resto.substr(0, punto) if punto >= 0 else resto
			if not bloques.has(actual):
				bloques[actual] = ""
			continue
		if actual != "":
			bloques[actual] = bloques[actual] + limpia + "\n"
	var macos := ""
	for id in bloques:
		if "platform=\"macOS\"" in bloques[id]:
			macos = bloques[id]
	if macos.is_empty():
		return false
	for clave in ["application/short_version", "application/version", "application/bundle_version", "application/bundle_short_version"]:
		if not ("%s=\"%s\"" % [clave, version]) in macos:
			return false
	return true


func _ci_ok() -> bool:
	var txt := _leer("res://.github/workflows/ci.yml")
	return "run_battery.sh" in txt and "upload-artifact" in txt


func _ci_protegida() -> bool:
	var txt := _leer("res://.github/workflows/ci.yml")
	return "timeout-minutes:" in txt and "run_estatico.sh" in txt


func _ci_matriz_windows() -> bool:
	var txt := _leer("res://.github/workflows/ci.yml")
	if "os: [ubuntu-latest, windows-latest]" not in txt:
		return false
	# En Windows los dos pasos de test son bash de Git Bash, no PowerShell: con el
	# shell por defecto el script .sh no se ejecuta y el job pasa sin correr nada.
	return "shell: bash" in txt and "run_battery.sh" in txt


func _ci_cache_importacion() -> bool:
	var txt := _leer("res://.github/workflows/ci.yml")
	if ".godot/imported" not in txt or ".godot/uid_cache.bin" not in txt:
		return false
	return "hashFiles('project.godot'" in txt or "hashFiles(\"project.godot\"" in txt


func _ci_smoke() -> bool:
	var txt := _leer("res://.github/workflows/ci.yml")
	return "run_smoke.sh" in txt and "--export-release" in txt \
		and txt.find("run_smoke.sh") > txt.find("--export-release")


func _ci_pasos_bash() -> bool:
	# En windows-latest el shell por defecto de un step es pwsh, donde
	# "C:\...\godot.exe --headless --path . --import" ni siquiera parsea (hace
	# falta el operador & delante), y un bash tests/run_x.sh no se ejecuta. Cada
	# paso que toca Godot o un .sh tiene que declarar shell: bash.
	# Los pasos se parten por su "- name:" porque el cuerpo de un run: | va en
	# lineas siguientes: buscar la cadena solo en la linea del run: no encuentra
	# ni el nombre del script.
	var necesidad := ["run_battery.sh", "run_estatico.sh", "run_smoke.sh", "--import", "--export-release"]
	var pasos: Array = []
	for linea in _leer("res://.github/workflows/ci.yml").split("\n"):
		var limpia := linea.strip_edges()
		if limpia.begins_with("- name:"):
			pasos.append({"texto": limpia, "bash": false})
			continue
		if pasos.is_empty():
			continue
		var paso: Dictionary = pasos[pasos.size() - 1]
		paso["texto"] = "%s\n%s" % [paso["texto"], limpia]
		if limpia.begins_with("shell:") and "bash" in limpia:
			paso["bash"] = true
	var revisados := 0
	for entrada in pasos:
		var texto := str(entrada["texto"])
		var toca := false
		for clave in necesidad:
			if texto.contains(clave):
				toca = true
		if not toca:
			continue
		revisados += 1
		if not bool(entrada["bash"]):
			return false
	return revisados >= 5


func _godot_action_curl_falla() -> bool:
	var txt := _leer("res://.github/actions/godot/action.yml")
	# Sin -f, curl sale con 0 ante un 404 y se guarda el "Not Found" de GitHub en
	# el .zip: el fallo que se ve es "End-of-central-directory signature not
	# found" de unzip, que no dice nada de la URL. Pasa en cuanto una URL de un
	# release se queda sin .exe (el zip de Windows es win64.exe.zip, no win64.zip).
	var curls := 0
	for linea in txt.split("\n"):
		# Solo los comandos: el comentario que explica el -f menciona curl y por
		# supuesto no lleva -f.
		if not linea.strip_edges().begins_with("curl "):
			continue
		curls += 1
		if not "curl -f" in linea:
			return false
	return curls >= 2


func _smoke_exige_marca() -> bool:
	var txt := _leer("res://tests/run_smoke.sh")
	# Un codigo de salida 0 no basta: Godot puede imprimir un SCRIPT ERROR y salir
	# con 0, y sin la marca del propio script no se distingue de un arranque bien.
	# El grep se busca en la MISMA linea que SCRIPT ERROR: en el comentario que
	# explica el motivo tambien aparece la palabra, y ahi no vigila nada.
	var grep_errores := false
	var grep_marca := false
	for linea in txt.split("\n"):
		if "grep -qE" in linea and "SCRIPT ERROR" in linea:
			grep_errores = true
		if "grep -q" in linea and "smoke OK" in linea:
			grep_marca = true
	return grep_errores and grep_marca and "SMOKE_BIN" in txt and "--smoke" in txt


func _smoke_wiring() -> bool:
	var main := _leer("res://scripts/main.gd")
	if "smoke.gd" not in main or "arrancar_desde_consola" not in main:
		return false
	return FileAccess.file_exists("res://scripts/smoke.gd") \
		and FileAccess.file_exists("res://tests/test_smoke.gd")


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


func _escritura_atomica_compartida() -> bool:
	# config_store._escribir_json abria el destino en WRITE y escribia encima:
	# un corte a mitad dejaba config.json en cero. cola_store iba por .tmp y
	# rename, pero borraba el destino antes, dejando un hueco sin fichero. Los dos
	# delegan ahora en la misma de almacen.gd, que ademas deja un .bak (#63).
	for nombre in ["config_store.gd", "cola_store.gd"]:
		var src := _leer("res://scripts/%s" % nombre)
		if "AlmacenScript.escribir_json(ruta, dato)" not in src:
			return false
		if "FileAccess.open(ruta, FileAccess.WRITE)" in src:
			return false
	var almacen := _leer("res://scripts/almacen.gd")
	return "static func escribir_json" in almacen and ".bak" in almacen and "rename_absolute" in almacen


func _almacen_antes_de_stores() -> bool:
	# El orden importa: CONFIG_BASE decide de donde salen enlaces.json y el resto.
	# Si _abrir_almacen() fuera despues de ConfigStoreScript.new(), el store se
	# construiria contra user:// y el resto de la sesion escribiria ahi (#63).
	var main := _leer("res://scripts/main.gd")
	var abrir := main.find("_abrir_almacen()")
	if abrir < 0:
		return false
	for marca in ["ConfigStoreScript.new(", "InstantaneaStoreScript.new(", "PresetsStoreScript.new("]:
		var donde := main.find(marca)
		if donde < 0 or donde < abrir:
			return false
	return main.contains("_almacen.aplicar_a(self)") \
		and _leer("res://scripts/almacen_controller.gd").contains("nodo.DATA_USER = base + \"enlaces.json\"")


func _almacen_no_preload_circular() -> bool:
	# almacen.gd es la base de la que extienden los backends. Si preloadease a
	# almacen_json.gd para resolver el modo, el preload de este ultimo sobre el
	# de aquel se cortocircuitaria al cargar (#63).
	var base := _leer("res://scripts/almacen.gd")
	if "almacen_json" in base or "almacen_controller" in base:
		return false
	var json := _leer("res://scripts/almacen_json.gd")
	return "extends AlmacenScript" in json and "const AlmacenScript := preload(\"res://scripts/almacen.gd\")" in json


func _preferencias_enseña_almacen() -> bool:
	var escena := _leer("res://scenes/Preferencias.tscn")
	var codigo := _leer("res://scripts/preferencias.gd")
	for nodo in ["AlmacenBase", "BotonExaminar", "BotonAbrirCarpeta", "AlmacenDetalle", "DialogoCarpeta"]:
		if not ("name=\"%s\"" % nodo) in escena:
			return false
	return "func _mostrar_almacen() -> void:" in codigo and "migrar_a_otro" in codigo


func _dialogos_extraido() -> bool:
	var main := _leer("res://scripts/main.gd")
	if not main.contains("DialogosControllerScript") or not main.contains("_dialogos."):
		return false
	var prohibidas := [
		"_borrados_pendientes",
		"_reubicar_pendientes",
		"_limpieza_resultado",
		"_aviso_url",
		"_dialogo_version",
		"_dialogo_con_aviso",
		"func _mostrar_aviso",
		"func _limpiar_aviso",
	]
	for prohibida in prohibidas:
		if main.contains(prohibida):
			return false
	var dialogos := _leer("res://scripts/dialogos_controller.gd")
	if not dialogos.contains("static func resultado_actualizacion") \
		or not dialogos.contains("func aviso_actualizacion") \
		or not dialogos.contains("func pedir_borrado") \
		or not dialogos.contains("func pedir_reubicar"):
		return false
	return FileAccess.file_exists("res://tests/test_dialogos_controller.gd")


func _main_no_secha() -> bool:
	# #66 saco los dialogos a dialogos_controller.gd: main.gd quedo en 1676 y
	# este techo (antes 1710) le obliga a seguir encogiendose con cada entrega.
	var main := _leer("res://scripts/main.gd")
	return main.split("\n").size() <= 1676


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
		"_borrados_pendientes",
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
		"_reubicar_pendientes",
	]
	for texto in prohibidas:
		if main.contains(texto):
			return false
	var dialogos := _leer("res://scripts/dialogos_controller.gd")
	if not dialogos.contains("reubicables_de(") or not dialogos.contains("texto_confirmar("):
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