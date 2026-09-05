extends Button

signal verificacion_terminada

const LinkCheckerScript := preload("res://scripts/link_checker.gd")

var url: String = ""
var estado: String = "pendiente"
var valido: Variant = null

var _checker: Node = null


func setup(nombre: String, descripcion: String, enlace: String) -> void:
	url = enlace
	text = ""
	tooltip_text = enlace
	%NombreLabel.text = nombre
	%DescripcionLabel.text = descripcion
	_pintar_estado("Sin comprobar", Color(0.55, 0.55, 0.55, 1))


func verificar() -> void:
	if _checker != null:
		return

	if url.is_empty() or not (url.begins_with("http://") or url.begins_with("https://")):
		valido = false
		estado = "invalido"
		_pintar_estado("URL inválida", Color(0.95, 0.55, 0.2, 1))
		verificacion_terminada.emit()
		return

	estado = "comprobando"
	_pintar_estado("Comprobando…", Color(0.85, 0.75, 0.25, 1))
	_checker = LinkCheckerScript.new()
	add_child(_checker)
	_checker.terminado.connect(_on_check_terminado)
	_checker.comprobar(url)


func _on_check_terminado(ok: bool, mensaje: String) -> void:
	_checker = null
	valido = ok
	estado = "ok" if ok else "caido"
	var color := Color(0.35, 0.85, 0.45, 1) if ok else Color(0.95, 0.35, 0.35, 1)
	_pintar_estado(mensaje, color)
	verificacion_terminada.emit()


func _pintar_estado(texto: String, color: Color) -> void:
	%EstadoLabel.text = texto
	%EstadoLabel.add_theme_color_override("font_color", color)
	%Indicador.color = color


func _pressed() -> void:
	if url.is_empty():
		return
	OS.shell_open(url)
