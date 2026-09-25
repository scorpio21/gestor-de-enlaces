extends Control

const LIST_ITEM_SCENE := preload("res://scenes/ListItem.tscn")
const GRID_ITEM_SCENE := preload("res://scenes/GridItem.tscn")
const TOPE_POR_HOST := 2
var DATA_RES := "res://data/data.json"
var DATA_USER := "user://enlaces.json"
const EstadoStoreScript := preload("res://scripts/estado_store.gd")
const ContadoresScript := preload("res://scripts/gestor_contadores.gd")
const ConfigStoreScript := preload("res://scripts/config_store.gd")
const IdiomaScript := preload("res://scripts/idioma.gd")
const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
const GestorImagenesScript := preload("res://scripts/gestor_imagenes.gd")
const GestorArchivoScript := preload("res://scripts/gestor_archivo.gd")
const GestorDatosScript := preload("res://scripts/gestor_datos.gd")
const LoggerScript := preload("res://scripts/logger.gd")
const DiagnosticoScript := preload("res://scripts/diagnostico.gd")
const ColaStoreScript := preload("res://scripts/cola_store.gd")
const InformeStoreScript := preload("res://scripts/informe_store.gd")
const TemaStoreScript := preload("res://scripts/tema_store.gd")
const ActualizadorScript := preload("res://scripts/actualizador.gd")
const OrdenadorScript := preload("res://scripts/ordenador.gd")
const FiltrosScript := preload("res://scripts/filtros.gd")
const CODIGOS_FILTRO := [200, 301, 302, 403, 404, 410, 500, 503]
const ColaEscaneoScript := preload("res://scripts/cola_escaneo.gd")
const EtiquetasScript := preload("res://scripts/etiquetas.gd")
const PresetsStoreScript := preload("res://scripts/presets_store.gd")

@onready var lista: VBoxContainer = %ListaContenedor
@onready var grilla: GridContainer = %GridContenedor
@onready var boton_vista: Button = %BotonVista
@onready var fila_cabeceras: HBoxContainer = %FilaCabeceras
@onready var busqueda: LineEdit = %Busqueda
@onready var filtro_cat: OptionButton = %FiltroCategoria
@onready var filtro_tag: OptionButton = %FiltroEtiqueta
@onready var filtro_codigo: OptionButton = %FiltroCodigo
@onready var filtro_dias: SpinBox = %FiltroDias
@onready var filtro_modo: OptionButton = %FiltroModo
@onready var preset_filtros: OptionButton = %PresetFiltros
@onready var boton_preset: Button = %BotonPreset
@onready var progreso: Label = %Progreso
@onready var filtro: OptionButton = %FiltroEstado
@onready var ventana_agregar = %VentanaAgregar
@onready var preferencias: Window = %VentanaPreferencias
@onready var dashboard: Window = %VentanaDashboard
@onready var rotos_label: Label = %Rotos
@onready var activos_label: Label = %Activos
@onready var total_label: Label = %Total
@onready var rotos_valor_label: Label = %RotosValor
@onready var activos_valor_label: Label = %ActivosValor
@onready var total_valor_label: Label = %TotalValor
@onready var version_label: Label = %Version
@onready var barra_progreso: ProgressBar = %BarraProgreso
@onready var cab_nombre: Button = %CabNombre
@onready var cab_estado: Button = %CabEstado
@onready var cab_fecha: Button = %CabFecha
@onready var cab_imagen: Button = %CabImagen
@onready var dialogo_historial: Window = %DialogoHistorial
@onready var timer_auto: Timer = %AutoEscaneo

var _entradas: Array = []
var _cola: Array[Button] = []
var _scan = ColaEscaneoScript.new()
var _estado_store: RefCounted
var _config_store: RefCounted
var CONFIG_BASE := "user://"
var _orden_columna := ""
var _orden_direccion := 1
var _modo_vista := "lista"
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
var _aviso_url := ""
var _dialogo_version := ""
var _dialogo_con_aviso := false
var _presets_store: RefCounted = null
var _presets: Dictionary = {}
var _boton_eliminar_preset: Button = null


