extends SceneTree

const LIST_ITEM := preload("res://scenes/ListItem.tscn")
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
	_check(_acciones_visibles(caido), "restaurar enlace caído muestra los botones de acción")
	_check(not _acciones_visibles(valido), "restaurar enlace válido oculta los botones de acción")
	_check(not _acciones_visibles(fresco), "enlace sin estado oculta los botones de acción")

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