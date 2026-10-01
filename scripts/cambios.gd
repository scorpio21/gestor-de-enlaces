extends Window

const CambiosStoreScript := preload("res://scripts/cambios_store.gd")
const ListItemScript := preload("res://scripts/list_item.gd")
const TemaStoreScript := preload("res://scripts/tema_store.gd")
const FILA_TABLA := preload("res://scenes/FilaTabla.tscn")

signal filtrar_pedido
signal dashboard_pedido

const ANCHOS := [0.0, 116.0, 128.0, 0.0]
const ALINEACIONES := [2, 0, 0]
const COLUMNA_COLOR := 1

@onready var resumen: Label = %Resumen
@onready var cobertura: Label = %Cobertura
@onready var aviso_vacio: Label = %AvisoVacio
@onready var lista_cambios: VBoxContainer = %ListaCambios
@onready var nota: Label = %Nota
@onready var dialogo_exportar: FileDialog = %DialogoExportar

var _cambios: Array = []
var _nombres: Dictionary = {}
var _cobertura := 0


func _ready() -> void:
	close_requested.connect(hide)
	%BotonFiltrar.pressed.connect(_al_filtrar)
	%BotonDashboard.pressed.connect(_al_dashboard)
	%BotonCsv.pressed.connect(_preparar_csv)
	dialogo_exportar.file_selected.connect(_on_exportar_elegido)
	dialogo_exportar.access = FileDialog.ACCESS_FILESYSTEM


func abrir(cambios: Array, nombres: Dictionary, desde := 0) -> void:
	_cambios = cambios.duplicate(true)
	_nombres = nombres.duplicate(true)
	_cobertura = desde
	resumen.text = _resumen_texto()
	cobertura.visible = desde > 0
	cobertura.text = tr("El historial de cambios llega hasta %s.") % ListItemScript.formatear_fecha(desde)
	aviso_vacio.visible = _cambios.is_empty()
	_pintar_filas()
	nota.text = ""
	popup_centered()


func cambios() -> Array:
	return _cambios


func aplicar_paleta() -> void:
	_pintar_filas()


func _pintar_filas() -> void:
	for hijo in lista_cambios.get_children():
		lista_cambios.remove_child(hijo)
		hijo.queue_free()
	for cambio in _cambios:
		var fila: PanelContainer = FILA_TABLA.instantiate()
		lista_cambios.add_child(fila)
		_configurar_fila(fila, cambio)


func _resumen_texto() -> String:
	var cuenta: Dictionary = CambiosStoreScript.resumen(_cambios)
	var partes: Array = []
	for par in [
		[CambiosStoreScript.TIPO_NUEVO_CAIDO, "%d nuevos caídos", "%d nuevo caído"],
		[CambiosStoreScript.TIPO_RECUPERADO, "%d recuperados", "%d recuperado"],
		[CambiosStoreScript.TIPO_REUBICADO, "%d reubicados", "%d reubicado"],
	]:
		var total := int(cuenta.get(par[0], 0))
		if total == 1:
			partes.append(tr(par[2]) % total)
		elif total > 1:
			partes.append(tr(par[1]) % total)
	return " · ".join(partes)


func _configurar_fila(fila: PanelContainer, cambio: Dictionary) -> void:
	fila.configurar_columnas(
		_nombre_de(cambio),
		[
			ListItemScript.formatear_fecha(int(cambio.get("fecha", 0))),
			tr("%s → %s") % [_texto_estado(cambio.get("valido_ant")), _texto_estado(cambio.get("valido_nue"))],
			_detalle_de(cambio),
		],
		TemaStoreScript.color_clave(_clave_de(str(cambio.get("tipo", "")))),
		COLUMNA_COLOR,
		ANCHOS,
		ALINEACIONES
	)


func _nombre_de(cambio: Dictionary) -> String:
	var nombre := str(_nombres.get(str(cambio.get("clave", "")), ""))
	return nombre if not nombre.is_empty() else str(cambio.get("url", ""))


func _detalle_de(cambio: Dictionary) -> String:
	var mensaje := str(cambio.get("mensaje_nue", ""))
	if not mensaje.is_empty():
		return ListItemScript.formatear_mensaje(mensaje, int(cambio.get("codigo_nue", 0)))
	return str(cambio.get("url", ""))


func _texto_estado(valido: Variant) -> String:
	if valido == true:
		return tr("Válido")
	if valido == false:
		return tr("Caído")
	return tr("Sin comprobar")


func _clave_de(tipo: String) -> String:
	if tipo == CambiosStoreScript.TIPO_NUEVO_CAIDO:
		return "caido"
	if tipo == CambiosStoreScript.TIPO_RECUPERADO:
		return "valido"
	if tipo == CambiosStoreScript.TIPO_REUBICADO:
		return "aviso"
	return "sin_comprobar"


func _al_filtrar() -> void:
	hide()
	filtrar_pedido.emit()


func _al_dashboard() -> void:
	hide()
	dashboard_pedido.emit()


func _preparar_csv() -> void:
	dialogo_exportar.current_file = "cambios.csv"
	dialogo_exportar.filters = PackedStringArray(["*.csv ; Archivo CSV (*.csv)"])
	dialogo_exportar.popup_centered()


func _on_exportar_elegido(ruta: String) -> void:
	var resultado: Dictionary = CambiosStoreScript.exportar_csv(ruta, _cambios, _nombres)
	nota.text = tr("Cambios exportados.") if resultado.get("ok", false) else tr("No se pudo exportar.")