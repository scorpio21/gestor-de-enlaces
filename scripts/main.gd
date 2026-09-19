extends Control

const LIST_ITEM_SCENE := preload("res://scenes/ListItem.tscn")
const DATA_RES := "res://data/data.json"
const DATA_USER := "user://enlaces.json"
const EstadoStoreScript := preload("res://scripts/estado_store.gd")
const ContadoresScript := preload("res://scripts/gestor_contadores.gd")
const ConfigStoreScript := preload("res://scripts/config_store.gd")
const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
const GestorImagenesScript := preload("res://scripts/gestor_imagenes.gd")
const GestorArchivoScript := preload("res://scripts/gestor_archivo.gd")
const GestorDatosScript := preload("res://scripts/gestor_datos.gd")
const LoggerScript := preload("res://scripts/logger.gd")
const DiagnosticoScript := preload("res://scripts/diagnostico.gd")
const ColaStoreScript := preload("res://scripts/cola_store.gd")
const InformeStoreScript := preload("res://scripts/informe_store.gd")

@onready var lista: VBoxContainer = %ListaContenedor
@onready var busqueda: LineEdit = %Busqueda
@onready var filtro_cat: OptionButton = %FiltroCategoria
@onready var progreso: Label = %Progreso
@onready var filtro: OptionButton = %FiltroEstado
@onready var ventana_agregar = %VentanaAgregar
@onready var preferencias: Window = %VentanaPreferencias
@onready var rotos_label: Label = %Rotos
@onready var activos_label: Label = %Activos
@onready var total_label: Label = %Total
@onready var version_label: Label = %Version
@onready var barra_progreso: ProgressBar = %BarraProgreso
@onready var orden_fecha: OptionButton = %OrdenFecha
@onready var dialogo_historial: Window = %DialogoHistorial
@onready var timer_auto: Timer = %AutoEscaneo

var _entradas: Array = []
var _cola: Array[Button] = []
var _en_vuelo := 0
var _hechos := 0
var _total := 0
var _estado_store: RefCounted
var _config_store: RefCounted
var _logger = null
var _paralelismo := 3
var _timeout := 10.0
var _auto_abrir := true
var _intervalo_auto := 0
var _estados := {}
var _borrados: Array = []
var _item_pendiente_borrar: Button = null
var _persistir := true
var _limpieza_resultado: Dictionary = {}
var _cola_store: RefCounted = null


func _ready() -> void:
	_configurar_menus()
	busqueda.text_changed.connect(_on_busqueda_changed)
	%BotonComprobar.pressed.connect(_comprobar_visibles)
	%ConfirmarBorrado.confirmed.connect(_confirmar_borrado)
	%ConfirmarLimpieza.confirmed.connect(_confirmar_limpieza)
	%ConfirmarRestaurar.confirmed.connect(_confirmar_restaurar)
	%ConfirmarReanudar.confirmed.connect(_reanudar_escaneo)
	%ConfirmarReanudar.canceled.connect(_descartar_cola_pendiente)
	filtro.clear()
	filtro.add_item("Todos", 0)
	filtro.add_item("Válidos", 1)
	filtro.add_item("Caídos / no existen", 2)
	filtro.add_item("Sin comprobar", 3)
	filtro.select(0)
	filtro.item_selected.connect(func(_i: int) -> void: _aplicar_filtro())
	filtro_cat.clear()
	filtro_cat.add_item("Todas", 0)
	for i in range(GestorCatalogoScript.CATEGORIAS.size()):
		filtro_cat.add_item(GestorCatalogoScript.categoria_display(GestorCatalogoScript.CATEGORIAS[i]), i + 1)
	filtro_cat.select(0)
	filtro_cat.item_selected.connect(func(_i: int) -> void: _aplicar_filtro())
	orden_fecha.clear()
	orden_fecha.add_item("Sin ordenar", 0)
	orden_fecha.add_item("Más recientes", 1)
	orden_fecha.add_item("Más antiguos", 2)
	orden_fecha.select(0)
	orden_fecha.item_selected.connect(func(_i: int) -> void: _aplicar_filtro())
	timer_auto.timeout.connect(_on_auto_timer)
	ventana_agregar.guardado.connect(_on_enlace_guardado)
	ventana_agregar.lote_guardado.connect(_on_lote_guardado)
	ventana_agregar.editado.connect(_on_enlace_editado)
	_cargar_datos()
	_config_store = ConfigStoreScript.new()
	_cola_store = ColaStoreScript.new()
	var cfg: Dictionary = _config_store.cargar()
	_paralelismo = clampi(int(cfg.get("paralelismo", 3)), 1, 8)
	_timeout = clampf(float(cfg.get("timeout", 10.0)), 3.0, 60.0)
	_auto_abrir = cfg.get("auto_abrir", true) == true
	_intervalo_auto = int(cfg.get("intervalo", 0))
	preferencias.aplicado.connect(_aplicar_preferencias)
	%DialogoImportar.file_selected.connect(_on_importar_elegido)
	%DialogoExportar.file_selected.connect(_on_exportar_elegido)
	%DialogoInforme.file_selected.connect(_on_informe_elegido)
	if not _es_headless():
		_logger = LoggerScript.new("user://")
		_log_app("inicio", "aplicación iniciada")
	%DialogoDiagnostico.file_selected.connect(_on_diag_elegido)
	_refrescar_vista()
	version_label.text = "v" + str(ProjectSettings.get_setting("application/config/version", "0.0.1"))
	_actualizar_status()
	_revisar_cola_pendiente()
	_rearmar_auto_escaneo()
	_iniciar_auto_escaneo()