func _ready() -> void:
	_configurar_menus()
	busqueda.text_changed.connect(_ui_busqueda)
	%BotonComprobar.pressed.connect(_scan_iniciar)
	%ConfirmarBorrado.confirmed.connect(_ui_confirmar_borrado)
	%ConfirmarLimpieza.confirmed.connect(_confirmar_limpieza)
	%ConfirmarRestaurar.confirmed.connect(_confirmar_restaurar)
	%ConfirmarReanudar.confirmed.connect(_scan_reanudar)
	%ConfirmarReanudar.canceled.connect(_scan_descartar_pendientes)
	cab_nombre.pressed.connect(func() -> void: _ui_cabecera("nombre"))
	cab_estado.pressed.connect(func() -> void: _ui_cabecera("estado"))
	cab_fecha.pressed.connect(func() -> void: _ui_cabecera("fecha"))
	cab_imagen.pressed.connect(func() -> void: _ui_cabecera("imagen"))
	timer_auto.timeout.connect(_scan_auto_timer)
	ventana_agregar.guardado.connect(_on_enlace_guardado)
	ventana_agregar.lote_guardado.connect(_on_lote_guardado)
	ventana_agregar.editado.connect(_on_enlace_editado)
	_cargar_datos()
	_config_store = ConfigStoreScript.new(CONFIG_BASE)
	_cola_store = ColaStoreScript.new()
	_presets_store = PresetsStoreScript.new(CONFIG_BASE)
	_presets = _presets_store.cargar()
	var cfg: Dictionary = _config_store.cargar()
	IdiomaScript.cargar_traducciones()
	TranslationServer.set_locale(IdiomaScript.aplicar(String(cfg.get("idioma", "")), OS.get_locale()))
	_paralelismo = clampi(int(cfg.get("paralelismo", 3)), 1, 8)
	_timeout = clampf(float(cfg.get("timeout", 10.0)), 3.0, 60.0)
	_auto_abrir = cfg.get("auto_abrir", true) == true
	_intervalo_auto = int(cfg.get("intervalo", 0))
	TemaStoreScript.aplicar(String(cfg.get("tema", "oscuro")), self)
	_orden_columna = str(cfg.get("orden_columna", ""))
	_orden_direccion = -1 if int(cfg.get("orden_direccion", 1)) < 0 else 1
	busqueda.text = str(cfg.get("busqueda", ""))
	_cargar_filtros()
	filtro.select(clampi(int(cfg.get("filtro_estado", 0)), 0, 3))
	filtro_cat.select(clampi(int(cfg.get("filtro_categoria", 0)), 0, GestorCatalogoScript.CATEGORIAS.size()))
	filtro_tag.select(_indice_etiqueta(String(cfg.get("filtro_etiqueta", ""))))
	filtro_codigo.select(_indice_codigo(String(cfg.get("filtro_codigo", ""))))
	filtro_modo.select(0 if str(cfg.get("busqueda_modo", "and")) == "and" else 1)
	filtro_dias.value = int(cfg.get("filtro_dias", 0))
	_modo_vista = "grilla" if str(cfg.get("vista", "lista")) == "grilla" else "lista"
	_presets_recargar_ui()
	boton_preset.pressed.connect(_ui_boton_preset)
	%DialogoPreset.confirmed.connect(_dialogo_preset_confirmado)
	_boton_eliminar_preset = %DialogoPreset.add_button(tr("Eliminar"))
	_boton_eliminar_preset.pressed.connect(_dialogo_preset_eliminar)
	boton_vista.pressed.connect(_ui_toggle_vista)
	grilla.resized.connect(_grilla_redimensionada)
	_ui_pintar_cabeceras()
	if _orden_columna != "":
		_ui_aplicar_filtro()
	preferencias.aplicado.connect(_aplicar_preferencias)
	%DialogoImportar.file_selected.connect(_on_importar_elegido)
	%DialogoExportar.file_selected.connect(_on_exportar_elegido)
	%DialogoInforme.file_selected.connect(_on_informe_elegido)
	if not _es_headless():
		_logger = LoggerScript.new("user://")
		_log_app("inicio", "aplicación iniciada")
	%DialogoDiagnostico.file_selected.connect(_on_diag_elegido)
	%DialogoImportar.access = FileDialog.ACCESS_FILESYSTEM
	%DialogoExportar.access = FileDialog.ACCESS_FILESYSTEM
	%DialogoInforme.access = FileDialog.ACCESS_FILESYSTEM
	%DialogoDiagnostico.access = FileDialog.ACCESS_FILESYSTEM
	_aplicar_vista()
	_ui_refrescar()
	version_label.text = "v" + str(ProjectSettings.get_setting("application/config/version", "0.0.1"))
	_ui_status()
	_scan_revisar_pendientes()
	_scan_rearmar_auto()
	_scan_iniciar_auto()
	%DialogoActualizacion.confirmed.connect(_on_actualizacion_ver)
	%DialogoActualizacion.canceled.connect(_on_actualizacion_cerrar)
	_lanzar_comprobacion_auto()


func _exit_tree() -> void:
	_hacer_limpieza_capturas()


func _es_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _configurar_menus() -> void:
	var menu_file: PopupMenu = %File
	menu_file.clear()
	menu_file.add_item(tr("Importar…"), 1)
	menu_file.add_item(tr("Exportar…"), 2)
	menu_file.add_item(tr("Informe de disponibilidad…"), 5)
	menu_file.add_separator()
	menu_file.add_item(tr("Restaurar copia…"), 4)
	menu_file.add_item(tr("Salir"), 3)
	if menu_file.id_pressed.is_connected(_on_file_id):
		menu_file.id_pressed.disconnect(_on_file_id)
	menu_file.id_pressed.connect(_on_file_id)

	var menu_util: PopupMenu = %Utilidades
	menu_util.clear()
	menu_util.add_item(tr("Agregar"), 0)
	menu_util.add_item(tr("Preferencias…"), 1)
	menu_util.add_item(tr("Limpiar capturas huérfanas…"), 2)
	menu_util.add_item(tr("Exportar diagnóstico…"), 3)
	menu_util.add_item(tr("Comprobar actualizaciones…"), 4)
	menu_util.add_item(tr("Dashboard de estadísticas…"), 5)
	if menu_util.id_pressed.is_connected(_on_utilidades_id):
		menu_util.id_pressed.disconnect(_on_utilidades_id)
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


func _on_utilidades_id(id: int) -> void:
	if id == 0:
		ventana_agregar.abrir(_sugerir_etiquetas())
	elif id == 1:
		preferencias.abrir(_paralelismo, _timeout, _auto_abrir, _intervalo_auto, String(_config_store.cargar().get("tema", "oscuro")), String(_config_store.cargar().get("idioma", "")))
	elif id == 2:
		_solicitar_limpieza_capturas()
	elif id == 3:
		%DialogoDiagnostico.popup_centered()
	elif id == 4:
		_comprobar_actualizaciones(true)
	elif id == 5:
		dashboard.abrir(_entradas, _estado_store.cargar().get("estados", {}))


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
			ventana_agregar.abrir(_sugerir_etiquetas())
		"atajo_comprobar":
			_scan_iniciar()
		"ui_cancel":
			if ventana_agregar.visible:
				ventana_agregar.hide()
			elif preferencias.visible:
				preferencias.hide()


func _sugerir_etiquetas() -> Array:
	return EtiquetasScript.frecuentes(_entradas, 8)


