extends Window

const ListItemScript := preload("res://scripts/list_item.gd")

@onready var lista_historial: VBoxContainer = %ListaHistorial
@onready var aviso_vacio: Label = %AvisoVacio


func _ready() -> void:
	close_requested.connect(hide)


func abrir(entradas: Array) -> void:
	for hijo in lista_historial.get_children():
		hijo.queue_free()
	var filas := 0
	for e in entradas:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var fila := Label.new()
		fila.text = "%s — %s — %s" % [
			ListItemScript.formatear_fecha(int(e.get("fecha", 0))),
			"Válido" if e.get("valido") == true else "Caído",
			str(e.get("mensaje", "")),
		]
		fila.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lista_historial.add_child(fila)
		filas += 1
	aviso_vacio.visible = filas == 0
	popup_centered()