func _configurar_menus() -> void:
	var menu_file: PopupMenu = %File
	menu_file.clear()
	menu_file.add_item("Importar…", 1)
	menu_file.add_item("Exportar…", 2)
	menu_file.add_item("Informe de disponibilidad…", 5)
	menu_file.add_separator()
	menu_file.add_item("Restaurar copia…", 4)
	menu_file.add_item("Salir", 3)
	menu_file.id_pressed.connect(_on_file_id)

	var menu_util: PopupMenu = %Utilidades
	menu_util.clear()
	menu_util.add_item("Agregar", 0)
	menu_util.add_item("Preferencias…", 1)
	menu_util.add_item("Limpiar capturas huérfanas…", 2)
	menu_util.add_item("Exportar diagnóstico…", 3)
	menu_util.id_pressed.connect(_on_utilidades_id)


func _on_file_id(id: int) -> void:
	match id:
		1:
			%DialogoImportar.popup_centered()
		2:
			%DialogoExportar.popup_centered()
		5:
			%DialogoInforme.popup_centered()
		3:
			get_tree().quit()
		4:
			_on_restaurar_copia()


func _on_importar_elegido(ruta: String) -> void:
	var res: Dictionary = GestorArchivoScript.importar(ruta, _urls_existentes())
	if not res.get("ok", false):
		progreso.text = str(res.get("error", "No se pudo importar el catálogo."))
		return
	var entradas: Array = res.get("entradas", [])
	var omitidas := int(res.get("omitidas", 0))
	if entradas.is_empty():
		progreso.text = "%d omitidos (ya existían o sin URL válida)." % omitidas
		return
	var importados := entradas.size()
	for entrada in entradas:
		_entradas.append(entrada)
	if not _guardar_datos():
		_cargar_datos()
		_refrescar_vista()
		progreso.text = "No se pudo guardar el catálogo."
		return
	_refrescar_vista()
	_actualizar_status()
	progreso.text = "%d importados, %d omitidos." % [importados, omitidas]


func _on_exportar_elegido(ruta: String) -> void:
	var res: Dictionary = GestorArchivoScript.exportar(ruta, _entradas)
	if not res.get("ok", false):
		progreso.text = str(res.get("error", "No se pudo exportar el catálogo."))
		return
	progreso.text = "Catálogo exportado (%d enlaces)." % int(res.get("total", 0))


func _on_informe_elegido(ruta: String) -> void:
	var formato := _formato_informe(ruta)
	if not ruta.to_lower().ends_with(".csv") and not ruta.to_lower().ends_with(".html"):
		ruta += ".csv"
	var filas: Array = []
	for entrada in _entradas:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		var url := str(entrada.get("url", ""))
		var estado: Dictionary = _estados.get(GestorCatalogoScript.clave_unica(url), {})
		var estado_texto := "Sin comprobar"
		var fecha := 0
		var mensaje := ""
		if not estado.is_empty():
			estado_texto = "Válido" if estado.get("valido") == true else "Caído"
			fecha = int(estado.get("fecha", 0))
			mensaje = str(estado.get("mensaje", ""))
		filas.append({
			"nombre": str(entrada.get("nombre", "")),
			"url": url,
			"estado": estado_texto,
			"fecha": fecha,
			"mensaje": mensaje,
		})
	var res: Dictionary = InformeStoreScript.exportar_html(ruta, filas) if formato == "html" else InformeStoreScript.exportar_csv(ruta, filas)
	if not res.get("ok", false):
		progreso.text = str(res.get("error", "No se pudo guardar el informe."))
		return
	progreso.text = "Informe %s guardado (%d enlaces)." % [formato.to_upper(), int(res.get("total", 0))]


