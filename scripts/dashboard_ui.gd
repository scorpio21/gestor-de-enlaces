extends Window

const DashboardStoreScript := preload("res://scripts/dashboard_store.gd")
const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
const TemaStoreScript := preload("res://scripts/tema_store.gd")
const RedireccionesScript := preload("res://scripts/redirecciones.gd")
const FILA_SCENE := preload("res://scenes/FilaTabla.tscn")
const CABECERAS := {
	"categoria": {"campo": "categoria", "claves": ["nombre", "activos", "rotos", "disponible_pct"]},
	"host": {"campo": "host", "claves": ["nombre", "activos", "rotos", "disponible_pct"]},
	"top": {"campo": "nombre", "claves": ["nombre", "veces", "codigo", "fecha"]},
}

signal navegar(tipo: String, valor: String)
signal comprobar_ya
signal actualizar_urls(urls: Array)

@onready var _cabeceras := {
	"categoria": %CabeceraCategorias,
	"host": %CabeceraHosts,
	"top": %CabeceraTop,
}

var _datos := {}
var _entradas: Array = []
var _estados: Dictionary = {}
var _instantaneas: Array = []
var _formato := ""
var _rango := 0
var _orden := {"categoria": "", "host": "", "top": ""}
var _orden_desc := {"categoria": true, "host": true, "top": true}
var _titulos := {}


func _ready() -> void:
	close_requested.connect(hide)
	%BotonCerrar.pressed.connect(hide)
	%BotonCsv.pressed.connect(_exportar.bind("csv"))
	%BotonJson.pressed.connect(_exportar.bind("json"))
	%BotonComprobar.pressed.connect(_on_comprobar)
	%BotonReubicar.pressed.connect(_on_actualizar_urls)
	%Rango.item_selected.connect(_on_rango)
	%DialogoExportar.file_selected.connect(_on_exportar_elegido)
	%DialogoExportar.access = FileDialog.ACCESS_FILESYSTEM
	%Rango.add_item(tr("7 días"), 7)
	%Rango.add_item(tr("30 días"), 30)
	%Rango.add_item(tr("90 días"), 90)
	%Rango.add_item(tr("Todo el histórico"), 0)
	%Rango.select(3)
	_preparar_cabeceras()
	aplicar_paleta()


func _preparar_cabeceras() -> void:
	for tipo in CABECERAS:
		var claves: Array = CABECERAS[tipo]["claves"]
		var titulos: Array = []
		for indice in range(_cabeceras[tipo].get_child_count()):
			var boton: Button = _cabeceras[tipo].get_child(indice)
			titulos.append(boton.text)
			boton.pressed.connect(_on_ordenar.bind(tipo, str(claves[indice])))
		_titulos[tipo] = titulos
	_pintar_cabeceras()


func _pintar_cabeceras() -> void:
	for tipo in CABECERAS:
		var activa := str(_orden.get(tipo, ""))
		var desc := bool(_orden_desc.get(tipo, true))
		var claves: Array = CABECERAS[tipo]["claves"]
		var titulos: Array = _titulos.get(tipo, [])
		for indice in range(_cabeceras[tipo].get_child_count()):
			var boton: Button = _cabeceras[tipo].get_child(indice)
			var titulo := str(titulos[indice])
			var flecha := " ▼" if desc and str(claves[indice]) == activa else (" ▲" if str(claves[indice]) == activa else "")
			boton.text = titulo + flecha
			boton.tooltip_text = tr("Ordenar por %s") % titulo


func _on_ordenar(tipo: String, clave: String) -> void:
	if str(_orden.get(tipo, "")) == clave:
		_orden_desc[tipo] = not bool(_orden_desc.get(tipo, true))
	else:
		_orden[tipo] = clave
		_orden_desc[tipo] = clave != "nombre"
	_pintar_cabeceras()
	_recalcular()


func _ordenado(lista: Array, tipo: String) -> Array:
	var clave := str(_orden.get(tipo, ""))
	if clave == "":
		return lista
	var copia := lista.duplicate()
	copia.sort_custom(_comparador.bind(clave, str(CABECERAS[tipo]["campo"]), bool(_orden_desc.get(tipo, true))))
	return copia


