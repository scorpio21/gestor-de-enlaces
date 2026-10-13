extends RefCounted

const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
const SeleccionControllerScript := preload("res://scripts/seleccion_controller.gd")
const RedireccionesScript := preload("res://scripts/redirecciones.gd")

var _orden_columna: Callable = Callable()
var _filas_visibles: Callable = Callable()
var _entradas: Callable = Callable()
var _guardar_datos: Callable = Callable()
var _cargar_datos: Callable = Callable()
var _refrescar: Callable = Callable()
var _aplicar_filtro: Callable = Callable()
var _status: Callable = Callable()
var _seleccion_conservar: Callable = Callable()
var _fila_en_lista: Callable = Callable()
var _sugerir_etiquetas: Callable = Callable()
var _assets_base: Callable = Callable()
var _catalogo: Callable = Callable()
var _estado_store: Callable = Callable()
var _estados: Callable = Callable()
var _borrados: Callable = Callable()
var _dialogos: Callable = Callable()
var _progreso: Label = null
var _historial_ventana: Window = null
var _ventana_agregar: Node = null
var _dialogo_borrado: ConfirmationDialog = null
var _dialogo_reubicar: ConfirmationDialog = null
var _seleccion_al_clic: Callable = Callable()
var _recomprobar: Callable = Callable()


func _init(orden_columna: Callable, filas_visibles: Callable, entradas: Callable, guardar_datos: Callable, cargar_datos: Callable, refrescar: Callable, aplicar_filtro: Callable, status: Callable, seleccion_conservar: Callable, fila_en_lista: Callable, sugerir_etiquetas: Callable, assets_base: Callable, catalogo: Callable, estado_store: Callable, estados: Callable, borrados: Callable, dialogos: Callable, progreso: Label, historial_ventana: Window, ventana_agregar: Node, dialogo_borrado: ConfirmationDialog, dialogo_reubicar: ConfirmationDialog, seleccion_al_clic: Callable, recomprobar: Callable) -> void:
	_orden_columna = orden_columna
	_filas_visibles = filas_visibles
	_entradas = entradas
	_guardar_datos = guardar_datos
	_cargar_datos = cargar_datos
	_refrescar = refrescar
	_aplicar_filtro = aplicar_filtro
	_status = status
	_seleccion_conservar = seleccion_conservar
	_fila_en_lista = fila_en_lista
	_sugerir_etiquetas = sugerir_etiquetas
	_assets_base = assets_base
	_catalogo = catalogo
	_estado_store = estado_store
	_estados = estados
	_borrados = borrados
	_dialogos = dialogos
	_progreso = progreso
	_historial_ventana = historial_ventana
	_ventana_agregar = ventana_agregar
	_dialogo_borrado = dialogo_borrado
	_dialogo_reubicar = dialogo_reubicar
	_seleccion_al_clic = seleccion_al_clic
	_recomprobar = recomprobar


func conectar_fila(item: Button) -> void:
	item.seleccion_pedido.connect(_seleccion_al_clic.bind(item))
	item.eliminar_pedido.connect(eliminar_fila.bind(item))
	item.recomprobar_pedido.connect(_recomprobar.bind(item))
	item.copiar_pedido.connect(copiar_url.bind(item))
	item.editar_pedido.connect(editar_fila.bind(item))
	item.historial_pedido.connect(historial.bind(item))
	item.subir_pedido.connect(mover_fila.bind(item, -1))
	item.bajar_pedido.connect(mover_fila.bind(item, 1))
	item.menu_solicitado.connect(menu_fila.bind(item))
	item.actualizar_url_pedido.connect(actualizar_url.bind(item))


func menu_fila(item: Button) -> void:
	if String(_orden_columna.call()) != "":
		item.fijar_estado_reorden(false, false)
		return
	var visibles: Array = _filas_visibles.call()
	var idx := visibles.find(item)
	item.fijar_estado_reorden(idx > 0, idx >= 0 and idx < visibles.size() - 1)


func mover_fila(item: Button, delta: int) -> void:
	if String(_orden_columna.call()) != "":
		return
	var visibles: Array = _filas_visibles.call()
	var idx := visibles.find(item)
	if idx < 0:
		return
	var vecino_idx := idx + delta
	if vecino_idx < 0 or vecino_idx >= visibles.size():
		return
	var entradas: Array = _entradas.call()
	var i := _indice_entrada(str(item.url))
	var j := _indice_entrada(str(visibles[vecino_idx].url))
	if i < 0 or j < 0:
		return
	var tmp = entradas[i]
	entradas[i] = entradas[j]
	entradas[j] = tmp
	if not _guardar_datos.call():
		entradas[j] = entradas[i]
		entradas[i] = tmp
		_progreso.text = tr("No se pudo guardar el orden.")
		return
	_refrescar.call()


