extends RefCounted

const GestorArchivoScript := preload("res://scripts/gestor_archivo.gd")
const InformeControllerScript := preload("res://scripts/informe_controller.gd")
const DiagnosticoScript := preload("res://scripts/diagnostico.gd")

var _progreso: Label = null
var _entradas: Callable = Callable()
var _estados: Callable = Callable()
var _urls_existentes: Callable = Callable()
var _guardar: Callable = Callable()
var _cargar: Callable = Callable()
var _refrescar: Callable = Callable()
var _status: Callable = Callable()
var _urls_informe: Callable = Callable()
var _diagnostico: Callable = Callable()
var _log_app: Callable = Callable()


func _init(progreso: Label, entradas: Callable, estados: Callable, urls_existentes: Callable, guardar: Callable, cargar: Callable, refrescar: Callable, status: Callable, urls_informe: Callable, diagnostico: Callable, log_app: Callable) -> void:
	_progreso = progreso
	_entradas = entradas
	_estados = estados
	_urls_existentes = urls_existentes
	_guardar = guardar
	_cargar = cargar
	_refrescar = refrescar
	_status = status
	_urls_informe = urls_informe
	_diagnostico = diagnostico
	_log_app = log_app


func importar(ruta: String) -> void:
	var res: Dictionary = GestorArchivoScript.importar(ruta, _urls_existentes.call())
	if not res.get("ok", false):
		_progreso.text = str(res.get("error", "No se pudo importar el catálogo."))
		return
	var nuevas: Array = res.get("entradas", [])
	var omitidas := int(res.get("omitidas", 0))
	if nuevas.is_empty():
		_progreso.text = tr("%d omitidos (ya existían o sin URL válida).") % omitidas
		return
	var importados := nuevas.size()
	var destino: Array = _entradas.call()
	for entrada in nuevas:
		destino.append(entrada)
	if not _guardar.call():
		_cargar.call()
		_refrescar.call()
		_progreso.text = tr("No se pudo guardar el catálogo.")
		return
	_refrescar.call()
	_status.call()
	_progreso.text = tr("%d importados, %d omitidos.") % [importados, omitidas]


func exportar(ruta: String) -> void:
	var res: Dictionary = GestorArchivoScript.exportar(ruta, _entradas.call())
	if not res.get("ok", false):
		_progreso.text = str(res.get("error", "No se pudo exportar el catálogo."))
		return
	_progreso.text = tr("Catálogo exportado (%d enlaces).") % int(res.get("total", 0))


func informe(ruta: String) -> void:
	var formato := InformeControllerScript.formato_de(ruta)
	var solo: Array = _urls_informe.call()
	var filas: Array = InformeControllerScript.filas(_entradas.call(), _estados.call(), solo)
	var res: Dictionary = InformeControllerScript.exportar(ruta, formato, filas)
	if not res.get("ok", false):
		_progreso.text = str(res.get("error", "No se pudo guardar el informe."))
		return
	_progreso.text = tr("Informe %s guardado (%d enlaces).") % [formato.to_upper(), int(res.get("total", 0))]


func diagnostico(ruta: String) -> void:
	var datos: Dictionary = _diagnostico.call()
	var res := DiagnosticoScript.exportar(ruta, str(datos.get("base", "user://")), str(ProjectSettings.get_setting("application/config/version", "0.0.1")), int(datos.get("total", 0)), datos.get("datos", {}))
	if not res.get("ok", false):
		_progreso.text = tr("No se pudo exportar el diagnóstico (%d errores).") % int(res.get("errores", 0))
		return
	_log_app.call("diagnostico", "diagnóstico exportado a " + ruta)
	_progreso.text = tr("Diagnóstico guardado en %s.") % ruta
