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
	_check(_menu_completo(caido), "la fila construye el menú con 7 opciones")
	_check(_menu_completo(valido), "la fila válida también construye el menú")

	var ruta_png := _generar_png_temporal()
	var con_imagen := _crear_item()
	con_imagen.setup("Nom", "Desc", "https://ejemplo.com/v", ruta_png)
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
	_check(con_imagen.nombre == "Nom" and con_imagen.img == ruta_png, "setup expone nombre e imagen")
	_check(sin_imagen.img == "", "sin imagen la fila guarda img vacía")

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

	var fecha_label := _crear_item()
	fecha_label.setup("Nom", "Desc", "https://ejemplo.com/fl")
	root.add_child(fecha_label)
	await process_frame
	_check(fecha_label.get_node("%FechaLabel").text == "Sin comprobar", "la fila sin comprobar muestra 'Sin comprobar' en FechaLabel")

	var fecha_formateada := _crear_item()
	fecha_formateada.setup("Nom", "Desc", "https://ejemplo.com/ff")
	fecha_formateada.aplicar_estado(true, "OK (200)", 200, 1000000000)
	root.add_child(fecha_formateada)
	await process_frame
	_check(fecha_formateada.get_node("%FechaLabel").text == ListItemScript.formatear_fecha(1000000000), "la fila con fecha muestra la fecha formateada en FechaLabel")

	var item := _crear_item()
	item.setup("Nom", "Desc", "https://ejemplo.com/menu")
	var emitido: Array = []
	item.editar_pedido.connect(func() -> void: emitido.append("editar"))
	item.recomprobar_pedido.connect(func() -> void: emitido.append("recomprobar"))
	item.copiar_pedido.connect(func(u: String) -> void: emitido.append(["copiar", u]))
	item.historial_pedido.connect(func() -> void: emitido.append("historial"))
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
	_check(emitido == ["editar", "recomprobar", ["copiar", "https://ejemplo.com/menu"], "historial"], "la opción Historial emite historial_pedido")
	item.get_node("%MenuContexto").id_pressed.emit(4)
	_check(emitido == ["editar", "recomprobar", ["copiar", "https://ejemplo.com/menu"], "historial", "eliminar"], "la opción Eliminar emite eliminar_pedido")

	var item_reorden := _crear_item()
	item_reorden.setup("Nom", "Desc", "https://ejemplo.com/reorden")
	var emitido_reorden: Array = []
	item_reorden.subir_pedido.connect(func() -> void: emitido_reorden.append("subir"))
	item_reorden.bajar_pedido.connect(func() -> void: emitido_reorden.append("bajar"))
	root.add_child(item_reorden)
	await process_frame

	item_reorden.get_node("%MenuContexto").id_pressed.emit(5)
	_check(emitido_reorden == ["subir"], "la opción Subir emite subir_pedido")
	item_reorden.get_node("%MenuContexto").id_pressed.emit(6)
	_check(emitido_reorden == ["subir", "bajar"], "la opción Bajar emite bajar_pedido")

	var menu_reorden: PopupMenu = item_reorden.get_node("%MenuContexto")
	menu_reorden.set_item_disabled(menu_reorden.get_item_index(5), true)
	menu_reorden.set_item_disabled(menu_reorden.get_item_index(6), true)
	item_reorden.fijar_estado_reorden(true, true)
	_check(not menu_reorden.is_item_disabled(menu_reorden.get_item_index(5)), "fijar_estado_reorden(true,true) habilita Subir")
	_check(not menu_reorden.is_item_disabled(menu_reorden.get_item_index(6)), "fijar_estado_reorden(true,true) habilita Bajar")
	item_reorden.fijar_estado_reorden(false, false)
	_check(menu_reorden.is_item_disabled(menu_reorden.get_item_index(5)), "fijar_estado_reorden(false,false) deshabilita Subir")
	_check(menu_reorden.is_item_disabled(menu_reorden.get_item_index(6)), "fijar_estado_reorden(false,false) deshabilita Bajar")

	var cat_cliente := _crear_item()
	cat_cliente.setup("Nom", "Desc", "https://ejemplo.com/cat1", "", "cliente")
	var cat_codigos := _crear_item()
	cat_codigos.setup("Nom", "Desc", "https://ejemplo.com/cat2", "", "codigos")
	var cat_vacia := _crear_item()
	cat_vacia.setup("Nom", "Desc", "https://ejemplo.com/cat3", "", "")
	var cat_rara := _crear_item()
	cat_rara.setup("Nom", "Desc", "https://ejemplo.com/cat4", "", "rara")
	root.add_child(cat_cliente)
	root.add_child(cat_codigos)
	root.add_child(cat_vacia)
	root.add_child(cat_rara)
	await process_frame
	_check(cat_cliente.get_node("%CategoriaLabel").text == "Cliente" and cat_cliente.categoria == "cliente", "la fila muestra y guarda la categoría cliente")
	_check(cat_codigos.get_node("%CategoriaLabel").text == "Códigos fuente", "la fila muestra la etiqueta de códigos fuente")
	_check(cat_vacia.get_node("%CategoriaLabel").text == "Otro" and cat_vacia.categoria == "otro", "sin categoría la fila normaliza y muestra Otro")
	_check(cat_rara.get_node("%CategoriaLabel").text == "Otro", "categoría desconocida muestra Otro")

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
	if menu == null:
		return false
	var opciones := 0
	for i in range(menu.get_item_count()):
		if not menu.is_item_separator(i):
			opciones += 1
	if opciones != 7:
		return false
	for id in [0, 1, 2, 3, 4, 5, 6]:
		if menu.get_item_index(id) == -1:
			return false
	return true


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