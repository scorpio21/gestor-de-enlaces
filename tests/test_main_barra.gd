extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const LIST_ITEM_SCENE := preload("res://scenes/ListItem.tscn")

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)

	await process_frame
	await process_frame

	_check(main.has_node("%Rotos"), "la barra tiene el label Rotos")
	_check(main.has_node("%Activos"), "la barra tiene el label Activos")
	_check(main.has_node("%Total"), "la barra tiene el label Total")
	_check(main.has_node("%Version"), "la barra tiene el label Version")

	if not main.has_node("%Rotos"):
		_cerrar()
		return

	_check(main.get_node("%Version").text.begins_with("v"), "la versión se muestra con prefijo v")
	_check(not main.get_node("%Rotos").text.is_empty(), "Rotos muestra un valor")
	_check(not main.get_node("%Activos").text.is_empty(), "Activos muestra un valor")
	_check(not main.get_node("%Total").text.is_empty(), "Total muestra un valor")

	var main_script = main.get_node(".")
	if main_script.has_method("_persistir_recompra"):
		main_script._estados.clear()
		var item = LIST_ITEM_SCENE.instantiate()
		item.url = "https://prueba-ejemplo.test"
		item.valido = false
		item.mensaje = "No existe"
		main_script._entradas.append({"nombre": "Prueba", "url": "https://prueba-ejemplo.test"})
		main_script._persistir_recompra(item)
		main_script._estado_store.borrar_estado(item.url)
		_check(main.get_node("%Rotos").text == "Rotos: 1", "Rotos se actualiza tras nueva comprobación")
		item.free()

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
