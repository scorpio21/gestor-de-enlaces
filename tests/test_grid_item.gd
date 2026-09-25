extends SceneTree

const GRID_ITEM := preload("res://scenes/GridItem.tscn")
const ListItemScript := preload("res://scripts/list_item.gd")
const IdiomaScript := preload("res://scripts/idioma.gd")
const TemaStoreScript := preload("res://scripts/tema_store.gd")
const PLACEHOLDER := "res://Assets/png/no-disponible.png"
const BASE := "user://__test_grid_item__"

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	IdiomaScript.cargar_traducciones()
	TranslationServer.set_locale("es")

	var caido := _crear_item()
	caido.aplicar_estado(false, "No existe (404)")
	var valido := _crear_item()
	valido.aplicar_estado(true, "OK (200)")
	var pendiente := _crear_item()

	root.add_child(caido)
	root.add_child(valido)
	root.add_child(pendiente)
	await process_frame
	_check(_menu_completo(caido), "la tarjeta construye el menú con 7 opciones")
	_check(_menu_completo(valido), "la tarjeta válida también construye el menú")
	_check(caido.valido == false and caido.estado == "caido", "aplicar_estado guarda el estado caído")
	_check(valido.valido == true and valido.estado == "ok", "aplicar_estado guarda el estado válido")
	_check(caido.get_node("%EstadoLabel").text == "No existe (404)", "la tarjeta pinta el mensaje caído")
	_check(caido.get_node("%Indicador").color == TemaStoreScript.color_estado(false), "el indicador de color refleja el estado caído")
	_check(pendiente.get_node("%EstadoLabel").text == "Sin comprobar", "sin comprobar la tarjeta pinta Sin comprobar")
	_check(pendiente.get_node("%Indicador").color == TemaStoreScript.color_estado(null), "el indicador de color refleja el estado pendiente")

	var ruta_png := _generar_png_temporal()
	var con_imagen := _crear_item()
	con_imagen.setup("Nom", "Desc", "https://ejemplo.com/v", ruta_png)
	var sin_imagen := _crear_item()
	sin_imagen.setup("Nom", "Desc", "https://ejemplo.com/w", "")

	root.add_child(con_imagen)
	root.add_child(sin_imagen)
	await process_frame
	_check(_miniatura_es(con_imagen, false), "la tarjeta muestra la imagen elegida")
	_check(_miniatura_es(sin_imagen, true), "sin imagen la tarjeta muestra el placeholder")
	_check(con_imagen.nombre == "Nom" and con_imagen.img == ruta_png, "setup expone nombre e imagen en la tarjeta")

	var cat_cliente := _crear_item()
	cat_cliente.setup("Nom", "Desc", "https://ejemplo.com/cat1", "", "cliente")
	var cat_vacia := _crear_item()
	cat_vacia.setup("Nom", "Desc", "https://ejemplo.com/cat2", "", "")
	root.add_child(cat_cliente)
	root.add_child(cat_vacia)
	await process_frame
	_check(cat_cliente.get_node("%CategoriaLabel").text == "Cliente" and cat_cliente.categoria == "cliente", "la tarjeta muestra y guarda la categoría cliente")
	_check(cat_vacia.get_node("%CategoriaLabel").text == "Otro" and cat_vacia.categoria == "otro", "sin categoría la tarjeta normaliza a Otro")

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

	var invalida := _crear_item()
	invalida.setup("", "", "")
	root.add_child(invalida)
	await process_frame
	var emitida: Array = []
	invalida.verificacion_terminada.connect(func() -> void: emitida.append(true))
	invalida.verificar()
	_check(invalida.valido == false and invalida.estado == "invalido", "una URL vacía marca la tarjeta como inválida")
	_check(invalida.get_node("%EstadoLabel").text == "URL inválida", "la tarjeta inválida pinta URL inválida")
	_check(emitida.size() == 1, "verificar emite verificacion_terminada")

	IdiomaScript.cargar_traducciones()
	TranslationServer.set_locale("en")
	var i18n_item := _crear_item()
	i18n_item.setup("Nom", "Desc", "https://ejemplo.com/i18n")
	i18n_item.aplicar_estado(false, "No existe (404)", 404, 0)
	root.add_child(i18n_item)
	await process_frame
	_check(i18n_item.get_node("%EstadoLabel").text == "Does not exist (404)", "cambiado a en, el estado guardado en es se repinta traducido")
	_check(ListItemScript.formatear_mensaje("Conexión cerrada", 0) == "Connection closed", "formatear_mensaje re-traduce una frase guardada")
	TranslationServer.set_locale("es")

	_cerrar()


func _crear_item() -> Control:
	var item: Control = GRID_ITEM.instantiate()
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


func _cerrar() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BASE))
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


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