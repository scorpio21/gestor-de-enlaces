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

	ventana.aplicado.connect(func(p: int, t: float, a: bool, i: int, tm: String, id: String) -> void: _aplicado = [p, t, a, i, tm, id])
	ventana.abrir(5, 20.0, false, 15, "oscuro")
	await process_frame
	_check(is_equal_approx(ventana.get_node("%Paralelismo").value, 5.0), "abrir precarga el paralelismo")
	_check(is_equal_approx(ventana.get_node("%Timeout").value, 20.0), "abrir precarga el timeout")
	_check(ventana.get_node("%AutoAbrir").button_pressed == false \
		and ventana.get_node("%IntervaloAuto").get_selected_id() == 15, "abrir precarga auto_abrir e intervalo")
	_check(ventana.get_node("%Tema").get_selected_id() == 0, "abrir precarga el tema")
	_check(ventana.get_node("%Idioma").get_selected_id() == 0, "abrir precarga el idioma es")
	_check(ventana.size.y >= ventana.get_node("Margen/Columna").get_combined_minimum_size().y, \
		"la ventana ajusta su alto al contenido (no desborda ni solapa)")

	ventana.get_node("%BotonCancelar").pressed.emit()
	_check(_aplicado == null and not ventana.visible, "cancelar no emite aplicado y oculta")

	ventana.abrir(5, 20.0, true, 30, "claro", "en")
	await process_frame
	_check(ventana.get_node("%Idioma").get_selected_id() == 1, "abrir precarga el idioma en")
	ventana.get_node("%Paralelismo").value = 7
	ventana.get_node("%Timeout").value = 15.0
	ventana.get_node("%AutoAbrir").button_pressed = true
	ventana.get_node("%IntervaloAuto").select(3)
	ventana.get_node("%BotonGuardar").pressed.emit()
	_check(_aplicado != null and _aplicado[0] == 7 and is_equal_approx(_aplicado[1], 15.0), "guardar emite aplicado con paralelismo y timeout")
	_check(_aplicado != null and _aplicado[2] == true and _aplicado[3] == 60, "guardar emite aplicado con auto_abrir e intervalo")
	_check(_aplicado != null and _aplicado[4] == "claro", "guardar emite el tema elegido")
	_check(_aplicado != null and _aplicado[5] == "en", "guardar emite el idioma elegido")

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