func _cargar_filtros() -> void:
	var sel_estado := filtro.get_selected()
	var sel_cat := filtro_cat.get_selected()
	var sel_tag := _etiqueta_seleccionada()
	filtro.clear()
	filtro.add_item(tr("Todos"), 0)
	filtro.add_item(tr("Válidos"), 1)
	filtro.add_item(tr("Caídos / no existen"), 2)
	filtro.add_item(tr("Sin comprobar"), 3)
	if filtro.item_selected.is_connected(_ui_filtro_estado):
		filtro.item_selected.disconnect(_ui_filtro_estado)
	filtro.item_selected.connect(_ui_filtro_estado)
	filtro.select(maxi(sel_estado, 0))
	filtro_cat.clear()
	filtro_cat.add_item(tr("Todas"), 0)
	for i in range(GestorCatalogoScript.CATEGORIAS.size()):
		filtro_cat.add_item(GestorCatalogoScript.new().categoria_display(GestorCatalogoScript.CATEGORIAS[i]), i + 1)
	if filtro_cat.item_selected.is_connected(_ui_filtro_categoria):
		filtro_cat.item_selected.disconnect(_ui_filtro_categoria)
	filtro_cat.item_selected.connect(_ui_filtro_categoria)
	filtro_cat.select(maxi(sel_cat, 0))
	filtro_tag.clear()
	filtro_tag.add_item(tr("Todas"), 0)
	for etiqueta in EtiquetasScript.frecuentes(_entradas, 0):
		filtro_tag.add_item(str(etiqueta), filtro_tag.item_count)
	if filtro_tag.item_selected.is_connected(_ui_filtro_etiqueta):
		filtro_tag.item_selected.disconnect(_ui_filtro_etiqueta)
	filtro_tag.item_selected.connect(_ui_filtro_etiqueta)
	filtro_tag.select(_indice_etiqueta(sel_tag))
	filtro_codigo.clear()
	filtro_codigo.add_item(tr("Todos"), 0)
	for codigo in CODIGOS_FILTRO:
		filtro_codigo.add_item(str(codigo), codigo)
	if filtro_codigo.item_selected.is_connected(_ui_filtro_codigo):
		filtro_codigo.item_selected.disconnect(_ui_filtro_codigo)
	filtro_codigo.item_selected.connect(_ui_filtro_codigo)
	filtro_modo.clear()
	filtro_modo.add_item(tr("Todas las palabras"), 0)
	filtro_modo.add_item(tr("Cualquier palabra"), 1)
	if filtro_modo.item_selected.is_connected(_ui_filtro_modo):
		filtro_modo.item_selected.disconnect(_ui_filtro_modo)
	filtro_modo.item_selected.connect(_ui_filtro_modo)
	filtro_dias.suffix = " " + tr("días")
	if filtro_dias.value_changed.is_connected(_ui_filtro_dias):
		filtro_dias.value_changed.disconnect(_ui_filtro_dias)
	filtro_dias.value_changed.connect(_ui_filtro_dias)


func _etiqueta_seleccionada() -> String:
	var id := filtro_tag.get_selected_id()
	if id > 0 and id < filtro_tag.item_count:
		return filtro_tag.get_item_text(id)
	return ""


func _codigo_seleccionado() -> String:
	return str(maxi(filtro_codigo.get_selected_id(), 0))


func _indice_codigo(clave: String) -> int:
	if clave.is_empty():
		return 0
	var codigo := int(clave)
	for i in range(1, filtro_codigo.item_count):
		if filtro_codigo.get_item_id(i) == codigo:
			return i
	return 0


func _modo_busqueda() -> String:
	return "or" if filtro_modo.get_selected_id() == 1 else "and"


func _indice_etiqueta(etiqueta: String) -> int:
	var clave := etiqueta.strip_edges().to_lower()
	for i in range(1, filtro_tag.item_count):
		if filtro_tag.get_item_text(i).to_lower() == clave:
			return i
	return 0


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


func _normalizar_categorias() -> void:
	for entrada in _entradas:
		if typeof(entrada) == TYPE_DICTIONARY:
			entrada["cat"] = GestorCatalogoScript.normalizar_categoria(entrada.get("cat", ""))
			entrada["tags"] = EtiquetasScript.parsear(entrada.get("tags", []))


func _ui_refrescar() -> void:
	_ui_mostrar_lista(FiltrosScript.filtrar(_entradas, busqueda.text, _modo_busqueda()))


func _ui_mostrar_lista(entradas: Array) -> void:
	_cola.clear()
	_scan.reiniciar()
	for hijo in _contenedor_activo().get_children():
		hijo.queue_free()

	for entrada in entradas:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		var item: Button = GRID_ITEM_SCENE.instantiate() if _modo_vista == "grilla" else LIST_ITEM_SCENE.instantiate()
		item.setup(
			str(entrada.get("nombre", "")),
			str(entrada.get("desc", "")),
			str(entrada.get("url", "")),
			str(entrada.get("img", "")),
			GestorCatalogoScript.normalizar_categoria(entrada.get("cat", ""))
		)
		item.tags = EtiquetasScript.parsear(entrada.get("tags", []))
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
		item.eliminar_pedido.connect(_ui_eliminar_fila.bind(item))
		item.recomprobar_pedido.connect(_scan_recomprobar.bind(item))
		item.copiar_pedido.connect(_ui_copiar_url.bind(item))
		item.editar_pedido.connect(_ui_editar_fila.bind(item))
		item.historial_pedido.connect(_ui_historial.bind(item))
		item.subir_pedido.connect(_ui_mover_fila.bind(item, -1))
		item.bajar_pedido.connect(_ui_mover_fila.bind(item, 1))
		item.menu_solicitado.connect(_ui_menu_fila.bind(item))
		_contenedor_activo().add_child(item)

	_ui_aplicar_filtro()
	progreso.text = tr("%d enlaces") % _contenedor_activo().get_child_count()


func _ui_aplicar_filtro() -> void:
	var modo := filtro.get_selected_id()
	var cat_id := filtro_cat.get_selected_id()
	var clave_cat := ""
	if cat_id > 0:
		clave_cat = GestorCatalogoScript.CATEGORIAS[cat_id - 1]
	var clave_tag := _etiqueta_seleccionada()
	var clave_codigo := ""
	var id_codigo := filtro_codigo.get_selected_id()
	if id_codigo > 0:
		clave_codigo = str(id_codigo)
	var fecha_minima := FiltrosScript.fecha_desde_dias(int(filtro_dias.value))
	for hijo in _contenedor_activo().get_children():
		hijo.visible = FiltrosScript.fila_visible(hijo.valido, hijo.categoria, modo, cat_id, clave_cat, hijo.tags, clave_tag, hijo.codigo, clave_codigo, hijo.fecha, fecha_minima)

	if _orden_columna != "":
		var hijos: Array = _contenedor_activo().get_children()
		hijos.sort_custom(func(a: Button, b: Button) -> bool:
			return OrdenadorScript.comparar(a, b, _orden_columna, _orden_direccion)
		)
		for hijo in hijos:
			_contenedor_activo().move_child(hijo, -1)


