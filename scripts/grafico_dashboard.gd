extends Control

const TemaStoreScript := preload("res://scripts/tema_store.gd")

var serie: Array = []


func _draw() -> void:
	if serie.is_empty():
		return
	var ancho := size.x
	var alto := size.y
	if ancho <= 0 or alto <= 0:
		return
	var maximo := 1
	for dia in serie:
		maximo = maxi(maximo, int(dia.get("validos", 0)) + int(dia.get("caidos", 0)))
	var paso := ancho / float(serie.size())
	var color_ok := TemaStoreScript.color_estado(true)
	var color_caido := TemaStoreScript.color_estado(false)
	for i in range(serie.size()):
		var dia: Dictionary = serie[i]
		var validos := int(dia.get("validos", 0))
		var caidos := int(dia.get("caidos", 0))
		var alto_v := alto * float(validos) / float(maximo)
		var alto_c := alto * float(caidos) / float(maximo)
		var x := paso * float(i)
		if caidos > 0:
			draw_rect(Rect2(x, alto - alto_c - alto_v, maxf(paso - 2.0, 1.0), alto_c), color_caido)
		if validos > 0:
			draw_rect(Rect2(x, alto - alto_v, maxf(paso - 2.0, 1.0), alto_v), color_ok)