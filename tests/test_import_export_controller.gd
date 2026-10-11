extends SceneTree

const ImportExportControllerScript := preload("res://scripts/import_export_controller.gd")
const BASE := "user://__test_import_export__"

var _fallos := 0
var _entradas: Array = []
var _estados: Dictionary = {}
var _urls_informe: Array = []
var _guardar_ok := true
var _log: Array = []
var _guardados := 0
var _cargados := 0
var _refrescos := 0
var _status := 0
var _cargar_reemplaza := false
var _progreso: Label
var _ctrl: RefCounted


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	_limpiar()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE))
	_progreso = Label.new()
	root.add_child(_progreso)
	_ctrl = ImportExportControllerScript.new(
		_progreso,
		func() -> Array: return _entradas,
		func() -> Dictionary: return _estados,
		func() -> Array: return _urls_catalogo(),
		_guardar,
		_cargar,
		func() -> void: _refrescos += 1,
		func() -> void: _status += 1,
		_tomar_urls,
		func() -> Dictionary: return {"base": BASE, "total": _entradas.size(), "datos": {"prueba": "si"}},
		func(tipo: String, msg: String) -> void: _log.append([tipo, msg])
	)

	_exportar_ok()
	_exportar_error()
	_importar_ok()
	_importar_omitidos()
	_importar_error()
	_importar_guardar_error()
	_informe_csv()
	_informe_html()
	_informe_filtrado()
	_diagnostico_ok()
	_diagnostico_error()

	root.remove_child(_progreso)
	_progreso.queue_free()
	_limpiar()

	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _exportar_ok() -> void:
	_entradas = [
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": "", "cat": "otro"},
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": "", "cat": "otro"},
	]
	var ruta := BASE + "/export.json"
	_ctrl.exportar(ruta)
	_check(FileAccess.file_exists(ruta), "exportar escribe el catálogo")
	_check(_progreso.text == "Catálogo exportado (2 enlaces).", "exportar informa del total exportado")


func _exportar_error() -> void:
	_entradas = []
	_ctrl.exportar(BASE + "/sub/no/x.json")
	_check(_progreso.text == "No se pudo escribir el archivo.", "exportar a una ruta inválida avisa del error del módulo")


func _importar_ok() -> void:
	_entradas = []
	_guardar_ok = true
	_guardados = 0
	_cargados = 0
	_refrescos = 0
	_status = 0
	var ruta := BASE + "/entrada.json"
	_escribir(ruta, [
		{"nombre": "A", "url": "https://a.test"},
		{"nombre": "B", "url": "https://b.test"},
		{"nombre": "dup", "url": "https://a.test"},
		{"nombre": "sin", "url": ""},
	])
	_ctrl.importar(ruta)
	_check(_entradas.size() == 2, "importar añade solo las entradas nuevas y válidas")
	_check(_progreso.text == "2 importados, 2 omitidos.", "importar informa de importados y omitidos")
	_check(_guardados == 1, "importar persiste una vez")
	_check(_refrescos == 1 and _status == 1, "importar refresca y actualiza el estado")


func _importar_omitidos() -> void:
	_entradas = []
	_guardar_ok = true
	_guardados = 0
	var ruta := BASE + "/solo_duplicadas.json"
	_escribir(ruta, [
		{"nombre": "x", "url": ""},
		{"nombre": "y", "url": ""},
	])
	_ctrl.importar(ruta)
	_check(_progreso.text == "2 omitidos (ya existían o sin URL válida).", "importar sin nada válido informa solo de omitidos")
	_check(_guardados == 0, "importar sin nada válido no persiste")


func _importar_error() -> void:
	_entradas = []
	_guardados = 0
	_ctrl.importar(BASE + "/no_existe.json")
	_check(_progreso.text == "El archivo no es un catálogo válido.", "importar un archivo inexistente avisa del error del módulo")
	_check(_guardados == 0, "un archivo inválido no persiste")


func _importar_guardar_error() -> void:
	_entradas = []
	_guardar_ok = false
	_cargados = 0
	_refrescos = 0
	var ruta := BASE + "/entrada2.json"
	_escribir(ruta, [{"nombre": "A", "url": "https://a.test"}])
	_ctrl.importar(ruta)
	_check(_progreso.text == "No se pudo guardar el catálogo.", "importar avisa si no se puede guardar")
	_check(_cargados == 1 and _refrescos == 1, "tras fallar el guardado recarga y refresca")
	_guardar_ok = true


func _informe_csv() -> void:
	_entradas = [
		{"nombre": "A", "url": "https://a.test"},
		{"nombre": "B", "url": "https://b.test"},
	]
	_estados = {}
	_urls_informe = []
	var ruta := BASE + "/informe.csv"
	_ctrl.informe(ruta)
	_check(FileAccess.file_exists(ruta), "informe escribe el CSV")
	_check(_progreso.text == "Informe CSV guardado (2 enlaces).", "informe informa del formato y el total")


func _informe_html() -> void:
	_entradas = [{"nombre": "A", "url": "https://a.test"}]
	_urls_informe = []
	var ruta := BASE + "/informe.html"
	_ctrl.informe(ruta)
	_check(FileAccess.file_exists(ruta), "informe escribe el HTML")
	_check(_progreso.text == "Informe HTML guardado (1 enlaces).", "informe detecta el formato html")


func _informe_filtrado() -> void:
	_entradas = [
		{"nombre": "A", "url": "https://a.test"},
		{"nombre": "B", "url": "https://b.test"},
	]
	_urls_informe = ["https://b.test"]
	_ctrl.informe(BASE + "/informe_filtro.csv")
	_check(_urls_informe.is_empty(), "el informe consume la selección pendiente")
	_check(_progreso.text == "Informe CSV guardado (1 enlaces).", "el informe respeta la selección")


func _diagnostico_ok() -> void:
	_entradas = [{"nombre": "A", "url": "https://a.test"}]
	_log = []
	var ruta := BASE + "/diagnostico.zip"
	_ctrl.diagnostico(ruta)
	_check(FileAccess.file_exists(ruta), "el diagnóstico escribe el zip")
	_check(_progreso.text == "Diagnóstico guardado en %s." % ruta, "el diagnóstico informa de la ruta")
	_check(_log.size() == 1 and str(_log[0][0]) == "diagnostico", "el diagnóstico deja rastro en el log")


func _diagnostico_error() -> void:
	_ctrl.diagnostico(BASE + "/no_dir/diagnostico.zip")
	_check(_progreso.text == "No se pudo exportar el diagnóstico (1 errores).", "el diagnóstico avisa si no puede escribir")


func _guardar() -> bool:
	_guardados += 1
	return _guardar_ok


func _cargar() -> void:
	_cargados += 1
	if _cargar_reemplaza:
		_entradas = []


func _tomar_urls() -> Array:
	var solo := _urls_informe.duplicate()
	_urls_informe = []
	return solo


func _urls_catalogo() -> Array:
	var urls: Array = []
	for entrada in _entradas:
		if typeof(entrada) == TYPE_DICTIONARY:
			urls.append(str(entrada.get("url", "")))
	return urls


func _escribir(ruta: String, contenido: Array) -> void:
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	archivo.store_string(JSON.stringify(contenido))
	archivo.close()


func _limpiar() -> void:
	if not DirAccess.dir_exists_absolute(BASE):
		return
	var dir := DirAccess.open(BASE)
	for nombre in dir.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [BASE, nombre]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BASE))


func _check(condicion: bool, texto: String) -> void:
	if condicion:
		return
	_fallos += 1
	print("FALLO: %s" % texto)
