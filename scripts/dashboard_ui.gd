extends Window

const DashboardStoreScript := preload("res://scripts/dashboard_store.gd")
const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")

var _datos := {}
var _serie: Array = []
var _formato := ""


func _ready() -> void:
	%BotonCsv.pressed.connect(_exportar.bind("csv"))
	%BotonJson.pressed.connect(_exportar.bind("json"))
	%DialogoExportar.file_selected.connect(_on_exportar_elegido)
	%DialogoExportar.access = FileDialog.ACCESS_FILESYSTEM


func abrir(entradas: Array, estados: Dictionary) -> void:
	_datos = DashboardStoreScript.agregar_datos(entradas, estados)
	_serie = _datos.get("serie", [])
	_pintar_resumen()
	_pintar_grupos()
	%Grafico.serie = _serie
	%Grafico.queue_redraw()
	popup_centered()


func _pintar_resumen() -> void:
	var r: Dictionary = _datos.get("resumen", {})
	var pct := float(r.get("disponible_pct", 0.0))
	%ResumenLabel.text = tr("Válidos: %d") % int(r.get("activos", 0)) \
		+ "  ·  " + tr("Caídos: %d") % int(r.get("rotos", 0)) \
		+ "  ·  " + tr("Sin comprobar: %d") % int(r.get("sin_comprobar", 0))
	%PctLabel.text = tr("Disponible: %s %% (%d comprobados)") % [
		str(int(round(pct))) + "%",
		int(r.get("activos", 0)) + int(r.get("rotos", 0)),
	]


func _pintar_grupos() -> void:
	%ListaCategorias.clear()
	%ListaHosts.clear()
	for g in _datos.get("categorias", []):
		var cat := str(g.get("categoria", ""))
		%ListaCategorias.add_item(_texto_grupo(GestorCatalogoScript.new().categoria_display(cat), g))
	for g in _datos.get("hosts", []):
		var nombre := str(g.get("host", ""))
		%ListaHosts.add_item(_texto_grupo(nombre, g))


func _texto_grupo(nombre: String, g: Dictionary) -> String:
	var activos := int(g.get("activos", 0))
	var rotos := int(g.get("rotos", 0))
	var pct := float(g.get("disponible_pct", 0.0))
	return "%s — %s · %s (%d%%)" % [
		nombre,
		tr("Válidos: %d") % activos,
		tr("Caídos: %d") % rotos,
		int(round(pct)),
	]


func _exportar(formato: String) -> void:
	_formato = formato
	if formato == "csv":
		%DialogoExportar.current_file = "estadisticas.csv"
		%DialogoExportar.filters = PackedStringArray(["*.csv ; Archivo CSV (*.csv)"])
	else:
		%DialogoExportar.current_file = "estadisticas.json"
		%DialogoExportar.filters = PackedStringArray(["*.json ; Archivo JSON (*.json)"])
	%DialogoExportar.popup_centered()


func _on_exportar_elegido(ruta: String) -> void:
	var resultado: Dictionary
	if _formato == "csv":
		resultado = DashboardStoreScript.exportar_csv(ruta, _datos)
	else:
		resultado = DashboardStoreScript.exportar_json(ruta, _datos)
	%Nota.text = tr("Estadísticas exportadas.") if resultado.get("ok") == true else tr("No se pudo exportar.")