func _formato_informe(ruta: String) -> String:
	if ruta.to_lower().ends_with(".html"):
		return "html"
	return "csv"


func _on_diag_elegido(ruta: String) -> void:
	var base := "user://"
	if _logger != null:
		base = _logger_base()
	var res := DiagnosticoScript.exportar(ruta, base, str(ProjectSettings.get_setting("application/config/version", "0.0.1")), _entradas.size())
	if not res.get("ok", false):
		progreso.text = "No se pudo exportar el diagnóstico (%d errores)." % int(res.get("errores", 0))
		return
	_log_app("diagnostico", "diagnóstico exportado a " + ruta)
	progreso.text = "Diagnóstico guardado en %s." % ruta


func _logger_base() -> String:
	return _logger.get("_base") if _logger != null else "user://"


func _log_app(tipo: String, msg: String) -> void:
	if _logger != null:
		_logger.app(tipo, msg)


func _log_scan(url: String, resultado: String, detalle := "") -> void:
	if _logger != null:
		_logger.scan(url, resultado, detalle)


func _on_utilidades_id(id: int) -> void:
	if id == 0:
		ventana_agregar.abrir()
	elif id == 1:
		preferencias.abrir(_paralelismo, _timeout, _auto_abrir, _intervalo_auto)
	elif id == 2:
		_solicitar_limpieza_capturas()
	elif id == 3:
		%DialogoDiagnostico.popup_centered()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("atajo_buscar"):
		_on_atajo("atajo_buscar")
	elif event.is_action_pressed("atajo_agregar"):
		_on_atajo("atajo_agregar")
	elif event.is_action_pressed("atajo_comprobar"):
		_on_atajo("atajo_comprobar")
	elif event.is_action_pressed("ui_cancel"):
		_on_atajo("ui_cancel")


func _on_atajo(accion: String) -> void:
	match accion:
		"atajo_buscar":
			busqueda.grab_focus()
		"atajo_agregar":
			ventana_agregar.abrir()
		"atajo_comprobar":
			_comprobar_visibles()
		"ui_cancel":
			if ventana_agregar.visible:
				ventana_agregar.hide()
			elif preferencias.visible:
				preferencias.hide()


func _rutas_captura_referidas() -> Array:
	var rutas := {}
	for lista in [GestorDatosScript.cargar(DATA_RES), GestorDatosScript.cargar(DATA_USER), _entradas]:
		for entrada in lista:
			if typeof(entrada) != TYPE_DICTIONARY:
				continue
			var ruta := str(entrada.get("img", ""))
			if not ruta.is_empty():
				rutas[ruta] = true
	return rutas.keys()


func _hacer_limpieza_capturas() -> Dictionary:
	return GestorImagenesScript.limpiar_huerfanas(_rutas_captura_referidas())


func _solicitar_limpieza_capturas() -> void:
	var res := _hacer_limpieza_capturas()
	_limpieza_resultado = res
	if not res.get("ok", false):
		progreso.text = str(res.get("error", "No se pudo limpiar las capturas."))
		return
	var borradas := int(res.get("borradas", 0))
	if borradas == 0:
		progreso.text = "No hay capturas huérfanas."
		return
	%ConfirmarLimpieza.dialog_text = "¿Borrar %d capturas huérfanas?" % borradas
	%ConfirmarLimpieza.popup_centered()


func _confirmar_limpieza() -> void:
	var res := _limpieza_resultado
	_limpieza_resultado = {}
	var borradas := int(res.get("borradas", 0))
	var errores := int(res.get("errores", 0))
	var texto := "Capturas huérfanas eliminadas: %d" % borradas
	if errores > 0:
		texto += " (%d errores)" % errores
	progreso.text = texto


func _on_restaurar_copia() -> void:
	if not GestorDatosScript.hay_copia(DATA_USER) and not GestorDatosScript.hay_copia(DATA_RES):
		progreso.text = "No hay copia de seguridad disponible."
		return
	%ConfirmarRestaurar.popup_centered()


