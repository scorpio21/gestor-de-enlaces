extends SceneTree

const EdicionControllerScript := preload("res://scripts/edicion_controller.gd")
const SeleccionControllerScript := preload("res://scripts/seleccion_controller.gd")
const RedireccionesScript := preload("res://scripts/redirecciones.gd")
const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
const LIST_ITEM_SCENE := preload("res://scenes/ListItem.tscn")


class _Catalogo extends RefCounted:
	var eliminados: Array = []
	var actualizados: Array = []
	var capturas: Array = []
	var eliminar_res := {"ok": true, "img": "captura.png"}
	var actualizar_res := {"ok": true}


	func indice_entrada(entradas: Array, url: String) -> int:
		for i in range(entradas.size()):
			if typeof(entradas[i]) == TYPE_DICTIONARY and str(entradas[i].get("url", "")) == url:
				return i
		return -1


	func buscar_entrada(entradas: Array, url: String) -> Dictionary:
		var idx := indice_entrada(entradas, url)
		return entradas[idx] if idx >= 0 else {}


	func borrar_captura_si_huerfana(_entradas: Array, ruta: String, _assets: String) -> void:
		capturas.append(ruta)


	func eliminar(_entradas: Array, url: String) -> Dictionary:
		eliminados.append(url)
		return eliminar_res


	func actualizar_url(_entradas: Array, _estados: Dictionary, _borrados: Array, vieja: String, nueva: String) -> Dictionary:
		actualizados.append([vieja, nueva])
		return actualizar_res


class _Estados extends RefCounted:
	var historial := {}
	var marcados: Array = []
	var borrados_estado: Array = []
	var renombrados: Array = []
	var volcados := 0


	func historial_de(clave: String) -> Array:
		return historial.get(clave, [])


	func marcar_borrado(clave: String) -> void:
		marcados.append(clave)


	func borrar_estado(clave: String) -> void:
		borrados_estado.append(clave)


	func renombrar(a: String, b: String) -> void:
		renombrados.append([a, b])


	func volcar() -> void:
		volcados += 1


class _Dialogos extends RefCounted:
	var texto := ""
	var borrado_pedido: Array = []
	var reubicar_pedido: Array = []
	var tomado: Array = []
	var cancelado_borrado := false
	var cancelado_reubicar := false


	func pedir_borrado(urls: Array, _etiqueta := "") -> String:
		borrado_pedido.append([urls, _etiqueta])
		return texto


	func cancelar_borrado() -> void:
		cancelado_borrado = true


	func tomar_borrado() -> Array:
		return tomado


	func pedir_reubicar(urls: Array, _entradas: Array, _estados: Dictionary) -> String:
		reubicar_pedido.append(urls)
		return texto


	func cancelar_reubicar() -> void:
		cancelado_reubicar = true


	func tomar_reubicar() -> Array:
		return tomado


class _Historial extends Window:
	var ultimo: Array = []


	func abrir(entradas: Array, url: String) -> void:
		ultimo = [entradas, url]


class _Agregar extends Node:
	var ultimo: Array = []


	func abrir_edicion(datos: Dictionary, url: String, etiquetas: Array) -> void:
		ultimo = [datos, url, etiquetas]


var _fallos := 0
var _progreso: Label = null
var _historial: _Historial = null
var _agregar: _Agregar = null
var _dialogo_borrado: ConfirmationDialog = null
var _dialogo_reubicar: ConfirmationDialog = null
var _cont: VBoxContainer = null
var _catalogo: _Catalogo = null
var _estado_store: _Estados = null
var _dialogos: _Dialogos = null
var _entradas: Array = []
var _estados := {}
var _borrados: Array = []
var _visibles: Array = []
var _orden := ""
var _fila_en_lista_ok := true
var _guardar_ok := true
var _clic: Array = []
var _recomprobados: Array = []
var _conservadas := 0
var _refrescos := 0
var _filtros := 0
var _status_n := 0
var _cargados := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	_progreso = Label.new()
	_historial = _Historial.new()
	_agregar = _Agregar.new()
	_dialogo_borrado = ConfirmationDialog.new()
	_dialogo_reubicar = ConfirmationDialog.new()
	_cont = VBoxContainer.new()
	root.add_child(_progreso)
	root.add_child(_historial)
	root.add_child(_agregar)
	root.add_child(_dialogo_borrado)
	root.add_child(_dialogo_reubicar)
	root.add_child(_cont)
	_catalogo = _Catalogo.new()
	_estado_store = _Estados.new()
	_dialogos = _Dialogos.new()
	_dialogo_borrado.hide()
	_dialogo_reubicar.hide()
	await process_frame

	_a_conectar()
	_b_menu_mover()
	_c_eliminar()
	_d_borrado()
	_e_reubicar()
	_f_copiar_editar_historial()
	_cerrar()