func _contenedor_activo() -> Node:
	return grilla if _modo_vista == "grilla" else lista


func _ui_toggle_vista() -> void:
	_modo_vista = "lista" if _modo_vista == "grilla" else "grilla"
	_aplicar_vista()
	_ui_refrescar()
	_persistir_filtros()


func _aplicar_vista() -> void:
	var es_grilla := _modo_vista == "grilla"
	lista.visible = not es_grilla
	grilla.visible = es_grilla
	fila_cabeceras.visible = not es_grilla
	boton_vista.text = tr("Vista lista") if es_grilla else tr("Vista grilla")
	if es_grilla:
		_grilla_redimensionada()


func _grilla_redimensionada() -> void:
	if not grilla.visible:
		return
	var n := clampi(floori(maxf(grilla.size.x, 620.0) / 170.0), 2, 8)
	if grilla.columns != n:
		grilla.columns = n


func _ui_busqueda(_texto: String) -> void:
	_ui_refrescar()
	_persistir_filtros()


func _ui_filtro_estado(_indice: int) -> void:
	_ui_aplicar_filtro()
	_persistir_filtros()


func _ui_filtro_categoria(_indice: int) -> void:
	_ui_aplicar_filtro()
	_persistir_filtros()


func _ui_filtro_etiqueta(_indice: int) -> void:
	_ui_aplicar_filtro()
	_persistir_filtros()


func _ui_filtro_codigo(_indice: int) -> void:
	_ui_aplicar_filtro()
	_persistir_filtros()


func _ui_filtro_dias(_valor: float) -> void:
	_ui_aplicar_filtro()
	_persistir_filtros()


func _ui_filtro_modo(_indice: int) -> void:
	_ui_refrescar()
	_persistir_filtros()


func _ui_preset_seleccionado(indice: int) -> void:
	if indice <= 0:
		preset_filtros.select(0)
		return
	_aplicar_preset(preset_filtros.get_item_text(indice))


func _aplicar_preset(nombre: String) -> void:
	var cfg: Dictionary = _presets_store.aplicar_preset(_presets, nombre)
	if cfg.is_empty():
		preset_filtros.select(0)
		return
	filtro.select(int(cfg.get("filtro_estado", 0)))
	filtro_cat.select(int(cfg.get("filtro_categoria", 0)))
	filtro_tag.select(_indice_etiqueta(str(cfg.get("filtro_etiqueta", ""))))
	filtro_codigo.select(_indice_codigo(str(cfg.get("filtro_codigo", ""))))
	filtro_modo.select(0 if str(cfg.get("busqueda_modo", "and")) == "and" else 1)
	filtro_dias.value = int(cfg.get("filtro_dias", 0))
	busqueda.text = str(cfg.get("busqueda", ""))
	_ui_refrescar()
	_persistir_filtros()
	preset_filtros.select(0)


func _ui_boton_preset() -> void:
	%NombrePreset.text = ""
	%DialogoPreset.popup_centered()
	%NombrePreset.grab_focus()


func _dialogo_preset_confirmado() -> void:
	var nombre: String = %NombrePreset.text.strip_edges()
	if not _presets_store.nombre_ok(nombre):
		progreso.text = tr("El nombre no puede estar vacío.")
		return
	_guardar_preset(nombre)


func _guardar_preset(nombre: String) -> bool:
	var presets_nuevos: Dictionary = _presets_store.guardar_preset(_presets, nombre, _config_filtros_actual())
	if presets_nuevos == _presets:
		progreso.text = tr("No se pudo guardar la configuración.")
		return false
	_presets = presets_nuevos
	_presets_store.guardar(_presets)
	_presets_recargar_ui()
	progreso.text = tr("Filtro guardado: %s") % nombre
	return true


func _dialogo_preset_eliminar() -> void:
	var nombre: String = %NombrePreset.text.strip_edges()
	if not _borrar_preset(nombre):
		progreso.text = tr("No existe ese filtro.")
		return
	%DialogoPreset.hide()


func _borrar_preset(nombre: String) -> bool:
	if not _presets.has(nombre):
		return false
	_presets = _presets_store.borrar_preset(_presets, nombre)
	_presets_store.guardar(_presets)
	_presets_recargar_ui()
	progreso.text = tr("Filtro eliminado: %s") % nombre
	return true


func _presets_recargar_ui() -> void:
	preset_filtros.clear()
	preset_filtros.add_item(tr("Presets…"), -1)
	for nombre in _presets_store.nombres(_presets):
		preset_filtros.add_item(str(nombre), preset_filtros.item_count)
	if preset_filtros.item_selected.is_connected(_ui_preset_seleccionado):
		preset_filtros.item_selected.disconnect(_ui_preset_seleccionado)
	preset_filtros.item_selected.connect(_ui_preset_seleccionado)
	preset_filtros.select(0)


func _config_filtros_actual() -> Dictionary:
	return {
		"filtro_estado": filtro.get_selected_id(),
		"filtro_categoria": filtro_cat.get_selected_id(),
		"filtro_etiqueta": _etiqueta_seleccionada(),
		"busqueda": busqueda.text,
		"filtro_codigo": _codigo_seleccionado(),
		"filtro_dias": int(filtro_dias.value),
		"busqueda_modo": _modo_busqueda(),
	}


func _ui_status() -> void:
	var c: Dictionary = ContadoresScript.contar(_entradas, _estados)
	rotos_label.text = tr("Rotos:")
	activos_label.text = tr("Activos:")
	total_label.text = tr("Total:")
	rotos_valor_label.text = str(c.get("rotos", 0))
	activos_valor_label.text = str(c.get("activos", 0))
	total_valor_label.text = str(c.get("total", 0))
	rotos_valor_label.add_theme_color_override("font_color", TemaStoreScript.color_estado(false))
	activos_valor_label.add_theme_color_override("font_color", TemaStoreScript.color_estado(true))
	total_valor_label.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0, 1))


