extends SceneTree

const UpdateControllerScript := preload("res://scripts/update_controller.gd")
const ConfigControllerScript := preload("res://scripts/config_controller.gd")
const ConfigStoreScript := preload("res://scripts/config_store.gd")
const DialogosControllerScript := preload("res://scripts/dialogos_controller.gd")
const BASE := "user://__test_update_ctrl__"

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	_limpiar_base()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE))
	var store = ConfigStoreScript.new(BASE)
	var ctrl = ConfigControllerScript.new()
	var dialogos = DialogosControllerScript.new()
	var dialogo := ConfirmationDialog.new()
	dialogo.name = "DialogoActualizacion"
	root.add_child(dialogo)
	var updates = UpdateControllerScript.new(root, dialogo, store, ctrl, dialogos, func() -> Array: return ["fecha", -1])
	await process_frame

	# En headless la comprobación manual abre el diálogo de error.
	updates.comprobar(true)
	_check(dialogo.visible, "comprobar(true) en headless abre el diálogo")
	_check(dialogo.dialog_text == "No se pudo comprobar actualizaciones.", "y dice que no se pudo comprobar")
	dialogo.hide()

	# La comprobación automática en headless no hace nada.
	updates.comprobar(false)
	_check(not dialogo.visible, "comprobar(false) en headless no abre nada")

	# Nueva versión: el diálogo se rellena y cerrar persiste la versión vista.
	updates.on_terminado({"nueva": true, "version": "2.0", "url": "https://github.com/scorpio21/gestor-de-enlaces", "error": ""}, true)
	_check(dialogo.visible, "nueva versión abre el diálogo")
	_check(dialogo.dialog_text == "Hay una nueva versión: 2.0", "el diálogo muestra la versión nueva")
	_check(dialogo.ok_button_text == "Ver release", "el botón principal es Ver release")
	_check(dialogo.get_cancel_button().visible, "la nueva versión ofrece cancelar")
	updates.on_cerrar()
	_check(str(store.cargar().get("ultima_version_vista", "")) == "2.0", "cerrar el aviso persiste la versión vista")
	_check(str(store.cargar().get("orden_columna", "")) == "fecha", "persistir conserva el orden actual")
	_check(int(store.cargar().get("orden_direccion", 0)) == -1, "y su dirección")
	dialogo.hide()

	# Comprobación manual al día: abre diálogo sin cancelar.
	updates.on_terminado({"nueva": false, "version": "0.3.0", "url": "", "error": ""}, true)
	_check(dialogo.visible, "comprobación manual al día abre el diálogo")
	_check(not dialogo.get_cancel_button().visible, "al día no ofrece cancelar")
	dialogo.hide()

	# persistir_version_vista conserva el resto de la configuración (#62).
	ctrl.guardar(store, {"tema": "oscuro", "aceptar_certificados": true, "reintentar_transitorios": false})
	updates.persistir_version_vista()
	_check(store.cargar().get("aceptar_certificados") == true, "persistir la versión vista no borra aceptar_certificados (#62)")
	_check(store.cargar().get("reintentar_transitorios") == false, "ni reintentar_transitorios (#62)")
	_check(str(store.cargar().get("tema", "")) == "oscuro", "ni el tema")

	# on_ver sin url no abre el shell, pero persiste y limpia el estado.
	updates.on_terminado({"nueva": true, "version": "3.0", "url": "", "error": ""}, true)
	updates.on_ver()
	_check(str(store.cargar().get("ultima_version_vista", "")) == "3.0", "ver el aviso persiste la versión vista")
	_check(not dialogos.con_aviso(), "ver el aviso limpia el estado pendiente")

	root.remove_child(dialogo)
	dialogo.queue_free()
	_limpiar_base()

	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _limpiar_base() -> void:
	if FileAccess.file_exists("%s/config.json" % BASE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/config.json" % BASE))
	if DirAccess.dir_exists_absolute(BASE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BASE))


func _check(condicion: bool, texto: String) -> void:
	if condicion:
		return
	_fallos += 1
	print("FALLO: %s" % texto)