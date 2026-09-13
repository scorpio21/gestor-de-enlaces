extends SceneTree

const DIALOGO := preload("res://scenes/AgregarEnlace.tscn")

var _fallos := 0
var emitido: Dictionary = {}
var url_original_emitida := ""
var lote: Array = []


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	var dialogo := DIALOGO.instantiate()
	root.add_child(dialogo)
	await process_frame

	dialogo.guardado.connect(func(d: Dictionary) -> void: emitido = d)
	dialogo.editado.connect(func(d: Dictionary, uo: String) -> void:
		emitido = d
		url_original_emitida = uo
	)
	dialogo.lote_guardado.connect(func(urls: Array) -> void: lote = urls)

	dialogo.abrir()
	emitido = {}
	dialogo.get_node("%Nombre").text = "Mi servidor"
	dialogo.get_node("%Descripcion").text = "Con códigos"
	dialogo.get_node("%Url").text = "https://servidor.com"
	dialogo.get_node("%BotonGuardar").pressed.emit()
	_check(emitido.get("url") == "https://servidor.com" and emitido.get("nombre") == "Mi servidor" and emitido.get("desc") == "Con códigos" and emitido.get("img") == "", "el alta individual emite guardado con los campos")
	_check(not dialogo.visible, "el diálogo se oculta tras guardar")

	dialogo.abrir()
	emitido = {}
	dialogo.get_node("%Nombre").text = "Sin url"
	dialogo.get_node("%Url").text = ""
	dialogo.get_node("%BotonGuardar").pressed.emit()
	_check(emitido.is_empty(), "URL vacía no emite guardado")
	_check(dialogo.get_node("%Error").text != "", "URL vacía muestra error en el diálogo")
	_check(dialogo.visible, "con error el diálogo permanece abierto")

	dialogo.abrir()
	emitido = {}
	dialogo.get_node("%Nombre").text = "Mal"
	dialogo.get_node("%Url").text = "no-es-http"
	dialogo.get_node("%BotonGuardar").pressed.emit()
	_check(emitido.is_empty(), "URL no http(s) no emite guardado")

	dialogo.abrir()
	dialogo.get_node("%Modo").select(1)
	dialogo.get_node("%Modo").item_selected.emit(1)
	_check(not dialogo.get_node("%Nombre").visible, "en modo Varias se oculta el formulario")
	_check(dialogo.get_node("%CajaVarias").visible, "en modo Varias se muestra la caja de URLs")
	lote = []
	dialogo.get_node("%ListaUrls").text = "https://a.com\n\n  \nhttps://b.com"
	dialogo.get_node("%BotonGuardar").pressed.emit()
	_check(lote == ["https://a.com", "https://b.com"], "modo Varias emite las URLs no vacías y sin espacios")
	_check(not dialogo.visible, "el diálogo se oculta tras guardar el lote")

	dialogo.abrir()
	dialogo.get_node("%Modo").select(1)
	dialogo.get_node("%Modo").item_selected.emit(1)
	lote = []
	dialogo.get_node("%ListaUrls").text = "   \n "
	dialogo.get_node("%BotonGuardar").pressed.emit()
	_check(lote.is_empty(), "lote sin URL no emite lote_guardado")
	_check(dialogo.get_node("%Error").text != "", "lote vacío muestra error")

	dialogo.abrir_edicion({"nombre": "A", "desc": "D", "url": "https://a.com", "img": ""}, "https://a.com")
	emitido = {}
	url_original_emitida = ""
	_check(dialogo.get_node("%Nombre").text == "A" and dialogo.get_node("%Url").text == "https://a.com", "abrir_edicion precarga los campos")
	_check(dialogo.get_node("%Nombre").visible and not dialogo.get_node("%CajaVarias").visible, "abrir_edicion tras modo Varias muestra el formulario")
	_check(not dialogo.get_node("%Modo").visible, "en edición se oculta el selector de modo")
	dialogo.get_node("%Url").text = "https://a2.com"
	dialogo.get_node("%BotonGuardar").pressed.emit()
	_check(not dialogo.visible, "el diálogo se cierra tras editar")
	_check(emitido.get("url") == "https://a2.com" and url_original_emitida == "https://a.com", "editar emite editado con los datos y la URL original")
	_check(emitido.get("nombre") == "A", "editar conserva los campos no modificados")
	dialogo.abrir_edicion({"nombre": "S", "desc": "D", "url": "https://s.com", "img": ""}, "https://s.com")
	emitido = {}
	url_original_emitida = ""
	var fuente_rara := ProjectSettings.globalize_path("res://__fuente_inexistente__.png")
	dialogo._imagen_ruta = fuente_rara
	dialogo.get_node("%BotonGuardar").pressed.emit()
	_check(emitido.get("img") == "" and emitido.get("img_pendiente") == fuente_rara, "editar con imagen nueva emite img vacío e img_pendiente")

	dialogo.abrir()
	emitido = {}
	dialogo.get_node("%Nombre").text = "Con cat"
	dialogo.get_node("%Url").text = "https://cat.test"
	dialogo.get_node("%BotonGuardar").pressed.emit()
	_check(emitido.get("cat") == "otro", "alta individual fija cat otro por defecto")

	dialogo.abrir()
	emitido = {}
	dialogo.get_node("%Categoria").select(1)
	dialogo.get_node("%Nombre").text = "Cliente"
	dialogo.get_node("%Url").text = "https://client.test"
	dialogo.get_node("%BotonGuardar").pressed.emit()
	_check(emitido.get("cat") == "cliente", "alta individual usa la categoría elegida")

	dialogo.abrir()
	dialogo.get_node("%Modo").select(1)
	dialogo.get_node("%Modo").item_selected.emit(1)
	_check(not dialogo.get_node("%Categoria").visible and not dialogo.get_node("%EtiquetaCategoria").visible, "en modo Varias se oculta la categoría")

	dialogo.abrir_edicion({"nombre": "Srv", "desc": "", "url": "https://srv.test", "img": "", "cat": "servidor"}, "https://srv.test")
	_check(dialogo.get_node("%Categoria").selected == 2, "edición selecciona la categoría del enlace")
	emitido = {}
	url_original_emitida = ""
	dialogo.get_node("%BotonGuardar").pressed.emit()
	_check(emitido.get("cat") == "servidor", "editar conserva la categoría")

	dialogo.abrir_edicion({"nombre": "Sin", "desc": "", "url": "https://sin.test", "img": ""}, "https://sin.test")
	_check(dialogo.get_node("%Categoria").selected == 0, "edición sin cat selecciona otro")

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