func _confirmar_restaurar() -> void:
	var ok_rest := true
	if not GestorDatosScript.restaurar_copia(DATA_USER):
		ok_rest = false
	if not GestorDatosScript.restaurar_copia(DATA_RES):
		ok_rest = false
	if not ok_rest:
		progreso.text = "No se pudo restaurar la copia."
		return
	_cargar_datos()
	_refrescar_vista()
	_actualizar_status()
	progreso.text = "Catálogo restaurado desde la copia."


func _exit_tree() -> void:
	_hacer_limpieza_capturas()


func _cargar_datos() -> void:
	var base := GestorDatosScript.cargar(DATA_RES)
	var usuario := GestorDatosScript.cargar(DATA_USER)
	_entradas = base
	if not usuario.is_empty():
		var urls := {}
		for entrada in _entradas:
			if typeof(entrada) == TYPE_DICTIONARY:
				urls[GestorCatalogoScript.clave_unica(str(entrada.get("url", "")))] = true
		for entrada in usuario:
			if typeof(entrada) != TYPE_DICTIONARY:
				continue
			var url := str(entrada.get("url", ""))
			if url.is_empty() or urls.has(GestorCatalogoScript.clave_unica(url)):
				continue
			_entradas.append(entrada)
			urls[GestorCatalogoScript.clave_unica(url)] = true

	_estado_store = EstadoStoreScript.new()
	var datos: Dictionary = _estado_store.cargar()
	_estados = datos.get("estados", {})
	_borrados = datos.get("borrados", [])
	_normalizar_urls()
	_entradas = _entradas.filter(
		func(entrada: Variant) -> bool:
			return typeof(entrada) != TYPE_DICTIONARY \
				or not _borrados.has(GestorCatalogoScript.clave_unica(str(entrada.get("url", ""))))
	)
	_normalizar_categorias()


func _normalizar_categorias() -> void:
	for entrada in _entradas:
		if typeof(entrada) == TYPE_DICTIONARY:
			entrada["cat"] = GestorCatalogoScript.normalizar_categoria(entrada.get("cat", ""))


func _normalizar_urls() -> void:
	var estados := {}
	for url_clave in _estados:
		estados[GestorCatalogoScript.clave_unica(str(url_clave))] = _estados[url_clave]
	_estados = estados
	var borrados_unicos := {}
	var borrados: Array = []
	for b in _borrados:
		var clave_b := GestorCatalogoScript.clave_unica(str(b))
		if clave_b.is_empty():
			continue
		if not borrados_unicos.has(clave_b):
			borrados_unicos[clave_b] = true
			borrados.append(clave_b)
	_borrados = borrados
	for entrada in _entradas:
		if typeof(entrada) == TYPE_DICTIONARY:
			entrada["url"] = GestorCatalogoScript.normalizar_url(str(entrada.get("url", "")))


func _guardar_datos() -> bool:
	if not _persistir:
		return true
	if not GestorDatosScript.guardar(DATA_USER, _entradas):
		progreso.text = "No se pudo guardar el enlace."
		return false
	GestorDatosScript.guardar(DATA_RES, _entradas)
	return true


func _on_enlace_guardado(datos: Dictionary) -> void:
	var url_nueva := GestorCatalogoScript.normalizar_url(str(datos.get("url", "")))
	var existente := _url_existente(url_nueva)
	if not existente.is_empty():
		progreso.text = "Ya existe: %s" % existente
		return
	datos["url"] = url_nueva
	datos["cat"] = GestorCatalogoScript.normalizar_categoria(datos.get("cat", "otro"))
	_entradas.append(datos)
	if not _guardar_datos():
		_entradas.pop_back()
		return
	_refrescar_vista()
	_actualizar_status()
	progreso.text = "Enlace agregado: %s" % datos.get("nombre", "")


