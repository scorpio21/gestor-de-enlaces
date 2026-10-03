extends PanelContainer

const TemaStoreScript := preload("res://scripts/tema_store.gd")

signal elegido

@onready var nombre: Label = %Nombre
@onready var col_a: Label = %ColA
@onready var col_b: Label = %ColB
@onready var col_c: Label = %ColC
@onready var barra: ProgressBar = %Barra


func configurar(texto_nombre: String, a: String, b: String, c: String, color: Color, ratio := -1.0, columna_color := 2, tooltip := "") -> void:
	nombre.text = texto_nombre
	nombre.tooltip_text = texto_nombre
	col_a.text = a
	col_b.text = b
	col_c.text = c
	var cols: Array[Label] = [col_a, col_b, col_c]
	for i in range(cols.size()):
		if i == columna_color:
			cols[i].add_theme_color_override("font_color", color)
		else:
			cols[i].remove_theme_color_override("font_color")
	barra.visible = ratio >= 0.0
	if ratio >= 0.0:
		barra.value = clampf(ratio * 100.0, 0.0, 100.0)
		barra.add_theme_stylebox_override("fill", TemaStoreScript.relleno(color))
	tooltip_text = texto_nombre if tooltip.is_empty() else tooltip


func configurar_columnas(texto_nombre: String, columnas: Array, color: Color, color_columna := 0, anchos := [], alineaciones := []) -> void:
	nombre.text = texto_nombre
	nombre.tooltip_text = texto_nombre
	var etiquetas: Array = [col_a, col_b, col_c]
	for i in range(mini(columnas.size(), etiquetas.size())):
		var etiqueta: Label = etiquetas[i]
		etiqueta.text = str(columnas[i])
		if i < anchos.size() and float(anchos[i]) > 0.0:
			etiqueta.custom_minimum_size.x = float(anchos[i])
			etiqueta.clip_text = true
			etiqueta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if i < alineaciones.size():
			etiqueta.horizontal_alignment = int(alineaciones[i])
		if i == color_columna:
			etiqueta.add_theme_color_override("font_color", color)
		else:
			etiqueta.remove_theme_color_override("font_color")
	barra.visible = false


func pulsable(activo: bool) -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if activo else Control.CURSOR_ARROW


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		elegido.emit()
