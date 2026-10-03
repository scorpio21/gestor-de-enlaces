extends Window

const ListItemScript := preload("res://scripts/list_item.gd")
const RedireccionesScript := preload("res://scripts/redirecciones.gd")

@onready var lista_historial: VBoxContainer = %ListaHistorial
@onready var aviso_vacio: Label = %AvisoVacio


func _ready() -> void:
	close_requested.connect(hide)


func abrir(entradas: Array, url := "") -> void:
	for hijo in lista_historial.get_children():
		hijo.queue_free()
	var filas := 0
	for e in entradas:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var intentos := maxi(int(e.get("intentos", 1)), 1)
		var detalle := ListItemScript.formatear_mensaje(str(e.get("mensaje", "")), int(e.get("codigo", 0)))
		if intentos > 1:
			detalle += " " + tr("(%d intentos)") % intentos
		var aviso := RedireccionesScript.explicar(url, str(e.get("url_final", "")))
		if not aviso.is_empty():
			detalle += " · " + aviso
		var fila := Label.new()
		fila.text = tr("%s — %s — %s") % [
			ListItemScript.formatear_fecha(int(e.get("fecha", 0))),
			_historial_estado(e),
			detalle,
		]
		fila.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lista_historial.add_child(fila)
		filas += 1
	aviso_vacio.visible = filas == 0
	popup_centered()


func _historial_estado(e: Dictionary) -> String:
	if e.get("valido") == true:
		return tr("Válido")
	if e.get("valido") == false:
		return tr("Caído")
	return tr("Sin comprobar")