func _on_lote_guardado(urls: Array) -> void:
	var canonicas: Array = []
	for linea in urls:
		var u: String = GestorCatalogoScript.normalizar_url(linea.strip_edges() if typeof(linea) == TYPE_STRING else "")
		if not u.is_empty():
			canonicas.append(u)
	var validas: Array = []
	var invalidas: Array = []
	for u in canonicas:
		if u.begins_with("http://") or u.begins_with("https://"):
			validas.append(u)
		else:
			invalidas.append(u)
	var res := GestorCatalogoScript.separar(validas, _urls_existentes())
	var nuevas: Array = res.get("nuevas", [])
	var repetidas: Array = res.get("repetidas", [])
	if nuevas.is_empty():
		var partes_vacias: Array = ["No se añadió ningún enlace."]
		if not repetidas.is_empty():
			partes_vacias.append("%d repetidas ignoradas." % repetidas.size())
		if not invalidas.is_empty():
			partes_vacias.append("%d inválidas ignoradas." % invalidas.size())
		progreso.text = " ".join(partes_vacias)
		return
	for u in nuevas:
		_entradas.append({
			"nombre": GestorCatalogoScript.dominio(u),
			"desc": "",
			"url": u,
			"img": "",
			"cat": "otro",
		})
	if not _guardar_datos():
		for i in range(nuevas.size()):
			_entradas.pop_back()
		progreso.text = "No se pudo guardar el lote."
		return
	var partes: Array = ["Se añadieron %d enlaces." % nuevas.size()]
	if not repetidas.is_empty():
		partes.append("%d repetidas ignoradas." % repetidas.size())
	if not invalidas.is_empty():
		partes.append("%d inválidas ignoradas." % invalidas.size())
	_refrescar_vista()
	_actualizar_status()
	progreso.text = " ".join(partes)


func _urls_existentes() -> Array:
	var urls: Array = []
	for entrada in _entradas:
		if typeof(entrada) == TYPE_DICTIONARY:
			urls.append(str(entrada.get("url", "")))
	return urls


func _url_existente(url: String) -> String:
	var clave := GestorCatalogoScript.clave_unica(url)
	for entrada in _entradas:
		if typeof(entrada) == TYPE_DICTIONARY:
			var c := GestorCatalogoScript.clave_unica(str(entrada.get("url", "")))
			if not c.is_empty() and c == clave:
				return str(entrada.get("url", ""))
	return ""


func _on_editar_pedido(item: Button) -> void:
	if not is_instance_valid(item):
		return
	var datos := _buscar_entrada(item.url)
	if datos.is_empty():
		progreso.text = "No se encontró el enlace."
		return
	ventana_agregar.abrir_edicion(datos, item.url)


func _buscar_entrada(url_entrada: String) -> Dictionary:
	for entrada in _entradas:
		if typeof(entrada) == TYPE_DICTIONARY and str(entrada.get("url", "")) == url_entrada:
			return entrada
	return {}


func _cambios_url_validos(url_original: String, url_nueva: String) -> bool:
	var existentes: Array = []
	for entrada in _entradas:
		if typeof(entrada) == TYPE_DICTIONARY and str(entrada.get("url", "")) != url_original:
			existentes.append(str(entrada.get("url", "")))
	var res := GestorCatalogoScript.separar([url_nueva], existentes)
	return (res.get("repetidas", []) as Array).is_empty()


func _on_enlace_editado(datos: Dictionary, url_original: String) -> void:
	var url_nueva := GestorCatalogoScript.normalizar_url(str(datos.get("url", "")))
	var indice := -1
	for i in range(_entradas.size()):
		if typeof(_entradas[i]) == TYPE_DICTIONARY and str(_entradas[i].get("url", "")) == url_original:
			indice = i
			break
	if indice == -1:
		progreso.text = "No se encontró el enlace."
		return
	var entrada: Dictionary = _entradas[indice]
	var img_anterior := str(entrada.get("img", ""))
	if url_nueva != url_original and not _cambios_url_validos(url_original, url_nueva):
		progreso.text = "Ya existe: %s" % url_nueva
		var datos_reabrir := datos.duplicate(true)
		datos_reabrir["img"] = img_anterior
		datos_reabrir.erase("img_pendiente")
		ventana_agregar.abrir_edicion(datos_reabrir, url_original)
		return
	if url_nueva != url_original:
		var clave_original := GestorCatalogoScript.clave_unica(url_original)
		var clave_nueva := GestorCatalogoScript.clave_unica(url_nueva)
		_estado_store.renombrar(clave_original, clave_nueva)
		if _estados.has(clave_original):
			_estados[clave_nueva] = _estados[clave_original]
			_estados.erase(clave_original)
		for i_b in range(_borrados.size()):
			if str(_borrados[i_b]) == clave_original:
				_borrados[i_b] = clave_nueva
	var destino := str(datos.get("img", ""))
	if datos.has("img_pendiente"):
		var resultado := GestorImagenesScript.copiar(str(datos["img_pendiente"]))
		if not resultado.get("ok", false):
			progreso.text = "No se pudo procesar la imagen."
			return
		destino = str(resultado.get("destino", ""))
	entrada["nombre"] = str(datos.get("nombre", ""))
	entrada["desc"] = str(datos.get("desc", ""))
	entrada["url"] = url_nueva
	entrada["img"] = destino
	entrada["cat"] = GestorCatalogoScript.normalizar_categoria(datos.get("cat", entrada.get("cat", "otro")))
	if not _guardar_datos():
		_cargar_datos()
		_refrescar_vista()
		progreso.text = "No se pudo guardar el enlace."
		return
	if destino != img_anterior:
		_borrar_captura_si_huerfana(img_anterior)
	_refrescar_vista()
	_actualizar_status()
	progreso.text = "Enlace actualizado: %s" % str(datos.get("nombre", ""))