func _ctrl() -> RefCounted:
	return EdicionControllerScript.new(
		func() -> String: return _orden,
		func() -> Array: return _visibles,
		func() -> Array: return _entradas,
		func() -> bool: return _guardar_ok,
		func() -> void: _cargados += 1,
		func() -> void: _refrescos += 1,
		func() -> void: _filtros += 1,
		func() -> void: _status_n += 1,
		func() -> void: _conservadas += 1,
		func(_item) -> bool: return _fila_en_lista_ok,
		func() -> Array: return ["tag1"],
		func() -> String: return "/tmp/assets",
		func() -> RefCounted: return _catalogo,
		func() -> RefCounted: return _estado_store,
		func() -> Dictionary: return _estados,
		func() -> Array: return _borrados,
		func() -> RefCounted: return _dialogos,
		_progreso,
		_historial,
		_agregar,
		_dialogo_borrado,
		_dialogo_reubicar,
		func(url: String, ctrl: bool, rango: bool, item: Button) -> void: _clic.append([url, ctrl, rango, item]),
		func(item: Button) -> void: _recomprobados.append(item)
	)


func _fila(url: String, nombre := "Nombre") -> Button:
	var item: Button = LIST_ITEM_SCENE.instantiate()
	item.setup(nombre, "", url, "")
	_cont.add_child(item)
	return item


func _entradas_de(items: Array) -> Array:
	var lista: Array = []
	for item in items:
		lista.append({"nombre": item.get_node("%NombreLabel").text, "desc": "", "url": str(item.url), "img": ""})
	return lista


func _a_conectar() -> void:
	var a := _fila("https://a.test")
	var b := _fila("https://b.test")
	var c := _fila("https://c.test")
	_visibles = [a, b, c]
	_entradas = _entradas_de([a, b, c])
	var ctrl := _ctrl()
	ctrl.conectar_fila(a)
	ctrl.conectar_fila(b)
	ctrl.conectar_fila(c)
	a.seleccion_pedido.emit("https://a.test", true, false)
	_check(_clic.size() == 1 and _clic[0][0] == "https://a.test" and _clic[0][3] == a, "seleccion_pedido llega al manejador de seleccion")
	a.recomprobar_pedido.emit()
	_check(_recomprobados.size() == 1 and _recomprobados[0] == a, "recomprobar_pedido llega al controlador de escaneo")
	b.subir_pedido.emit()
	_check(str(_entradas[0]["url"]) == "https://b.test", "subir_pedido mueve la fila hacia arriba")
	_check(_refrescos == 1, "y refresca la lista")
	ctrl.menu_fila(a)
	var menu: PopupMenu = a.get_node("%MenuContexto")
	_check(menu.is_item_disabled(menu.get_item_index(5)), "menu_solicitado en la primera fila deshabilita Subir")
	_check(not menu.is_item_disabled(menu.get_item_index(6)), "y deja Bajar habilitada")