func _ui_barra(hechos: int, total: int) -> void:
	%BarraProgreso.max_value = maxi(total, 1)
	%BarraProgreso.value = hechos


func _ui_barra_final(caidos: int) -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.35, 0.85, 0.45, 1) if caidos == 0 else Color(0.95, 0.35, 0.35, 1)
	%BarraProgreso.add_theme_stylebox_override("fill", estilo)


func _ui_pintar_cabeceras() -> void:
	var titulos := {"nombre": "Nombre", "estado": "Estado", "fecha": "Fecha", "imagen": "Imagen"}
	var flecha := "▼" if _orden_direccion == -1 else "▲"
	var pares := {
		"nombre": cab_nombre,
		"estado": cab_estado,
		"fecha": cab_fecha,
		"imagen": cab_imagen,
	}
	for col in pares:
		var boton: Button = pares[col]
		boton.button_pressed = _orden_columna == col
		boton.text = tr("%s %s") % [tr(titulos[col]), flecha] if _orden_columna == col else tr(titulos[col])


func _ui_cabecera(columna: String) -> void:
	var prev_col := _orden_columna
	var prev_dir := _orden_direccion
	if _orden_columna != columna:
		_orden_columna = columna
		_orden_direccion = OrdenadorScript.direccion_por_defecto(columna)
	elif _orden_direccion == OrdenadorScript.direccion_por_defecto(columna):
		_orden_direccion = -_orden_direccion
	else:
		_orden_columna = ""
	_ui_pintar_cabeceras()
	_ui_aplicar_filtro()
	if not _persistir_orden():
		_orden_columna = prev_col
		_orden_direccion = prev_dir
		_ui_pintar_cabeceras()
		_ui_aplicar_filtro()
		progreso.text = tr("No se pudo guardar el orden.")


func _ui_filas_visibles() -> Array:
	var visibles: Array = []
	for hijo in _contenedor_activo().get_children():
		if hijo.visible:
			visibles.append(hijo)
	return visibles


func _ui_menu_fila(item: Button) -> void:
	if _orden_columna != "":
		item.fijar_estado_reorden(false, false)
		return
	var visibles := _ui_filas_visibles()
	var idx := visibles.find(item)
	item.fijar_estado_reorden(idx > 0, idx >= 0 and idx < visibles.size() - 1)


func _ui_mover_fila(item: Button, delta: int) -> void:
	if _orden_columna != "":
		return
	var visibles := _ui_filas_visibles()
	var idx := visibles.find(item)
	if idx < 0:
		return
	var vecino_idx := idx + delta
	if vecino_idx < 0 or vecino_idx >= visibles.size():
		return
	var i := _indice_entrada(item.url)
	var j := _indice_entrada(visibles[vecino_idx].url)
	if i < 0 or j < 0:
		return
	var tmp = _entradas[i]
	_entradas[i] = _entradas[j]
	_entradas[j] = tmp
	if not _guardar_datos():
		_entradas[j] = _entradas[i]
		_entradas[i] = tmp
		progreso.text = tr("No se pudo guardar el orden.")
		return
	_ui_refrescar()
func _ui_historial(item: Button) -> void:
	if not is_instance_valid(item):
		return
	var clave_estado := GestorCatalogoScript.clave_unica(item.url)
	dialogo_historial.abrir(_estado_store.historial_de(clave_estado))


func _ui_eliminar_fila(item: Button) -> void:
	_item_pendiente_borrar = item
	%ConfirmarBorrado.dialog_text = tr("¿Eliminar «%s» para siempre?") % item.get_node("%NombreLabel").text
	%ConfirmarBorrado.popup_centered()


func _ui_confirmar_borrado() -> void:
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
	progreso.text = tr("Enlace eliminado")
	_ui_aplicar_filtro()
	_ui_status()


func _ui_copiar_url(url: String, item: Button) -> void:
	if not is_instance_valid(item):
		return
	DisplayServer.clipboard_set(url)
	progreso.text = tr("URL copiada: %s") % url


func _ui_editar_fila(item: Button) -> void:
	if not is_instance_valid(item):
		return
	var datos := _buscar_entrada(item.url)
	if datos.is_empty():
		progreso.text = tr("No se encontró el enlace.")
		return
	ventana_agregar.abrir_edicion(datos, item.url, _sugerir_etiquetas())


func _scan_iniciar() -> void:
	_cola.clear()
	for hijo in lista.get_children():
		if hijo.visible:
			_cola.append(hijo)

	_scan.configurar(_cola, _paralelismo, _scan_lanzar_item, TOPE_POR_HOST)
	if _scan.total == 0:
		%BarraProgreso.visible = false
		progreso.text = tr("Nada que comprobar")
		return

	%BotonComprobar.disabled = true
	%BarraProgreso.visible = true
	%BarraProgreso.remove_theme_stylebox_override("fill")
	_ui_barra(0, _scan.total)
	progreso.text = tr("Comprobando 0/%d…") % _scan.total
	_scan_persistir_cola()
	_scan.lanzar()


func _scan_lanzar_item(item: Button) -> void:
	item.verificacion_terminada.connect(_scan_item_terminado.bind(item), CONNECT_ONE_SHOT)
	item.verificar()