func _comparador(a: Dictionary, b: Dictionary, clave: String, campo: String, desc: bool) -> bool:
	var va: Variant = a.get(clave, 0)
	var vb: Variant = b.get(clave, 0)
	var comparacion := 0
	if typeof(va) == TYPE_INT or typeof(va) == TYPE_FLOAT:
		comparacion = -1 if float(va) < float(vb) else (1 if float(va) > float(vb) else 0)
	else:
		comparacion = str(va).naturalnocasecmp_to(str(vb))
	if comparacion == 0:
		comparacion = str(a.get(campo, "")).naturalnocasecmp_to(str(b.get(campo, "")))
	return comparacion > 0 if desc else comparacion < 0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		hide()


func abrir(entradas: Array, estados: Dictionary, instantaneas := []) -> void:
	_entradas = entradas
	_estados = estados
	_instantaneas = instantaneas
	_recalcular()
	popup_centered()


func aplicar_paleta() -> void:
	%LeyendaOk.color = TemaStoreScript.color_estado(true)
	%LeyendaCaido.color = TemaStoreScript.color_estado(false)
	%LeyendaSinComprobar.color = TemaStoreScript.color_estado(null)
	if _entradas.is_empty():
		%Grafico.queue_redraw()
		return
	_recalcular()


func _recalcular() -> void:
	_datos = DashboardStoreScript.agregar_datos(_entradas, _estados, _rango, _instantaneas)
	var vacio := _entradas.is_empty()
	%Datos.visible = not vacio
	%EstadoVacio.visible = vacio
	%Rango.visible = not vacio
	%AvisoSinComprobar.visible = not vacio and int(_datos.get("ultima", 0)) == 0
	%AvisoInstantaneas.visible = not vacio and int(_datos.get("instantaneas", 0)) == 0
	if vacio:
		%Grafico.limpiar_globo()
		%Grafico.serie = []
		%Grafico.queue_redraw()
		return
	_pintar_kpis()
	_pintar_grupos()
	_pintar_top()
	_pintar_reubicados()
	%Grafico.serie = _datos.get("serie", [])
	%Grafico.queue_redraw()


func _pintar_kpis() -> void:
	var r: Dictionary = _datos.get("resumen", {})
	var total := int(r.get("total", 0))
	var activos := int(r.get("activos", 0))
	var rotos := int(r.get("rotos", 0))
	var sin_comprobar := int(r.get("sin_comprobar", 0))
	var comprobados := activos + rotos
	var pct := float(r.get("disponible_pct", 0.0))
	var color_ok := TemaStoreScript.color_estado(true)
	var color_caido := TemaStoreScript.color_estado(false)
	var color_tenue := TemaStoreScript.color_estado(null)
	%KpiTotal.configurar(str(total), tr("Total"), color_tenue, -1.0)
	%KpiDisponibles.configurar(str(activos), tr("Disponibles"), color_ok, _ratio(pct, comprobados))
	%KpiCaidos.configurar(str(rotos), tr("Caídos"), color_caido, _ratio(pct, comprobados))
	%KpiSinComprobar.configurar(str(sin_comprobar), tr("Sin comprobar"), color_tenue, _ratio(0.0, total))
	%EtiquetaDisponibilidad.text = tr("Disponibilidad de %d enlaces comprobados") % comprobados \
		if comprobados > 0 else tr("Sin comprobaciones todavía")
	var pct_texto := "%d%%" % int(round(pct))
	%PctDisponibilidad.text = pct_texto
	%PctDisponibilidad.add_theme_color_override("font_color", _color_pct(pct))
	%BarraDisponibilidad.value = clampf(pct, 0.0, 100.0)
	%BarraDisponibilidad.add_theme_stylebox_override("fill", TemaStoreScript.relleno(_color_pct(pct)))


func _pintar_grupos() -> void:
	var hay: bool = not _datos.get("categorias", []).is_empty() or not _datos.get("hosts", []).is_empty()
	%AyudaNavegar.visible = hay
	_llenar_grupos(%ListaCategorias, _ordenado(_datos.get("categorias", []), "categoria"), "categoria")
	_llenar_grupos(%ListaHosts, _ordenado(_datos.get("hosts", []), "host"), "host")