func _b_menu_mover() -> void:
	var a := _fila("https://a.test")
	var b := _fila("https://b.test")
	var c := _fila("https://c.test")
	_visibles = [a, b, c]
	_entradas = _entradas_de([a, b, c])
	var ctrl := _ctrl()
	ctrl.menu_fila(c)
	var menu: PopupMenu = c.get_node("%MenuContexto")
	_check(not menu.is_item_disabled(menu.get_item_index(5)), "la ultima fila deja Subir habilitada")
	_check(menu.is_item_disabled(menu.get_item_index(6)), "y deshabilita Bajar")

	_orden = "estado"
	ctrl.menu_fila(b)
	var menu_b: PopupMenu = b.get_node("%MenuContexto")
	_check(menu_b.is_item_disabled(menu_b.get_item_index(5)) and menu_b.is_item_disabled(menu_b.get_item_index(6)), "con columna activa el menu deshabilita el reorden")
	var antes := _entradas_de([a, b, c])
	ctrl.mover_fila(b, -1)
	_check(_entradas == antes, "con columna activa mover_fila no modifica _entradas")
	_orden = ""

	_refrescos = 0
	ctrl.mover_fila(c, -1)
	_check(str(_entradas[1]["url"]) == "https://c.test", "con la lista sin ordenar mover_fila intercambia")
	_check(_refrescos == 1, "y refresca")

	_entradas = _entradas_de([a, b, c])
	_guardar_ok = false
	ctrl.mover_fila(c, -1)
	_check(str(_entradas[0]["url"]) == "https://a.test" and str(_entradas[2]["url"]) == "https://c.test", "si no se guarda el orden se revierte")
	_check(_progreso.text == tr("No se pudo guardar el orden."), "y se avisa")
	_guardar_ok = true


func _c_eliminar() -> void:
	var a := _fila("https://a.test", "Enlace A")
	var ctrl := _ctrl()
	_dialogos.borrado_pedido = []
	_dialogos.texto = ""
	_fila_en_lista_ok = false
	ctrl.eliminar_fila(a)
	_check(_dialogos.borrado_pedido.is_empty(), "eliminar_fila ignora filas que no estan en la lista")
	_fila_en_lista_ok = true
	_dialogos.texto = "¿Borrar?"
	ctrl.eliminar_fila(a)
	_check(_dialogos.borrado_pedido.size() == 1 and _dialogos.borrado_pedido[0][0][0] == "https://a.test", "eliminar_fila pide el borrado de esa url")
	_check(_dialogos.borrado_pedido[0][1] == "Enlace A", "con el nombre de la fila como etiqueta")
	_check(_dialogo_borrado.dialog_text == "¿Borrar?", "y el dialogo recibe el texto")


func _d_borrado() -> void:
	var ctrl := _ctrl()
	_dialogo_borrado.hide()
	_dialogos.texto = ""
	ctrl.pedir_borrado(["https://x.test"])
	_check(not _dialogo_borrado.visible, "sin texto de dialogo no se abre la confirmacion")
	ctrl.cancelar_borrado()
	_check(_dialogos.cancelado_borrado, "cancelar_borrado delega en los dialogos")

	_visibles = []
	_catalogo.eliminados = []
	_estado_store.marcados = []
	_estado_store.borrados_estado = []
	_catalogo.capturas = []
	_estados = {"a.test": {"codigo": 404}}
	_conservadas = 0
	_filtros = 0
	_status_n = 0
	_dialogos.tomado = []
	ctrl.confirmar_borrado()
	_check(_catalogo.eliminados.is_empty(), "confirmar sin urls pendientes no borra nada")

	_dialogos.tomado = ["https://a.test"]
	ctrl.confirmar_borrado()
	_check(_catalogo.eliminados == ["https://a.test"], "confirmar borra la url pendiente")
	_check(_estado_store.marcados == ["a.test"] and _estado_store.borrados_estado == ["a.test"], "y limpia su estado por clave sin esquema")
	_check(not _estados.has("a.test"), "y lo saca de _estados")
	_check(_catalogo.capturas == ["captura.png"], "y borra la captura huerfana")
	_check(_conservadas == 1 and _filtros == 1 and _status_n == 1, "conserva la seleccion y refresca filtros y contadores")
	_check(_progreso.text == SeleccionControllerScript.texto_borrados(1), "y resume el borrado en la barra")