func historial(item: Button) -> void:
	if not is_instance_valid(item):
		return
	var clave := GestorCatalogoScript.clave_unica(str(item.url))
	_historial_ventana.abrir(_estado_store.call().historial_de(clave), str(item.url))


func eliminar_fila(item: Button) -> void:
	if not _fila_en_lista.call(item):
		return
	pedir_borrado([str(item.url)], str(item.get_node("%NombreLabel").text))


func pedir_borrado(urls: Array, etiqueta := "") -> void:
	var texto: String = _dialogos.call().pedir_borrado(urls, etiqueta)
	if texto.is_empty():
		return
	_dialogo_borrado.dialog_text = texto
	_dialogo_borrado.popup_centered()


func cancelar_borrado() -> void:
	_dialogos.call().cancelar_borrado()


func confirmar_borrado() -> void:
	var urls: Array = _dialogos.call().tomar_borrado()
	var borradas: Array = []
	for url in urls:
		if _borrar_entrada(str(url)):
			borradas.append(url)
	if borradas.is_empty():
		return
	for fila in _filas_visibles.call():
		if borradas.has(str(fila.url)):
			fila.queue_free()
	_seleccion_conservar.call()
	_progreso.text = SeleccionControllerScript.texto_borrados(borradas.size())
	_aplicar_filtro.call()
	_status.call()


func actualizar_url(item: Button) -> void:
	if _fila_en_lista.call(item):
		pedir_reubicar([str(item.url)])


func pedir_reubicar_lote(urls: Array) -> void:
	pedir_reubicar(urls)


func pedir_reubicar(urls: Array) -> void:
	var texto: String = _dialogos.call().pedir_reubicar(urls, _entradas.call(), _estados.call())
	if texto.is_empty():
		return
	_dialogo_reubicar.dialog_text = texto
	_dialogo_reubicar.popup_centered()


func cancelar_reubicar() -> void:
	_dialogos.call().cancelar_reubicar()


func confirmar_reubicar() -> void:
	var urls: Array = _dialogos.call().tomar_reubicar()
	var actualizadas := 0
	for url in urls:
		if _actualizar_url_entrada(str(url)):
			actualizadas += 1
	if actualizadas == 0:
		return
	_refrescar.call()
	_status.call()
	_progreso.text = RedireccionesScript.texto_actualizadas(actualizadas)


func copiar_url(url: String, item: Button) -> void:
	if not is_instance_valid(item):
		return
	DisplayServer.clipboard_set(url)
	_progreso.text = tr("URL copiada: %s") % url


func editar_fila(item: Button) -> void:
	if not is_instance_valid(item):
		return
	var datos: Dictionary = _buscar_entrada(str(item.url))
	if datos.is_empty():
		_progreso.text = tr("No se encontró el enlace.")
		return
	_ventana_agregar.abrir_edicion(datos, item.url, _sugerir_etiquetas.call())


func _indice_entrada(url: String) -> int:
	return _catalogo.call().indice_entrada(_entradas.call(), url)


func _buscar_entrada(url: String) -> Dictionary:
	return _catalogo.call().buscar_entrada(_entradas.call(), url)


func _borrar_captura_si_huerfana(ruta: String) -> void:
	_catalogo.call().borrar_captura_si_huerfana(_entradas.call(), ruta, _assets_base.call())


func _borrar_entrada(url: String) -> bool:
	var res: Dictionary = _catalogo.call().eliminar(_entradas.call(), url)
	if not res.get("ok", false):
		return false
	var clave := GestorCatalogoScript.clave_unica(url)
	var store = _estado_store.call()
	store.marcar_borrado(clave)
	store.borrar_estado(clave)
	_estados.call().erase(clave)
	_borrar_captura_si_huerfana(str(res.get("img", "")))
	return true


func _actualizar_url_entrada(url_original: String) -> bool:
	var estados: Dictionary = _estados.call()
	var url_nueva := RedireccionesScript.destino_de(estados, url_original)
	if url_nueva.is_empty() or url_nueva == url_original:
		return false
	var res: Dictionary = _catalogo.call().actualizar_url(_entradas.call(), estados, _borrados.call(), url_original, url_nueva)
	if not res.get("ok", false):
		_progreso.text = str(res.get("mensaje", ""))
		return false
	if not _guardar_datos.call():
		_cargar_datos.call()
		_refrescar.call()
		_progreso.text = tr("No se pudo guardar el enlace.")
		return false
	var store = _estado_store.call()
	var clave_vieja := GestorCatalogoScript.clave_unica(url_original)
	var clave_nueva := GestorCatalogoScript.clave_unica(url_nueva)
	store.renombrar(clave_vieja, clave_nueva)
	if estados.has(clave_nueva):
		var estado: Dictionary = estados[clave_nueva]
		estado["url_final"] = ""
	store.volcar()
	return true
