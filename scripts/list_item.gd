extends Button

signal verificacion_terminada
signal eliminar_pedido
signal recomprobar_pedido
signal copiar_pedido(url: String)
signal editar_pedido
signal historial_pedido
signal subir_pedido
signal bajar_pedido
signal menu_solicitado

var mensaje: String = ""
var codigo := 0
var fecha := 0

const LinkCheckerScript := preload("res://scripts/link_checker.gd")
const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
const TemaStoreScript := preload("res://scripts/tema_store.gd")

var url: String = ""
var nombre := ""
var img := ""
var estado: String = "pendiente"
var valido: Variant = null
var categoria: String = "otro"
var tags: Array = []

var _checker: Node = null
var _timeout := 10.0


func _ready() -> void:
	var menu: PopupMenu = %MenuContexto
	menu.add_item(tr("Editar…"), 0)
	menu.add_separator()
	menu.add_item(tr("Subir"), 5)
	menu.add_item(tr("Bajar"), 6)
	menu.add_separator()
	menu.add_item(tr("Volver a comprobar"), 1)
	menu.add_item(tr("Copiar URL"), 2)
	menu.add_item(tr("Historial…"), 3)
	menu.add_item(tr("Eliminar"), 4)
	menu.id_pressed.connect(_on_menu)
	gui_input.connect(_on_gui_input)


func setup(nombre: String, descripcion: String, enlace: String, imagen := "", categoria := "") -> void:
	self.nombre = nombre
	self.img = imagen
	url = enlace
	text = ""
	_actualizar_tooltip()
	%NombreLabel.text = nombre
	%DescripcionLabel.text = descripcion
	%FechaLabel.text = tr("Sin comprobar")
	_pintar_estado(tr("Sin comprobar"), TemaStoreScript.color_estado(null))
	self.categoria = GestorCatalogoScript.normalizar_categoria(categoria)
	%CategoriaLabel.text = GestorCatalogoScript.new().categoria_display(self.categoria)
	if imagen != "" and FileAccess.file_exists(imagen):
		var img := Image.load_from_file(imagen)
		if img != null and not img.is_empty():
			%Imagen.texture = ImageTexture.create_from_image(img)


func aplicar_estado(ok: Variant, texto: String, codigo_nuevo := 0, fecha_nueva := 0) -> void:
	valido = ok
	mensaje = texto
	codigo = codigo_nuevo
	fecha = fecha_nueva
	_pintar_fecha()
	if ok == true:
		estado = "ok"
		_pintar_estado(formatear_mensaje(texto, codigo), TemaStoreScript.color_estado(true))
	elif ok == false:
		estado = "caido"
		_pintar_estado(formatear_mensaje(texto, codigo), TemaStoreScript.color_estado(false))
	else:
		estado = "pendiente"
		_pintar_estado(tr("Sin comprobar"), TemaStoreScript.color_estado(null))
	_actualizar_tooltip()


static func formatear_fecha(unix: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix)
	return "%02d/%02d/%04d %02d:%02d" % [d.day, d.month, d.year, d.hour, d.minute]


static func formatear_mensaje(mensaje: String, codigo: int) -> String:
	var clave := _clave_de_mensaje(mensaje, codigo)
	if clave.is_empty():
		return TranslationServer.translate(mensaje)
	if clave.count("%d") == 1 and clave.count("%") == 1:
		return TranslationServer.translate(clave) % codigo
	return TranslationServer.translate(clave)


static var _mapas_render := {}
static var _cache_dinamica := {}


static func _clave_de_mensaje(mensaje: String, codigo: int) -> String:
	if TranslationServer.get_loaded_locales().is_empty():
		return ""
	for locale in TranslationServer.get_loaded_locales():
		var mapa := _mapa_render(locale)
		if mapa.has(mensaje):
			return mapa[mensaje]
	return _clave_dinamica(mensaje, codigo)


static func _mapa_render(locale: String) -> Dictionary:
	if _mapas_render.has(locale):
		return _mapas_render[locale]
	var mapa := {}
	var traduccion: Translation = TranslationServer.get_translation_object(locale)
	if traduccion != null:
		for clave in traduccion.get_message_list():
			var valor := traduccion.get_message(clave)
			if _es_dinamica(clave, valor):
				continue
			if not mapa.has(clave):
				mapa[clave] = clave
			if not valor.is_empty() and valor != clave and not mapa.has(valor):
				mapa[valor] = clave
	_mapas_render[locale] = mapa
	return mapa