func _e_reubicar() -> void:
	var ctrl := _ctrl()
	_dialogo_reubicar.hide()
	_dialogos.texto = ""
	ctrl.pedir_reubicar(["https://viejo.test/x"])
	_check(not _dialogo_reubicar.visible, "sin texto no se abre la confirmacion de reubicacion")
	ctrl.cancelar_reubicar()
	_check(_dialogos.cancelado_reubicar, "cancelar_reubicar delega en los dialogos")

	_dialogos.tomado = ["https://viejo.test/x"]
	_estados = {"viejo.test/x": {"url_final": "https://nuevo.test/y"}}
	_catalogo.actualizados = []
	_estado_store.renombrados = []
	_estado_store.volcados = 0
	_refrescos = 0
	_status_n = 0
	_guardar_ok = true
	ctrl.confirmar_reubicar()
	_check(_catalogo.actualizados == [["https://viejo.test/x", "https://nuevo.test/y"]], "confirmar_reubicar actualiza la url en el catalogo")
	_check(_estado_store.renombrados == [["viejo.test/x", "nuevo.test/y"]], "y renombra el estado")
	_check(_estado_store.volcados == 1, "y vuelca")
	_check(_refrescos == 1 and _status_n == 1, "y refresca la lista")
	_check(_progreso.text == RedireccionesScript.texto_actualizadas(1), "y resume la reubicacion")

	_dialogos.tomado = ["https://viejo.test/x"]
	_catalogo.actualizar_res = {"ok": false, "mensaje": "no se pudo"}
	_estado_store.renombrados = []
	ctrl.confirmar_reubicar()
	_check(_estado_store.renombrados.is_empty(), "si el catalogo rechaza no se renombra el estado")
	_check(_progreso.text == "no se pudo", "y se muestra el mensaje del catalogo")
	_catalogo.actualizar_res = {"ok": true}

	_dialogos.tomado = ["https://sin.test/destino"]
	_refrescos = 0
	ctrl.confirmar_reubicar()
	_check(_refrescos == 0, "una url sin destino no se actualiza")


func _f_copiar_editar_historial() -> void:
	var ctrl := _ctrl()
	var a := _fila("https://a.test")
	_progreso.text = ""
	ctrl.copiar_url("https://a.test", null)
	_check(_progreso.text.is_empty(), "copiar_url ignora items invalidos")
	ctrl.copiar_url("https://a.test", a)
	_check(_progreso.text == tr("URL copiada: %s") % "https://a.test", "copiar_url avisa por la barra")

	_entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""}]
	_agregar.ultimo = []
	ctrl.editar_fila(a)
	_check(_agregar.ultimo.size() == 3 and _agregar.ultimo[1] == "https://a.test", "editar_fila abre la ventana con los datos")
	_check(_agregar.ultimo[2] == ["tag1"], "y con las etiquetas sugeridas")

	var z := _fila("https://z.test")
	_agregar.ultimo = []
	_progreso.text = ""
	ctrl.editar_fila(z)
	_check(_agregar.ultimo.is_empty(), "editar_fila de una url ausente no abre nada")
	_check(_progreso.text == tr("No se encontró el enlace."), "y avisa por la barra")

	_estado_store.historial = {"a.test": [{"fecha": 1}]}
	_historial.ultimo = []
	ctrl.historial(a)
	_check(_historial.ultimo.size() == 2 and _historial.ultimo[1] == "https://a.test", "historial abre el dialogo con la url")

	_estado_store.historial = {"a.test": [{"fecha": 2}]}
	_historial.ultimo = []
	ctrl.historial(a)
	_check(_historial.ultimo[0][0]["fecha"] == 2, "historial pide el estado con la clave sin esquema")
	_check(GestorCatalogoScript.clave_unica("https://a.test") == "a.test", "la clave unica no lleva esquema")


func _check(cond: bool, msg: String) -> void:
	if cond:
		return
	_fallos += 1
	print("FALLO: " + msg)


func _cerrar() -> void:
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
	else:
		print("%d FALLOS" % _fallos)
		quit(1)