func _scan_item_terminado(item: Button) -> void:
	_scan.terminar(item)
	_ui_barra(_scan.hechos, _scan.total)
	progreso.text = tr("Comprobando %d/%d…") % [_scan.hechos, _scan.total]
	var ahora := int(Time.get_unix_time_from_system())
	if is_instance_valid(item):
		var clave_estado := GestorCatalogoScript.clave_unica(item.url)
		_estado_store.guardar_estado(clave_estado, item.valido == true, item.mensaje, item.codigo)
		_estados[clave_estado] = {"valido": item.valido == true, "mensaje": item.mensaje, "codigo": item.codigo, "fecha": ahora}
		_scan_log(item.url, "valido" if item.valido == true else "caido", item.mensaje)
	_ui_aplicar_filtro()
	_ui_status()
	if _scan.queda_trabajo():
		_scan.lanzar()
		_scan_persistir_cola()
		return

	%BotonComprobar.disabled = false
	if _cola_store != null:
		_cola_store.limpiar()
	var caidos := 0
	for hijo in lista.get_children():
		if is_instance_valid(hijo) and hijo.valido == false:
			caidos += 1
	_ui_barra_final(caidos)
	progreso.text = tr("Listo: %d caídos de %d") % [caidos, _scan.total]


func _scan_log(url: String, resultado: String, detalle := "") -> void:
	if _logger != null:
		_logger.scan(url, resultado, detalle)


func _scan_persistir_cola() -> void:
	if _cola_store == null:
		return
	var urls: Array = []
	for item in _cola:
		if is_instance_valid(item):
			urls.append(item.url)
	_cola_store.guardar(urls)


func _scan_recomprobar(item: Button) -> void:
	if not is_instance_valid(item):
		return
	if item.estado == "comprobando":
		return
	progreso.text = tr("Re-comprobando %s…") % item.url
	item.verificacion_terminada.connect(_scan_recompra.bind(item), CONNECT_ONE_SHOT)
	item.verificar()


func _scan_recompra(item: Button) -> void:
	if not is_instance_valid(item):
		return
	var ahora := int(Time.get_unix_time_from_system())
	var clave_estado := GestorCatalogoScript.clave_unica(item.url)
	_estado_store.guardar_estado(clave_estado, item.valido == true, item.mensaje, item.codigo)
	_estados[clave_estado] = {"valido": item.valido == true, "mensaje": item.mensaje, "codigo": item.codigo, "fecha": ahora}
	_scan_log(item.url, "valido" if item.valido == true else "caido", item.mensaje)
	_ui_aplicar_filtro()
	_ui_status()


func _scan_revisar_pendientes() -> void:
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
	%ConfirmarReanudar.dialog_text = tr("¿Reanudar escaneo de %d enlaces?") % validas.size()
	%ConfirmarReanudar.popup_centered()


func _scan_reanudar() -> void:
	if _cola_store == null:
		return
	var pendientes: Array = _cola_store.cargar().get("urls", [])
	if pendientes.is_empty():
		return
	_scan_rearmar_pendientes(pendientes)
	_scan.configurar(_cola, _paralelismo, _scan_lanzar_item, TOPE_POR_HOST)
	if _scan.total == 0:
		_cola_store.limpiar()
		%BotonComprobar.disabled = false
		return
	%BotonComprobar.disabled = true
	%BarraProgreso.visible = true
	%BarraProgreso.remove_theme_stylebox_override("fill")
	_ui_barra(0, _scan.total)
	progreso.text = tr("Comprobando 0/%d…") % _scan.total
	_scan.lanzar()


func _scan_rearmar_pendientes(pendientes: Array) -> void:
	_cola.clear()
	for hijo in lista.get_children():
		if is_instance_valid(hijo) and pendientes.has(hijo.url):
			_cola.append(hijo)


func _scan_descartar_pendientes() -> void:
	if _cola_store != null:
		_cola_store.limpiar()


func _scan_rearmar_auto() -> void:
	if _es_headless() or _intervalo_auto <= 0:
		timer_auto.stop()
		return
	timer_auto.wait_time = float(_intervalo_auto * 60)
	timer_auto.start()


func _scan_iniciar_auto() -> void:
	if _es_headless() or not _auto_abrir:
		return
	await get_tree().create_timer(0.5).timeout
	if _scan_auto_posible():
		_scan_iniciar()
	_scan_rearmar_auto()


func _scan_auto_posible() -> bool:
	return not _es_headless() and _cola.is_empty() and _scan.en_vuelo == 0


func _scan_auto_timer() -> void:
	if _scan_auto_posible():
		_scan_iniciar()


func _logger_base() -> String:
	return _logger.get("_base") if _logger != null else "user://"


func _log_app(tipo: String, msg: String) -> void:
	if _logger != null:
		_logger.app(tipo, msg)


func _on_importar_elegido(ruta: String) -> void:
	var res: Dictionary = GestorArchivoScript.importar(ruta, _urls_existentes())
	if not res.get("ok", false):
		progreso.text = str(res.get("error", "No se pudo importar el catálogo."))
		return
	var entradas: Array = res.get("entradas", [])
	var omitidas := int(res.get("omitidas", 0))
	if entradas.is_empty():
		progreso.text = tr("%d omitidos (ya existían o sin URL válida).") % omitidas
		return
	var importados := entradas.size()
	for entrada in entradas:
		_entradas.append(entrada)
	if not _guardar_datos():
		_cargar_datos()
		_ui_refrescar()
		progreso.text = tr("No se pudo guardar el catálogo.")
		return
	_ui_refrescar()
	_ui_status()
	progreso.text = tr("%d importados, %d omitidos.") % [importados, omitidas]


func _on_exportar_elegido(ruta: String) -> void:
	var res: Dictionary = GestorArchivoScript.exportar(ruta, _entradas)
	if not res.get("ok", false):
		progreso.text = str(res.get("error", "No se pudo exportar el catálogo."))
		return
	progreso.text = tr("Catálogo exportado (%d enlaces).") % int(res.get("total", 0))


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
	progreso.text = tr("Informe %s guardado (%d enlaces).") % [formato.to_upper(), int(res.get("total", 0))]


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
		progreso.text = tr("No se pudo exportar el diagnóstico (%d errores).") % int(res.get("errores", 0))
		return
	_log_app("diagnostico", "diagnóstico exportado a " + ruta)
	progreso.text = tr("Diagnóstico guardado en %s.") % ruta


