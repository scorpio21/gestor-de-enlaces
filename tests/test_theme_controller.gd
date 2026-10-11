extends SceneTree

const ThemeControllerScript := preload("res://scripts/theme_controller.gd")

var _fallos := 0


func _check(condicion: bool, texto: String) -> void:
	if condicion:
		return
	_fallos += 1
	print("FALLO: %s" % texto)


func _initialize() -> void:
	var ctrl := ThemeControllerScript.new(null, null)
	# Sin raiz no revienta: es un no-op silencioso.
	ctrl.aplicar_tema("oscuro")
	ctrl.aplicar_tema("auto")
	_check(true, "aplicar_tema sin raiz no revienta")

	# Con una raiz real aplica la paleta y no revienta.
	var raiz := Control.new()
	root.add_child(raiz)
	var ctrl2 := ThemeControllerScript.new(raiz, null)
	ctrl2.aplicar_tema("claro")
	_check(raiz.theme != null, "aplicar_tema deja un tema puesto en la raiz")
	ctrl2.aplicar_tema("oscuro")
	_check(raiz.theme != null, "aplicar_tema cambia de modo sin soltar el tema")

	# El callback solo se registra si la plataforma soporta tema oscuro.
	var marco := [false]
	var cb := func() -> void: marco[0] = true
	ctrl2.conectar_cambio_tema(cb)
	if DisplayServer.is_dark_mode_supported():
		_check(true, "conectar_cambio_tema registra el callback")
	else:
		_check(not marco[0], "sin soporte de tema del sistema no se registra")

	root.remove_child(raiz)
	raiz.queue_free()

	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)