func _borrar_captura_si_huerfana(ruta: String) -> void:
	if not (ruta.begins_with("res://Assets/png/") or ruta.begins_with("res://Assets/jpg/")):
		return
	if not ruta.get_file().begins_with("img_"):
		return
	for entrada in _entradas:
		if typeof(entrada) == TYPE_DICTIONARY and str(entrada.get("img", "")) == ruta:
			return
	GestorImagenesScript.borrar(ruta)


func _refrescar_vista() -> void:
	_mostrar_lista(_filtrar_busqueda(busqueda.text))


func _filtrar_busqueda(texto: String) -> Array:
	var filtro_texto := texto.strip_edges().to_lower()
	if filtro_texto.is_empty():
		return _entradas

	var filtradas: Array = []
	for entrada in _entradas:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		var haystack := "%s %s" % [entrada.get("nombre", ""), entrada.get("desc", "")]
		if filtro_texto in haystack.to_lower():
			filtradas.append(entrada)
	return filtradas


func _mostrar_lista(entradas: Array) -> void:
	_cola.clear()
	_en_vuelo = 0
	for hijo in lista.get_children():
		hijo.queue_free()

	for entrada in entradas:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		var item: Button = LIST_ITEM_SCENE.instantiate()
		item.setup(
			str(entrada.get("nombre", "")),
			str(entrada.get("desc", "")),
			str(entrada.get("url", "")),
			str(entrada.get("img", "")),
			GestorCatalogoScript.normalizar_categoria(entrada.get("cat", ""))
		)
		item.configurar_timeout(_timeout)
		var url_item := str(entrada.get("url", ""))
		var estado: Dictionary = _estados.get(GestorCatalogoScript.clave_unica(url_item), {})
		if not estado.is_empty():
			item.aplicar_estado(
				estado.get("valido"),
				str(estado.get("mensaje", "")),
				int(estado.get("codigo", 0)),
				int(estado.get("fecha", 0))
			)
		item.eliminar_pedido.connect(_on_eliminar_pedido.bind(item))
		item.recomprobar_pedido.connect(_on_recomprobar_pedido.bind(item))
		item.copiar_pedido.connect(_on_copiar_pedido.bind(item))
		item.editar_pedido.connect(_on_editar_pedido.bind(item))
		item.historial_pedido.connect(_on_historial_pedido.bind(item))
		lista.add_child(item)

	_aplicar_filtro()
	progreso.text = "%d enlaces" % lista.get_child_count()


func _actualizar_barra(hechos: int, total: int) -> void:
	%BarraProgreso.max_value = maxi(total, 1)
	%BarraProgreso.value = hechos


func _marcar_barra_final(caidos: int) -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.35, 0.85, 0.45, 1) if caidos == 0 else Color(0.95, 0.35, 0.35, 1)
	%BarraProgreso.add_theme_stylebox_override("fill", estilo)


func _persistir_cola() -> void:
	if _cola_store == null:
		return
	var urls: Array = []
	for item in _cola:
		if is_instance_valid(item):
			urls.append(item.url)
	_cola_store.guardar(urls)


func _comprobar_visibles() -> void:
	_cola.clear()
	for hijo in lista.get_children():
		if hijo.visible:
			_cola.append(hijo)

	_total = _cola.size()
	_hechos = 0
	_en_vuelo = 0
	if _total == 0:
		%BarraProgreso.visible = false
		progreso.text = "Nada que comprobar"
		return

	%BotonComprobar.disabled = true
	%BarraProgreso.visible = true
	%BarraProgreso.remove_theme_stylebox_override("fill")
	_actualizar_barra(0, _total)
	progreso.text = "Comprobando 0/%d…" % _total
	_persistir_cola()
	_lanzar_siguiente()


func _lanzar_siguiente() -> void:
	while _en_vuelo < _paralelismo and not _cola.is_empty():
		var item: Button = _cola.pop_front()
		if not is_instance_valid(item):
			continue
		_en_vuelo += 1
		item.verificacion_terminada.connect(_on_item_terminado.bind(item), CONNECT_ONE_SHOT)
		item.verificar()


