extends SceneTree

const LIST_ITEM := preload("res://scenes/ListItem.tscn")
const ListItemScript := preload("res://scripts/list_item.gd")
const PLACEHOLDER := "res://Assets/png/no-disponible.png"
const BASE := "user://__test_list_item__"

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
	_check(_menu_completo(caido), "la fila construye el menú con 4 opciones")
	_check(_menu_completo(valido), "la fila válida también construye el menú")

	var con_imagen := _crear_item()
	con_imagen.setup("Nom", "Desc", "https://ejemplo.com/v", _generar_png_temporal())
	var sin_imagen := _crear_item()
	sin_imagen.setup("Nom", "Desc", "https://ejemplo.com/w", "")
	var inexistente := _crear_item()
	inexistente.setup("Nom", "Desc", "https://ejemplo.com/u", BASE + "/no-existe.png")

	root.add_child(con_imagen)
	root.add_child(sin_imagen)
	root.add_child(inexistente)

	await process_frame
	_check(_miniatura_es(con_imagen, false), "miniatura muestra la imagen elegida")
	_check(_miniatura_es(sin_imagen, true), "sin imagen muestra el placeholder")
	_check(_miniatura_es(inexistente, true), "imagen inexistente muestra el placeholder")

	var con_detalle := _crear_item()
	con_detalle.setup("Nom", "Desc", "https://ejemplo.com/d")
	con_detalle.aplicar_estado(true, "OK (200)", 200, 1000000000)
	root.add_child(con_detalle)
	await process_frame
	_check(con_detalle.codigo == 200, "aplicar_estado() guarda el código")
	_check(con_detalle.fecha == 1000000000, "aplicar_estado() guarda la fecha")

	var unix := 1000000000
	var esperado := ListItemScript.formatear_fecha(unix)
	_check(esperado.length() == 16, "formatear_fecha devuelve 'dd/mm/aaaa hh:mm'")
	var d_fecha := Time.get_datetime_dict_from_unix_time(unix)
	_check(esperado == "%02d/%02d/%04d %02d:%02d" % [d_fecha.day, d_fecha.month, d_fecha.year, d_fecha.hour, d_fecha.minute], "formatear_fecha compone día/mes/año y hora")
	var detallado := _crear_item()
	detallado.setup("Nom", "Desc", "https://ejemplo.com/t")
	detallado.aplicar_estado(false, "No existe (404)", 404, unix)
	root.add_child(detallado)
	await process_frame
	_check(detallado.tooltip_text == "https://ejemplo.com/t\nCódigo: 404\nComprobado: %s\nNo existe (404)" % esperado, "tooltip con estado muestra URL, código, fecha y mensaje")
	var sin_codigo := _crear_item()
	sin_codigo.setup("Nom", "Desc", "https://ejemplo.com/s")
	sin_codigo.aplicar_estado(true, "OK (200)")
	root.add_child(sin_codigo)
	await process_frame
	_check(sin_codigo.tooltip_text == "https://ejemplo.com/s\nCódigo: —\nOK (200)", "tooltip sin código muestra 'Código: —'")
	var sin_estado := _crear_item()
	sin_estado.setup("Nom", "Desc", "https://ejemplo.com/p")
	_check(sin_estado.tooltip_text == "https://ejemplo.com/p\nSin comprobar", "fila sin comprobar muestra URL y 'Sin comprobar'")

	var item := _crear_item()
	item.setup("Nom", "Desc", "https://ejemplo.com/menu")
	var emitido: Array = []
	item.editar_pedido.connect(func() -> void: emitido.append("editar"))
	item.recomprobar_pedido.connect(func() -> void: emitido.append("recomprobar"))
	item.copiar_pedido.connect(func(u: String) -> void: emitido.append(["copiar", u]))
	item.eliminar_pedido.connect(func() -> void: emitido.append("eliminar"))
	root.add_child(item)
	await process_frame

	var clic_derecho := InputEventMouseButton.new()
	clic_derecho.button_index = MOUSE_BUTTON_RIGHT
	clic_derecho.pressed = true
	item.gui_input.emit(clic_derecho)
	await process_frame
	_check(item.get_node("%MenuContexto").visible, "el clic derecho abre el menú contextual")

	item.get_node("%MenuContexto").id_pressed.emit(0)
	_check(emitido == ["editar"], "la opción Editar emite editar_pedido")
	item.get_node("%MenuContexto").id_pressed.emit(1)
	_check(emitido == ["editar", "recomprobar"], "la opción Volver a comprobar emite recomprobar_pedido")
	item.get_node("%MenuContexto").id_pressed.emit(2)
	_check(emitido == ["editar", "recomprobar", ["copiar", "https://ejemplo.com/menu"]], "la opción Copiar URL emite copiar_pedido con la URL")
	item.get_node("%MenuContexto").id_pressed.emit(3)
	_check(emitido == ["editar", "recomprobar", ["copiar", "https://ejemplo.com/menu"], "eliminar"], "la opción Eliminar emite eliminar_pedido")

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


func _menu_completo(item: Control) -> bool:
	var menu: PopupMenu = item.get_node("%MenuContexto")
	return menu != null and menu.get_item_count() == 4


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)


func _generar_png_temporal() -> String:
	DirAccess.make_dir_recursive_absolute(BASE)
	var ruta := BASE + "/prueba.png"
	var img := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	img.save_png(ruta)
	return ruta


func _miniatura_es(item: Control, placeholder_esperado: bool) -> bool:
	if not item.has_node("%Imagen"):
		return false
	var textura: Texture2D = item.get_node("%Imagen").texture
	if textura == null:
		return false
	var es_placeholder := textura.resource_path == PLACEHOLDER
	return es_placeholder == placeholder_esperado