static func _clave_dinamica(mensaje: String, codigo: int) -> String:
	var t := mensaje + "\n" + str(codigo)
	if _cache_dinamica.has(t):
		return _cache_dinamica[t]
	var res := ""
	for locale in TranslationServer.get_loaded_locales():
		var traduccion: Translation = TranslationServer.get_translation_object(locale)
		if traduccion == null:
			continue
		for clave in traduccion.get_message_list():
			var valor := traduccion.get_message(clave)
			if not _es_dinamica(clave, valor):
				continue
			if (clave % codigo) == mensaje or (valor % codigo) == mensaje:
				res = clave
				break
		if not res.is_empty():
			break
	_cache_dinamica[t] = res
	return res


static func _es_dinamica(clave: String, valor: String) -> bool:
	return clave.count("%d") == 1 and clave.count("%") == 1 and valor.count("%d") == 1 and valor.count("%") == 1


func _actualizar_tooltip() -> void:
	if valido == null:
		tooltip_text = url + "\n" + tr("Sin comprobar")
		return
	var lineas := PackedStringArray([url])
	lineas.append(tr("Código: %s") % ("—" if codigo == 0 else str(codigo)))
	if fecha > 0:
		lineas.append(tr("Comprobado: %s") % formatear_fecha(fecha))
	lineas.append(formatear_mensaje(mensaje, codigo))
	tooltip_text = "\n".join(lineas)


func configurar_timeout(segundos: float) -> void:
	_timeout = segundos


func fijar_estado_reorden(arriba: bool, abajo: bool) -> void:
	var menu: PopupMenu = %MenuContexto
	menu.set_item_disabled(menu.get_item_index(5), not arriba)
	menu.set_item_disabled(menu.get_item_index(6), not abajo)


func verificar() -> void:
	if _checker != null:
		return

	if url.is_empty() or not (url.begins_with("http://") or url.begins_with("https://")):
		valido = false
		estado = "invalido"
		mensaje = tr("URL inválida")
		_pintar_estado(tr("URL inválida"), Color(0.95, 0.55, 0.2, 1))
		_actualizar_tooltip()
		verificacion_terminada.emit()
		return

	estado = "comprobando"
	_pintar_estado(tr("Comprobando…"), Color(0.85, 0.75, 0.25, 1))
	_checker = LinkCheckerScript.new()
	add_child(_checker)
	_checker.terminado.connect(_on_check_terminado)
	_checker.timeout_s = _timeout
	_checker.comprobar(url)


func _on_check_terminado(ok: bool, texto: String) -> void:
	codigo = _checker.codigo
	fecha = int(Time.get_unix_time_from_system())
	_pintar_fecha()
	_checker = null
	valido = ok
	estado = "ok" if ok else "caido"
	mensaje = texto
	_pintar_estado(texto, Color(0.35, 0.85, 0.45, 1) if ok else Color(0.95, 0.35, 0.35, 1))
	_actualizar_tooltip()
	verificacion_terminada.emit()


func _pintar_estado(texto: String, color: Color) -> void:
	%EstadoLabel.text = texto
	%EstadoLabel.add_theme_color_override("font_color", color)
	%Indicador.color = color


func _pressed() -> void:
	if url.is_empty():
		return
	OS.shell_open(url)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		menu_solicitado.emit()
		%MenuContexto.popup(Rect2i(Vector2i(DisplayServer.mouse_get_position()), Vector2i.ZERO))


func _on_menu(id: int) -> void:
	match id:
		0:
			editar_pedido.emit()
		1:
			recomprobar_pedido.emit()
		2:
			copiar_pedido.emit(url)
		3:
			historial_pedido.emit()
		4:
			eliminar_pedido.emit()
		5:
			subir_pedido.emit()
		6:
			bajar_pedido.emit()


func _pintar_fecha() -> void:
	if fecha > 0:
		%FechaLabel.text = formatear_fecha(fecha)
	else:
		%FechaLabel.text = tr("Sin comprobar")