func _on_item_terminado(item: Button) -> void:
	_en_vuelo = maxi(_en_vuelo - 1, 0)
	_hechos += 1
	_actualizar_barra(_hechos, _total)
	progreso.text = "Comprobando %d/%d…" % [_hechos, _total]
	var ahora := int(Time.get_unix_time_from_system())
	if is_instance_valid(item):
		var clave_estado := GestorCatalogoScript.clave_unica(item.url)
		_estado_store.guardar_estado(clave_estado, item.valido == true, item.mensaje, item.codigo)
		_estados[clave_estado] = {"valido": item.valido == true, "mensaje": item.mensaje, "codigo": item.codigo, "fecha": ahora}
		_log_scan(item.url, "valido" if item.valido == true else "caido", item.mensaje)
	_aplicar_filtro()
	_actualizar_status()
	if not _cola.is_empty() or _en_vuelo > 0:
		_lanzar_siguiente()
		_persistir_cola()
		return

	%BotonComprobar.disabled = false
	if _cola_store != null:
		_cola_store.limpiar()
	var caidos := 0
	for hijo in lista.get_children():
		if is_instance_valid(hijo) and hijo.valido == false:
			caidos += 1
	_marcar_barra_final(caidos)
	progreso.text = "Listo: %d caídos de %d" % [caidos, _total]


func _revisar_cola_pendiente() -> void:
	if _cola_store == null:
		return
	var pendientes: Array = _cola_store.cargar().get("urls", [])
	if pendientes.is_empty():
		return
	var set_catalogo := {}
	for entrada in _entradas:
		if typeof(entrada) == TYPE_DICTIONARY:
			set_catalogo[GestorCatalogoScript.clave_unica(str(entrada.get("url", "")))] = true
	var validas: Array = []
	for url in pendientes:
		if set_catalogo.has(GestorCatalogoScript.clave_unica(str(url))):
			validas.append(str(url))
	if validas.is_empty():
		_cola_store.limpiar()
		return
	%ConfirmarReanudar.dialog_text = "¿Reanudar escaneo de %d enlaces?" % validas.size()
	%ConfirmarReanudar.popup_centered()


func _reanudar_escaneo() -> void:
	if _cola_store == null:
		return
	var pendientes: Array = _cola_store.cargar().get("urls", [])
	if pendientes.is_empty():
		return
	_en_vuelo = 0
	_rearmar_cola_pendiente(pendientes)
	_total = _cola.size()
	if _total == 0:
		_cola_store.limpiar()
		%BotonComprobar.disabled = false
		return
	_hechos = 0
	%BotonComprobar.disabled = true
	%BarraProgreso.visible = true
	%BarraProgreso.remove_theme_stylebox_override("fill")
	_actualizar_barra(0, _total)
	progreso.text = "Comprobando 0/%d…" % _total
	_lanzar_siguiente()


func _rearmar_cola_pendiente(pendientes: Array) -> void:
	_cola.clear()
	for hijo in lista.get_children():
		if is_instance_valid(hijo) and pendientes.has(hijo.url):
			_cola.append(hijo)


func _descartar_cola_pendiente() -> void:
	if _cola_store != null:
		_cola_store.limpiar()


func _on_recomprobar_pedido(item: Button) -> void:
	if not is_instance_valid(item):
		return
	if item.estado == "comprobando":
		return
	progreso.text = "Re-comprobando %s…" % item.url
	item.verificacion_terminada.connect(_persistir_recompra.bind(item), CONNECT_ONE_SHOT)
	item.verificar()


func _persistir_recompra(item: Button) -> void:
	if not is_instance_valid(item):
		return
	var ahora := int(Time.get_unix_time_from_system())
	var clave_estado := GestorCatalogoScript.clave_unica(item.url)
	_estado_store.guardar_estado(clave_estado, item.valido == true, item.mensaje, item.codigo)
	_estados[clave_estado] = {"valido": item.valido == true, "mensaje": item.mensaje, "codigo": item.codigo, "fecha": ahora}
	_log_scan(item.url, "valido" if item.valido == true else "caido", item.mensaje)
	_aplicar_filtro()
	_actualizar_status()


func _on_eliminar_pedido(item: Button) -> void:
	_item_pendiente_borrar = item
	%ConfirmarBorrado.dialog_text = "¿Eliminar «%s» para siempre?" % item.get_node("Margen/Fila/Textos/NombreLabel").text
	%ConfirmarBorrado.popup_centered()


