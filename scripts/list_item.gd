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
var estado: String = "pendiente"
var valido: Variant = null
var categoria: String = "otro"

var _checker: Node = null
var _timeout := 10.0


func _ready() -> void:
	var menu: PopupMenu = %MenuContexto
	menu.add_item("Editar…", 0)
	menu.add_separator()
	menu.add_item("Subir", 5)
	menu.add_item("Bajar", 6)
	menu.add_separator()
	menu.add_item("Volver a comprobar", 1)
	menu.add_item("Copiar URL", 2)
	menu.add_item("Historial…", 3)
	menu.add_item("Eliminar", 4)
	menu.id_pressed.connect(_on_menu)
	gui_input.connect(_on_gui_input)


func setup(nombre: String, descripcion: String, enlace: String, imagen := "", categoria := "") -> void:
	url = enlace
	text = ""
	_actualizar_tooltip()
	%NombreLabel.text = nombre
	%DescripcionLabel.text = descripcion
	%FechaLabel.text = "Sin comprobar"
	_pintar_estado("Sin comprobar", TemaStoreScript.color_estado(null))
	self.categoria = GestorCatalogoScript.normalizar_categoria(categoria)
	%CategoriaLabel.text = GestorCatalogoScript.categoria_display(self.categoria)
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
		_pintar_estado(texto, TemaStoreScript.color_estado(true))
	elif ok == false:
		estado = "caido"
		_pintar_estado(texto, TemaStoreScript.color_estado(false))
	else:
		estado = "pendiente"
		_pintar_estado("Sin comprobar", TemaStoreScript.color_estado(null))
	_actualizar_tooltip()


static func formatear_fecha(unix: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix)
	return "%02d/%02d/%04d %02d:%02d" % [d.day, d.month, d.year, d.hour, d.minute]


func _actualizar_tooltip() -> void:
	if valido == null:
		tooltip_text = url + "\nSin comprobar"
		return
	var lineas := PackedStringArray([url])
	lineas.append("Código: %s" % ("—" if codigo == 0 else str(codigo)))
	if fecha > 0:
		lineas.append("Comprobado: %s" % formatear_fecha(fecha))
	lineas.append(mensaje)
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
		mensaje = "URL inválida"
		_pintar_estado("URL inválida", Color(0.95, 0.55, 0.2, 1))
		_actualizar_tooltip()
		verificacion_terminada.emit()
		return

	estado = "comprobando"
	_pintar_estado("Comprobando…", Color(0.85, 0.75, 0.25, 1))
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
		%MenuContexto.popup(Rect2i(Vector2i(event.global_position), Vector2i.ZERO))


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
		%FechaLabel.text = "Sin comprobar"