func _llenar_grupos(contenedor: VBoxContainer, grupos: Array, tipo: String) -> void:
	for hijo in contenedor.get_children():
		contenedor.remove_child(hijo)
		hijo.queue_free()
	for g in grupos:
		var clave := str(g.get(tipo, ""))
		var nombre := GestorCatalogoScript.new().categoria_display(clave) if tipo == "categoria" else clave
		var pct := float(g.get("disponible_pct", 0.0))
		var fila := FILA_SCENE.instantiate()
		contenedor.add_child(fila)
		fila.pulsable(true)
		fila.elegido.connect(_on_elegido.bind(tipo, clave))
		var pct_texto := "%d%%" % int(round(pct))
		fila.configurar(nombre, str(int(g.get("activos", 0))), str(int(g.get("rotos", 0))), pct_texto, _color_pct(pct), pct / 100.0)


func _pintar_top() -> void:
	for hijo in %ListaTop.get_children():
		%ListaTop.remove_child(hijo)
		hijo.queue_free()
	var top: Array = _ordenado(_datos.get("top", []), "top")
	%PanelTop.visible = not top.is_empty()
	for t in top:
		var url := str(t.get("url", ""))
		var codigo := int(t.get("codigo", 0))
		var fila := FILA_SCENE.instantiate()
		%ListaTop.add_child(fila)
		fila.pulsable(true)
		fila.elegido.connect(_on_elegido.bind("enlace", url))
		fila.configurar(str(t.get("nombre", "")), str(int(t.get("veces", 0))), str(codigo), \
			_fecha_corta(int(t.get("fecha", 0))), TemaStoreScript.color_estado(false), -1.0, 1, \
			_tooltip_redirect(url, str(t.get("url_final", ""))))


func _tooltip_redirect(url: String, destino: String) -> String:
	var lineas := PackedStringArray([url])
	var aviso := RedireccionesScript.explicar(url, destino)
	if not aviso.is_empty():
		lineas.append(aviso)
	return "\n".join(lineas)


func _pintar_reubicados() -> void:
	for hijo in %ListaReubicados.get_children():
		%ListaReubicados.remove_child(hijo)
		hijo.queue_free()
	var reubicados: Array = _datos.get("reubicados", [])
	%PanelReubicados.visible = not reubicados.is_empty()
	for r in reubicados:
		var url := str(r.get("url", ""))
		var fila := FILA_SCENE.instantiate()
		%ListaReubicados.add_child(fila)
		fila.pulsable(true)
		fila.elegido.connect(_on_elegido.bind("enlace", url))
		fila.configurar_columnas(
			str(r.get("nombre", "")),
			[
				_host_de_url(url),
				_host_de_url(str(r.get("destino", ""))),
				_fecha_corta(int(r.get("fecha", 0))),
			],
			TemaStoreScript.color_estado(null),
			1,
			[120, 220, 76],
			[HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_RIGHT]
		)
		fila.tooltip_text = _tooltip_redirect(url, str(r.get("destino", "")))


func _host_de_url(url: String) -> String:
	return str(url).trim_prefix("https://").trim_prefix("http://").get_slice("/", 0)


func _on_actualizar_urls() -> void:
	var reubicados: Array = _datos.get("reubicados", [])
	if reubicados.is_empty():
		return
	var urls: Array = []
	for r in reubicados:
		urls.append(str(r.get("url", "")))
	actualizar_urls.emit(urls)


func _on_elegido(tipo: String, valor: String) -> void:
	navegar.emit(tipo, valor)


func _on_comprobar() -> void:
	hide()
	comprobar_ya.emit()


func _on_rango(_indice: int) -> void:
	_rango = %Rango.get_selected_id()
	_recalcular()


func _ratio(pct: float, total: int) -> float:
	return pct / 100.0 if total > 0 else -1.0


func _color_pct(pct: float) -> Color:
	if pct >= 80.0:
		return TemaStoreScript.color_estado(true)
	if pct >= 50.0:
		return TemaStoreScript.color_estado(null)
	return TemaStoreScript.color_estado(false)


func _fecha_corta(unix: int) -> String:
	if unix <= 0:
		return tr("Sin historial")
	var d := Time.get_datetime_dict_from_unix_time(unix)
	return "%02d/%02d/%02d" % [d.day, d.month, d.year % 100]


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