func _on_copiar_pedido(url: String, item: Button) -> void:
	if not is_instance_valid(item):
		return
	DisplayServer.clipboard_set(url)
	progreso.text = "URL copiada: %s" % url


func _confirmar_borrado() -> void:
	var item := _item_pendiente_borrar
	_item_pendiente_borrar = null
	if not is_instance_valid(item):
		return

	var clave_estado := GestorCatalogoScript.clave_unica(item.url)
	_estado_store.marcar_borrado(clave_estado)
	_estado_store.borrar_estado(clave_estado)
	_estados.erase(clave_estado)

	var imagen_borrada := ""
	for i in range(_entradas.size() - 1, -1, -1):
		if typeof(_entradas[i]) == TYPE_DICTIONARY and str(_entradas[i].get("url", "")) == item.url:
			imagen_borrada = str(_entradas[i].get("img", ""))
			_entradas.remove_at(i)

	item.queue_free()
	if (imagen_borrada.begins_with("res://Assets/png/") or imagen_borrada.begins_with("res://Assets/jpg/")) and imagen_borrada != "res://Assets/png/no-disponible.png":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(imagen_borrada))
	progreso.text = "Enlace eliminado"
	_aplicar_filtro()
	_actualizar_status()


func _aplicar_filtro() -> void:
	var modo := filtro.get_selected_id()
	var cat_id := filtro_cat.get_selected_id()
	var clave_cat := ""
	if cat_id > 0:
		clave_cat = GestorCatalogoScript.CATEGORIAS[cat_id - 1]
	for hijo in lista.get_children():
		var visible_estado := true
		match modo:
			1:
				visible_estado = hijo.valido == true
			2:
				visible_estado = hijo.valido == false
			3:
				visible_estado = hijo.valido == null
		hijo.visible = visible_estado and (cat_id == 0 or hijo.categoria == clave_cat)

	var modo_orden := orden_fecha.get_selected_id()
	if modo_orden > 0:
		var hijos: Array = lista.get_children()
		hijos.sort_custom(func(a: Button, b: Button) -> bool:
			return _comparar_orden(a, b, modo_orden)
		)
		for hijo in hijos:
			lista.move_child(hijo, -1)


func _on_busqueda_changed(_texto: String) -> void:
	_refrescar_vista()


func _actualizar_status() -> void:
	var c: Dictionary = ContadoresScript.contar(_entradas, _estados)
	rotos_label.text = "Rotos: %d" % c.get("rotos", 0)
	activos_label.text = "Activos: %d" % c.get("activos", 0)
	total_label.text = "Total: %d" % c.get("total", 0)


func _aplicar_preferencias(paralelismo: int, timeout: float, auto_abrir := true, intervalo := 0) -> void:
	_paralelismo = paralelismo
	_timeout = timeout
	_auto_abrir = auto_abrir
	_intervalo_auto = intervalo
	if not _config_store.guardar(paralelismo, timeout, auto_abrir, intervalo):
		progreso.text = "No se pudo guardar la configuración."
	_rearmar_auto_escaneo()
	if _auto_abrir and _puede_auto_escanear():
		_comprobar_visibles()


func _es_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _rearmar_auto_escaneo() -> void:
	if _es_headless() or _intervalo_auto <= 0:
		timer_auto.stop()
		return
	timer_auto.wait_time = float(_intervalo_auto * 60)
	timer_auto.start()


func _iniciar_auto_escaneo() -> void:
	if _es_headless() or not _auto_abrir:
		return
	await get_tree().create_timer(0.5).timeout
	if _puede_auto_escanear():
		_comprobar_visibles()
	_rearmar_auto_escaneo()


func _puede_auto_escanear() -> bool:
	return not _es_headless() and _cola.is_empty() and _en_vuelo == 0


func _on_auto_timer() -> void:
	if _puede_auto_escanear():
		_comprobar_visibles()


func _comparar_orden(a: Button, b: Button, modo: int) -> bool:
	var fa := int(a.fecha)
	var fb := int(b.fecha)
	if fa == fb:
		return a.url < b.url
	if fa == 0:
		return false
	if fb == 0:
		return true
	return fa > fb if modo == 1 else fa < fb


func _on_historial_pedido(item: Button) -> void:
	if not is_instance_valid(item):
		return
	var clave_estado := GestorCatalogoScript.clave_unica(item.url)
	dialogo_historial.abrir(_estado_store.historial_de(clave_estado))
