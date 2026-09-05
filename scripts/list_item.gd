extends Button

signal verificacion_terminada
signal eliminar_pedido
signal recomprobar_pedido

var mensaje: String = ""

const LinkCheckerScript := preload("res://scripts/link_checker.gd")

var url: String = ""
var estado: String = "pendiente"
var valido: Variant = null

var _checker: Node = null


func _ready() -> void:
	%BtnRecomprobar.pressed.connect(recomprobar_pedido.emit)
	%BtnEliminar.pressed.connect(eliminar_pedido.emit)
	mostrar_acciones(valido == false)


func setup(nombre: String, descripcion: String, enlace: String, imagen := "") -> void:
	url = enlace
	text = ""
	tooltip_text = enlace
	%NombreLabel.text = nombre
	%DescripcionLabel.text = descripcion
	_pintar_estado("Sin comprobar", Color(0.55, 0.55, 0.55, 1))
	if imagen != "" and FileAccess.file_exists(imagen):
		var img := Image.load_from_file(imagen)
		if img != null and not img.is_empty():
			%Imagen.texture = ImageTexture.create_from_image(img)


func aplicar_estado(ok: Variant, texto: String) -> void:
	valido = ok
	mensaje = texto
	if ok == true:
		estado = "ok"
		_pintar_estado(texto, Color(0.35, 0.85, 0.45, 1))
	elif ok == false:
		estado = "caido"
		_pintar_estado(texto, Color(0.95, 0.35, 0.35, 1))
	else:
		estado = "pendiente"
		_pintar_estado("Sin comprobar", Color(0.55, 0.55, 0.55, 1))
	mostrar_acciones(ok == false)


func mostrar_acciones(visible_acciones: bool) -> void:
	%Acciones.visible = visible_acciones


func verificar() -> void:
	if _checker != null:
		return

	if url.is_empty() or not (url.begins_with("http://") or url.begins_with("https://")):
		valido = false
		estado = "invalido"
		mensaje = "URL inválida"
		_pintar_estado("URL inválida", Color(0.95, 0.55, 0.2, 1))
		verificacion_terminada.emit()
		return

	estado = "comprobando"
	mostrar_acciones(false)
	_pintar_estado("Comprobando…", Color(0.85, 0.75, 0.25, 1))
	_checker = LinkCheckerScript.new()
	add_child(_checker)
	_checker.terminado.connect(_on_check_terminado)
	_checker.comprobar(url)


func _on_check_terminado(ok: bool, texto: String) -> void:
	_checker = null
	valido = ok
	estado = "ok" if ok else "caido"
	mensaje = texto
	_pintar_estado(texto, Color(0.35, 0.85, 0.45, 1) if ok else Color(0.95, 0.35, 0.35, 1))
	mostrar_acciones(not ok)
	verificacion_terminada.emit()


func _pintar_estado(texto: String, color: Color) -> void:
	%EstadoLabel.text = texto
	%EstadoLabel.add_theme_color_override("font_color", color)
	%Indicador.color = color


func _pressed() -> void:
	if url.is_empty():
		return
	OS.shell_open(url)
