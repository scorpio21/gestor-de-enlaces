extends SceneTree

const PREF := preload("res://scenes/Preferencias.tscn")

var _fallos := 0
var _aplicado: Variant = null


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	var ventana := PREF.instantiate()
	root.add_child(ventana)
	await process_frame

	ventana.aplicado.connect(func(p: int, t: float) -> void: _aplicado = [p, t])
	ventana.abrir(5, 20.0)
	_check(is_equal_approx(ventana.get_node("%Paralelismo").value, 5.0), "abrir precarga el paralelismo")
	_check(is_equal_approx(ventana.get_node("%Timeout").value, 20.0), "abrir precarga el timeout")

	ventana.get_node("%BotonCancelar").pressed.emit()
	_check(_aplicado == null and not ventana.visible, "cancelar no emite aplicado y oculta")

	ventana.abrir(5, 20.0)
	ventana.get_node("%Paralelismo").value = 7
	ventana.get_node("%Timeout").value = 15.0
	ventana.get_node("%BotonGuardar").pressed.emit()
	_check(_aplicado != null and _aplicado[0] == 7 and is_equal_approx(_aplicado[1], 15.0), "guardar emite aplicado con los valores")

	ventana.free()
	_cerrar()


func _cerrar() -> void:
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)