func _on_enlace_guardado(datos: Dictionary) -> void:
	var url_nueva := GestorCatalogoScript.normalizar_url(str(datos.get("url", "")))
	var existente := _url_existente(url_nueva)
	if not existente.is_empty():
		progreso.text = tr("Ya existe: %s") % existente
		return
	datos["url"] = url_nueva
	datos["cat"] = GestorCatalogoScript.normalizar_categoria(datos.get("cat", "otro"))
	datos["tags"] = EtiquetasScript.parsear(datos.get("tags", []))
	_entradas.append(datos)
	if not _guardar_datos():
		_entradas.pop_back()
		return
	_ui_refrescar()
	_ui_status()
	progreso.text = tr("Enlace agregado: %s") % datos.get("nombre", "")


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
			partes_vacias.append(tr("%d repetidas ignoradas.") % repetidas.size())
		if not invalidas.is_empty():
			partes_vacias.append(tr("%d inválidas ignoradas.") % invalidas.size())
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
		progreso.text = tr("No se pudo guardar el lote.")
		return
	var partes: Array = [tr("Se añadieron %d enlaces.") % nuevas.size()]
	if not repetidas.is_empty():
		partes.append(tr("%d repetidas ignoradas.") % repetidas.size())
	if not invalidas.is_empty():
		partes.append(tr("%d inválidas ignoradas.") % invalidas.size())
	_ui_refrescar()
	_ui_status()
	progreso.text = " ".join(partes)


func _on_enlace_editado(datos: Dictionary, url_original: String) -> void:
	var url_nueva := GestorCatalogoScript.normalizar_url(str(datos.get("url", "")))
	var indice := -1
	for i in range(_entradas.size()):
		if typeof(_entradas[i]) == TYPE_DICTIONARY and str(_entradas[i].get("url", "")) == url_original:
			indice = i
			break
	if indice == -1:
		progreso.text = tr("No se encontró el enlace.")
		return
	var entrada: Dictionary = _entradas[indice]
	var img_anterior := str(entrada.get("img", ""))
	if url_nueva != url_original and not _cambios_url_validos(url_original, url_nueva):
		progreso.text = tr("Ya existe: %s") % url_nueva
		var datos_reabrir := datos.duplicate(true)
		datos_reabrir["img"] = img_anterior
		datos_reabrir.erase("img_pendiente")
		ventana_agregar.abrir_edicion(datos_reabrir, url_original, _sugerir_etiquetas())
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
			progreso.text = tr("No se pudo procesar la imagen.")
			return
		destino = str(resultado.get("destino", ""))
	entrada["nombre"] = str(datos.get("nombre", ""))
	entrada["desc"] = str(datos.get("desc", ""))
	entrada["url"] = url_nueva
	entrada["img"] = destino
	entrada["cat"] = GestorCatalogoScript.normalizar_categoria(datos.get("cat", entrada.get("cat", "otro")))
	entrada["tags"] = EtiquetasScript.parsear(datos.get("tags", entrada.get("tags", [])))
	if not _guardar_datos():
		_cargar_datos()
		_ui_refrescar()
		progreso.text = tr("No se pudo guardar el enlace.")
		return
	if destino != img_anterior:
		_borrar_captura_si_huerfana(img_anterior)
	_ui_refrescar()
	_ui_status()
	progreso.text = tr("Enlace actualizado: %s") % str(datos.get("nombre", ""))


func _guardar_datos() -> bool:
	if not _persistir:
		return true
	if not GestorDatosScript.guardar(DATA_USER, _entradas):
		progreso.text = tr("No se pudo guardar el enlace.")
		return false
	GestorDatosScript.guardar(DATA_RES, _entradas)
	return true


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


func _indice_entrada(url: String) -> int:
	for i in _entradas.size():
		var entrada: Dictionary = _entradas[i]
		if GestorCatalogoScript.clave_unica(str(entrada.get("url", ""))) == GestorCatalogoScript.clave_unica(url):
			return i
	return -1


func _borrar_captura_si_huerfana(ruta: String) -> void:
	if not (ruta.begins_with("res://Assets/png/") or ruta.begins_with("res://Assets/jpg/")):
		return
	if not ruta.get_file().begins_with("img_"):
		return
	for entrada in _entradas:
		if typeof(entrada) == TYPE_DICTIONARY and str(entrada.get("img", "")) == ruta:
			return
	GestorImagenesScript.borrar(ruta)


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
		progreso.text = tr("No hay capturas huérfanas.")
		return
	%ConfirmarLimpieza.dialog_text = tr("¿Borrar %d capturas huérfanas?") % borradas
	%ConfirmarLimpieza.popup_centered()


func _confirmar_limpieza() -> void:
	var res := _limpieza_resultado
	_limpieza_resultado = {}
	var borradas := int(res.get("borradas", 0))
	var errores := int(res.get("errores", 0))
	var texto := tr("Capturas huérfanas eliminadas: %d") % borradas
	if errores > 0:
		texto += tr(" (%d errores)") % errores
	progreso.text = texto


func _on_restaurar_copia() -> void:
	if not GestorDatosScript.hay_copia(DATA_USER) and not GestorDatosScript.hay_copia(DATA_RES):
		progreso.text = tr("No hay copia de seguridad disponible.")
		return
	%ConfirmarRestaurar.popup_centered()


func _confirmar_restaurar() -> void:
	var ok_rest := true
	if not GestorDatosScript.restaurar_copia(DATA_USER):
		ok_rest = false
	if not GestorDatosScript.restaurar_copia(DATA_RES):
		ok_rest = false
	if not ok_rest:
		progreso.text = tr("No se pudo restaurar la copia.")
		return
	_cargar_datos()
	_ui_refrescar()
	_ui_status()
	progreso.text = tr("Catálogo restaurado desde la copia.")


