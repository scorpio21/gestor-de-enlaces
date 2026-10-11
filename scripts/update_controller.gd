extends RefCounted

const ActualizadorScript := preload("res://scripts/actualizador.gd")
const DialogosControllerScript := preload("res://scripts/dialogos_controller.gd")

var _padre: Node = null
var _dialogo: ConfirmationDialog = null
var _config_store = null
var _config_ctrl = null
var _dialogos = null
var _orden: Callable = Callable()


func _init(padre: Node, dialogo: ConfirmationDialog, config_store, config_ctrl, dialogos, orden: Callable) -> void:
	_padre = padre
	_dialogo = dialogo
	_config_store = config_store
	_config_ctrl = config_ctrl
	_dialogos = dialogos
	_orden = orden
	if _dialogo != null:
		_dialogo.confirmed.connect(on_ver)
		_dialogo.canceled.connect(on_cerrar)


func lanzar_auto(espera: float = 1.0) -> void:
	if _es_headless():
		return
	await _padre.get_tree().create_timer(espera).timeout
	comprobar(false)


func comprobar(manual: bool) -> void:
	if _es_headless():
		if manual:
			avisar("error", "", "")
		return
	var actualizador: Node = ActualizadorScript.new()
	_padre.add_child(actualizador)
	actualizador.terminado.connect(func(r: Dictionary) -> void: on_terminado(r, manual))
	actualizador.comprobar()


func on_terminado(resultado: Dictionary, manual: bool) -> void:
	var version_actual := str(ProjectSettings.get_setting("application/config/version", "0.0.1"))
	var aviso: Dictionary = DialogosControllerScript.resultado_actualizacion(
		resultado, manual, str(_config_store.cargar().get("ultima_version_vista", "")), version_actual)
	if not aviso.is_empty():
		avisar(str(aviso.get("modo", "")), str(aviso.get("version", "")), str(aviso.get("url", "")))


func avisar(modo: String, version: String, url: String) -> void:
	var contenido: Dictionary = _dialogos.aviso_actualizacion(modo, version, url)
	_dialogo.title = str(contenido.get("titulo", ""))
	_dialogo.dialog_text = str(contenido.get("texto", ""))
	_dialogo.ok_button_text = str(contenido.get("ok", ""))
	_dialogo.get_cancel_button().visible = bool(contenido.get("cancelar", false))
	_dialogo.popup_centered()


func on_ver() -> void:
	if not _dialogos.url_aviso().is_empty():
		OS.shell_open(_dialogos.url_aviso())
	persistir_version_vista()
	_dialogos.limpiar_aviso()


func on_cerrar() -> void:
	if _dialogos.con_aviso():
		persistir_version_vista()
	_dialogos.limpiar_aviso()


func persistir_version_vista() -> void:
	var orden: Array = _orden.call()
	_config_ctrl.guardar(_config_store, {
		"ultima_version_vista": _dialogos.version_aviso(),
		"orden_columna": orden[0],
		"orden_direccion": orden[1],
	})


func _es_headless() -> bool:
	return DisplayServer.get_name() == "headless"