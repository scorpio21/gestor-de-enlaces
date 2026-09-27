extends Control

const TemaStoreScript := preload("res://scripts/tema_store.gd")

const MARGEN_IZQ := 34.0
const MARGEN_DER := 8.0
const MARGEN_INF := 6.0
const MARGEN_HOJA := 18.0
const LINEAS_REJILLA := 4
const SEPARACION := 3.0
const FUENTE_EJE := 10

var serie: Array = []
var _indice := -1
var _globo: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_globo = Label.new()
	_globo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_globo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_globo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_globo.add_theme_font_size_override("font_size", 11)
	_globo.visible = false
	add_child(_globo)
	gui_input.connect(_on_gui_input)
	mouse_exited.connect(_on_fuera)
	resized.connect(queue_redraw)


func indice_bajo(x: float) -> int:
	if serie.is_empty():
		return -1
	var ancho := _ancho_util()
	if ancho <= 0.0:
		return -1
	var paso := ancho / float(serie.size())
	return clampi(int((x - MARGEN_IZQ) / paso), 0, serie.size() - 1)


func limpiar_globo() -> void:
	_indice = -1
	if _globo != null:
		_globo.visible = false
	queue_redraw()


func _draw() -> void:
	var ancho := _ancho_util()
	var alto := size.y - MARGEN_INF - MARGEN_HOJA
	if serie.is_empty() or ancho <= 0.0 or alto <= 0.0:
		return
	var color_ok := TemaStoreScript.color_estado(true)
	var color_caido := TemaStoreScript.color_estado(false)
	var color_tenue := TemaStoreScript.color_estado(null)
	var maximo := 1
	for dia in serie:
		maximo = maxi(maximo, int(dia.get("validos", 0)) + int(dia.get("caidos", 0)))
	var fuente := get_theme_default_font()
	for i in range(LINEAS_REJILLA + 1):
		var y := MARGEN_INF + alto * float(i) / float(LINEAS_REJILLA)
		draw_line(Vector2(MARGEN_IZQ, y), Vector2(MARGEN_IZQ + ancho, y), Color(color_tenue, 0.3), 1.0)
		var valor := int(round(maximo * (1.0 - float(i) / float(LINEAS_REJILLA))))
		draw_string(fuente, Vector2(2.0, y + 4.0), str(valor), HORIZONTAL_ALIGNMENT_LEFT, -1, FUENTE_EJE, color_tenue)
	var paso := ancho / float(serie.size())
	var grosor := maxf(paso - SEPARACION, 1.0)
	for i in range(serie.size()):
		var dia: Dictionary = serie[i]
		var validos := int(dia.get("validos", 0))
		var caidos := int(dia.get("caidos", 0))
		var x := MARGEN_IZQ + paso * float(i)
		var alto_caidos := alto * float(caidos) / float(maximo)
		if caidos > 0:
			draw_rect(Rect2(x, MARGEN_INF + alto - alto_caidos, grosor, alto_caidos), color_caido)
		var alto_validos := alto * float(validos) / float(maximo)
		if validos > 0:
			draw_rect(Rect2(x, MARGEN_INF + alto - alto_caidos - alto_validos, grosor, alto_validos), color_ok)
		if i == _indice:
			draw_rect(Rect2(x - 1.0, MARGEN_INF - 2.0, grosor + 2.0, alto + 2.0), Color(color_tenue, 0.8), false, 1.0)
	for pos in _posiciones_fecha(serie.size()):
		var dia: Dictionary = serie[pos]
		var x := MARGEN_IZQ + paso * (float(pos) + 0.5)
		draw_string(fuente, Vector2(x - 25.0, size.y - 4.0), _fecha_corta(str(dia.get("fecha", ""))), \
			HORIZONTAL_ALIGNMENT_CENTER, 50.0, FUENTE_EJE, color_tenue)


func _ancho_util() -> float:
	return size.x - MARGEN_IZQ - MARGEN_DER


func _posiciones_fecha(total: int) -> Array:
	var lista: Array = []
	for pos in [0, int(total / 2), total - 1]:
		if pos >= 0 and pos < total and not lista.has(pos):
			lista.append(pos)
	return lista


func _fecha_corta(clave: String) -> String:
	if clave.length() < 10:
		return clave
	return "%s/%s" % [clave.substr(8, 2), clave.substr(5, 2)]


func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion):
		return
	var nuevo := indice_bajo((event as InputEventMouseMotion).position.x)
	if nuevo == _indice:
		return
	_indice = nuevo
	_pintar_globo()
	queue_redraw()


func _on_fuera() -> void:
	limpiar_globo()


func _pintar_globo() -> void:
	if _indice < 0 or _indice >= serie.size():
		_globo.visible = false
		return
	var dia: Dictionary = serie[_indice]
	var validos := int(dia.get("validos", 0))
	var caidos := int(dia.get("caidos", 0))
	var texto := "%s · %s %d · %s %d" % [
		str(dia.get("fecha", "")),
		tr("Válidos"), validos,
		tr("Caídos"), caidos,
	]
	_globo.text = texto
	_globo.add_theme_stylebox_override("normal", _caja_globo())
	_globo.reset_size()
	var alto := size.y - MARGEN_INF - MARGEN_HOJA
	var paso := _ancho_util() / float(serie.size())
	var x := MARGEN_IZQ + paso * (float(_indice) + 0.5) - _globo.size.x * 0.5
	_globo.position = Vector2(clampf(x, 0.0, maxf(size.x - _globo.size.x, 0.0)), maxf(alto - _globo.size.y - 6.0, 0.0))
	_globo.visible = true


func _caja_globo() -> StyleBoxFlat:
	var base := get_theme_stylebox("panel", "TooltipPanel")
	if base is StyleBoxFlat:
		return (base as StyleBoxFlat).duplicate() as StyleBoxFlat
	return TemaStoreScript.relleno(TemaStoreScript.color_estado(null), 4)
