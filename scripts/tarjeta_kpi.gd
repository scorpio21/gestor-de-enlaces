extends PanelContainer

const TemaStoreScript := preload("res://scripts/tema_store.gd")

@onready var valor: Label = %Valor
@onready var etiqueta: Label = %Etiqueta
@onready var barra: ProgressBar = %Barra


func configurar(texto_valor: String, texto_etiqueta: String, color: Color, ratio := -1.0) -> void:
	valor.text = texto_valor
	valor.add_theme_color_override("font_color", color)
	etiqueta.text = texto_etiqueta
	barra.visible = ratio >= 0.0
	if ratio >= 0.0:
		barra.value = clampf(ratio * 100.0, 0.0, 100.0)
		barra.add_theme_stylebox_override("fill", TemaStoreScript.relleno(color))
