extends SceneTree

const HISTORIAL := preload("res://scenes/Historial.tscn")

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	var ventana: Window = HISTORIAL.instantiate()
	root.add_child(ventana)
	await process_frame

	ventana.abrir([
		{"fecha": 1600000000, "valido": true, "codigo": 200, "mensaje": "OK (200)"},
		{"fecha": 1600000000, "valido": false, "codigo": 404, "mensaje": "No existe (404)"},
		{"fecha": 1600000000, "valido": null, "codigo": 0, "mensaje": "Sin respuesta", "intentos": 3},
		"basura",
	])
	await process_frame
	var textos := _textos(ventana)
	_check(textos.size() == 3, "historial() pinta una fila por entrada válida y descarta el resto")
	_check(textos[0].contains("Válido") and textos[0].contains("OK (200)"), "historial marca un enlace válido como Válido")
	_check(textos[1].contains("Caído") and textos[1].contains("No existe (404)"), "historial marca un enlace caído como Caído")
	_check(textos[2].contains("Sin comprobar"), "un fallo de red aparece como Sin comprobar, no como Caído (#54)")
	_check(textos[2].contains("(3 intentos)"), "el historial indica los intentos de reintento (#54)")
	_check(textos[2].contains("Sin respuesta"), "el historial conserva el motivo del fallo de red")
	_check(not ventana.get_node("%AvisoVacio").visible, "con filas el aviso de vacío se oculta")

	ventana.get_node("%ListaHistorial").get_child(0).queue_free()
	await process_frame
	ventana.get_node("%ListaHistorial").get_child(0).free()

	ventana.abrir([{"fecha": 1600000000, "valido": true, "codigo": 200, "mensaje": "OK (200)"}])
	await process_frame
	ventana.abrir([])
	await process_frame
	_check(_textos(ventana).is_empty(), "abrir() vacío deja la lista sin filas")
	_check(ventana.get_node("%AvisoVacio").visible, "sin filas el aviso de vacío se muestra")

	ventana.free()
	_cerrar()


func _textos(ventana: Window) -> PackedStringArray:
	var lista: Array = []
	for hijo in ventana.get_node("%ListaHistorial").get_children():
		if hijo is Label:
			lista.append(str((hijo as Label).text))
	var res := PackedStringArray()
	for t in lista:
		res.append(t)
	return res


func _cerrar() -> void:
	if _fallos == 0:
		print("TESTS OK")
	else:
		print("TESTS FALLIDOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)


func _check(cond: bool, nombre: String) -> void:
	if cond:
		print("  OK: %s" % nombre)
	else:
		_fallos += 1
		printerr("  check FALLIDO — ", nombre)
