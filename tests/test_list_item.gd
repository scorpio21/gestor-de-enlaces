extends SceneTree

const LIST_ITEM := preload("res://scenes/ListItem.tscn")

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	var caido := _crear_item()
	caido.aplicar_estado(false, "No existe (404)")
	var valido := _crear_item()
	valido.aplicar_estado(true, "OK (200)")
	var fresco := _crear_item()

	root.add_child(caido)
	root.add_child(valido)
	root.add_child(fresco)

	await process_frame
	_check(_acciones_visibles(caido), "restaurar enlace caído muestra los botones de acción")
	_check(not _acciones_visibles(valido), "restaurar enlace válido oculta los botones de acción")
	_check(not _acciones_visibles(fresco), "enlace sin estado oculta los botones de acción")

	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _crear_item() -> Control:
	var item: Control = LIST_ITEM.instantiate()
	item.setup("Nombre de prueba", "Descripción", "https://ejemplo.com/x")
	return item


func _acciones_visibles(item: Control) -> bool:
	return item.get_node("%Acciones").visible


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)