func _aplicar_preferencias(paralelismo: int, timeout: float, auto_abrir := true, intervalo := 0, tema := "oscuro", idioma := "es") -> void:
	var locale_anterior := TranslationServer.get_locale()
	_paralelismo = paralelismo
	_timeout = timeout
	_auto_abrir = auto_abrir
	_intervalo_auto = intervalo
	TemaStoreScript.aplicar(tema, self)
	TranslationServer.set_locale(idioma)
	if not _config_store.guardar(paralelismo, timeout, auto_abrir, intervalo, tema, "", "", 1, idioma, filtro.get_selected_id(), filtro_cat.get_selected_id(), _etiqueta_seleccionada(), busqueda.text, _codigo_seleccionado(), int(filtro_dias.value), _modo_busqueda(), _modo_vista):
		TranslationServer.set_locale(locale_anterior)
		progreso.text = tr("No se pudo guardar la configuración.")
	_retraducir_ui()
	_scan_rearmar_auto()
	if _auto_abrir and _scan_auto_posible():
		_scan_iniciar()


func _retraducir_ui() -> void:
	_configurar_menus()
	_cargar_filtros()
	_presets_recargar_ui()
	if _boton_eliminar_preset != null:
		_boton_eliminar_preset.text = tr("Eliminar")
	_ui_status()
	_ui_refrescar()
	boton_vista.text = tr("Vista lista") if _modo_vista == "grilla" else tr("Vista grilla")


func _persistir_orden() -> bool:
	var cfg: Dictionary = _config_store.cargar()
	return _config_store.guardar(
		int(cfg.get("paralelismo", 3)),
		float(cfg.get("timeout", 10.0)),
		bool(cfg.get("auto_abrir", true)),
		int(cfg.get("intervalo", 0)),
		str(cfg.get("tema", "oscuro")),
		str(cfg.get("ultima_version_vista", "")),
		_orden_columna,
		_orden_direccion,
		str(cfg.get("idioma", "")),
		filtro.get_selected_id(),
		filtro_cat.get_selected_id(),
		_etiqueta_seleccionada(),
		busqueda.text,
		_codigo_seleccionado(),
		int(filtro_dias.value),
		_modo_busqueda(),
		_modo_vista,
	)


func _persistir_filtros() -> bool:
	var cfg: Dictionary = _config_store.cargar()
	return _config_store.guardar(
		int(cfg.get("paralelismo", 3)),
		float(cfg.get("timeout", 10.0)),
		bool(cfg.get("auto_abrir", true)),
		int(cfg.get("intervalo", 0)),
		str(cfg.get("tema", "oscuro")),
		str(cfg.get("ultima_version_vista", "")),
		_orden_columna,
		_orden_direccion,
		str(cfg.get("idioma", "")),
		filtro.get_selected_id(),
		filtro_cat.get_selected_id(),
		_etiqueta_seleccionada(),
		busqueda.text,
		_codigo_seleccionado(),
		int(filtro_dias.value),
		_modo_busqueda(),
		_modo_vista,
	)


func _lanzar_comprobacion_auto() -> void:
	if _es_headless():
		return
	await get_tree().create_timer(1.0).timeout
	_comprobar_actualizaciones(false)


func _comprobar_actualizaciones(manual: bool) -> void:
	if _es_headless():
		if manual:
			_mostrar_aviso("error", "", "")
		return
	var actualizador: Node = ActualizadorScript.new()
	add_child(actualizador)
	actualizador.terminado.connect(func(r: Dictionary) -> void: _on_actualizacion_terminado(r, manual))
	actualizador.comprobar()


func _on_actualizacion_terminado(resultado: Dictionary, manual: bool) -> void:
	var nueva: bool = resultado.get("nueva") == true
	var version := str(resultado.get("version", ""))
	var url := str(resultado.get("url", ""))
	if nueva and version != str(_config_store.cargar().get("ultima_version_vista", "")):
		_mostrar_aviso("nueva", version, url)
	elif manual and not nueva and str(resultado.get("error", "")).is_empty():
		_mostrar_aviso("al_dia", str(ProjectSettings.get_setting("application/config/version", "0.0.1")), "")
	elif manual:
		_mostrar_aviso("error", "", "")


func _mostrar_aviso(modo: String, version: String, url: String) -> void:
	var dialogo: ConfirmationDialog = %DialogoActualizacion
	if modo == "nueva":
		dialogo.title = tr("Nueva versión disponible")
		dialogo.dialog_text = tr("Hay una nueva versión: %s") % version
		dialogo.ok_button_text = tr("Ver release")
		dialogo.get_cancel_button().visible = true
		_aviso_url = url
		_dialogo_version = version
		_dialogo_con_aviso = true
	elif modo == "al_dia":
		dialogo.title = tr("Comprobar actualizaciones")
		dialogo.dialog_text = tr("Estás al día (v%s)") % version
		dialogo.ok_button_text = tr("Cerrar")
		dialogo.get_cancel_button().visible = false
		_dialogo_con_aviso = false
	else:
		dialogo.title = tr("Comprobar actualizaciones")
		dialogo.dialog_text = tr("No se pudo comprobar actualizaciones.")
		dialogo.ok_button_text = tr("Cerrar")
		dialogo.get_cancel_button().visible = false
		_dialogo_con_aviso = false
	dialogo.popup_centered()


func _on_actualizacion_ver() -> void:
	if not _aviso_url.is_empty():
		OS.shell_open(_aviso_url)
	_persistir_version_vista()
	_limpiar_aviso()


func _on_actualizacion_cerrar() -> void:
	if _dialogo_con_aviso:
		_persistir_version_vista()
	_limpiar_aviso()


func _persistir_version_vista() -> void:
	var cfg: Dictionary = _config_store.cargar()
	_config_store.guardar(
		int(cfg.get("paralelismo", 3)),
		float(cfg.get("timeout", 10.0)),
		bool(cfg.get("auto_abrir", true)),
		int(cfg.get("intervalo", 0)),
		str(cfg.get("tema", "oscuro")),
		_dialogo_version,
		_orden_columna,
		_orden_direccion,
		str(cfg.get("idioma", "")),
		filtro.get_selected_id(),
		filtro_cat.get_selected_id(),
		_etiqueta_seleccionada(),
		busqueda.text,
		_codigo_seleccionado(),
		int(filtro_dias.value),
		_modo_busqueda(),
		_modo_vista,
	)


func _limpiar_aviso() -> void:
	_aviso_url = ""
	_dialogo_version = ""
	_dialogo_con_aviso = false


