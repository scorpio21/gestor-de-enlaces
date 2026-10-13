extends Control

const LIST_ITEM_SCENE := preload("res://scenes/ListItem.tscn")
const GRID_ITEM_SCENE := preload("res://scenes/GridItem.tscn")
const TOPE_POR_HOST := 2
const ESPERA_BUSQUEDA := 0.2
const RutasScript := preload("res://scripts/rutas.gd")
const CacheTexturasScript := preload("res://scripts/cache_texturas.gd")
var DATA_RES := RutasScript.CATALOGO_RES
var DATA_USER := "user://enlaces.json"
var ASSETS_BASE := RutasScript.ASSETS_USER:
	set(valor):
		ASSETS_BASE = valor
		var ventana := get_node_or_null("%VentanaAgregar")
		if ventana != null:
			ventana.ASSETS_BASE = valor
const EstadoStoreScript := preload("res://scripts/estado_store.gd")
const AlmacenControllerScript := preload("res://scripts/almacen_controller.gd")
const ContadoresScript := preload("res://scripts/gestor_contadores.gd")
const ConfigStoreScript := preload("res://scripts/config_store.gd")
const InstantaneaStoreScript := preload("res://scripts/instantanea_store.gd")
const SmokeScript := preload("res://scripts/smoke.gd")
const IdiomaScript := preload("res://scripts/idioma.gd")
const DialogosControllerScript := preload("res://scripts/dialogos_controller.gd")
const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
const GestorImagenesScript := preload("res://scripts/gestor_imagenes.gd")
const GestorDatosScript := preload("res://scripts/gestor_datos.gd")
const LoggerScript := preload("res://scripts/logger.gd")
const ColaStoreScript := preload("res://scripts/cola_store.gd")
const TemaStoreScript := preload("res://scripts/tema_store.gd")
const OrdenadorScript := preload("res://scripts/ordenador.gd")
const FiltrosScript := preload("res://scripts/filtros.gd")
const CODIGOS_FILTRO := [200, 301, 302, 403, 404, 410, 500, 503]
const ScanControllerScript := preload("res://scripts/scan_controller.gd")
const ListaControllerScript := preload("res://scripts/lista_controller.gd")
const ConfigControllerScript := preload("res://scripts/config_controller.gd")
const CatalogoControllerScript := preload("res://scripts/catalogo_controller.gd")
const EtiquetasScript := preload("res://scripts/etiquetas.gd")
const PresetsStoreScript := preload("res://scripts/presets_store.gd")
const CambiosControllerScript := preload("res://scripts/cambios_controller.gd")
const SeleccionControllerScript := preload("res://scripts/seleccion_controller.gd")
const RedireccionesScript := preload("res://scripts/redirecciones.gd")
const ThemeControllerScript := preload("res://scripts/theme_controller.gd")
const UpdateControllerScript := preload("res://scripts/update_controller.gd")
const NavigationControllerScript := preload("res://scripts/navigation_controller.gd")
const ImportExportControllerScript := preload("res://scripts/import_export_controller.gd")
const ScanUiControllerScript := preload("res://scripts/scan_ui_controller.gd")
const EdicionControllerScript := preload("res://scripts/edicion_controller.gd")

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
@onready var dialogo_cambios: Window = %DialogoCambios
@onready var timer_auto: Timer = %AutoEscaneo
@onready var barra_seleccion: FlowContainer = %BarraSeleccion

var _entradas: Array = []
var _scan = ScanControllerScript.new()
var _lista = ListaControllerScript.new()
var _config_ctrl = ConfigControllerScript.new()
var _catalogo = CatalogoControllerScript.new()
var _estado_store: RefCounted
var _config_store: RefCounted
var _instantanea_store: RefCounted = null
var _almacen: RefCounted = null
var CONFIG_BASE := "user://"
var _orden_columna := ""
var _orden_direccion := 1
var _logger = null
var _paralelismo := 3
var _timeout := 10.0
var _auto_abrir := true
var _intervalo_auto := 0
var _reintentar_transitorios := true
var _red_sin_comprobar := true
var _aceptar_certificados := false
var _instantaneas_dias := InstantaneaStoreScript.LIMITE_DEFAULT
var _estados := {}
var _borrados: Array = []
var _urls_informe: Array = []
var _persistir := true
var _cola_store: RefCounted = null
var _presets_store: RefCounted = null
var _presets: Dictionary = {}
var _boton_eliminar_preset: Button = null
var _aviso_base := ""
var _espera_busqueda: Timer = null
var _ultimo_repaint_ms := 0.0
var _filas_visibles := 0
var _cambios = CambiosControllerScript.new()
var _estado_previo := {}
var _sel = SeleccionControllerScript.new()
var _dialogos = DialogosControllerScript.new()
var _tema_ctrl: RefCounted = null
var _updates: RefCounted = null
var _nav: RefCounted = null
var _imp_exp: RefCounted = null
var _scan_ui: RefCounted = null
var _edicion: RefCounted = null


func _ready() -> void:
	if SmokeScript.arrancar_desde_consola(get_tree()):
		return
	_configurar_menus()
	_tema_ctrl = ThemeControllerScript.new(self, dashboard)
	_espera_busqueda = Timer.new()
	_espera_busqueda.one_shot = true
	_espera_busqueda.wait_time = ESPERA_BUSQUEDA
	_espera_busqueda.timeout.connect(_ui_busqueda_aplicar)
	add_child(_espera_busqueda)
	busqueda.text_changed.connect(_ui_busqueda)
	busqueda.text_submitted.connect(_ui_busqueda_enviada)
	busqueda.focus_exited.connect(_ui_busqueda_guardar)
	%ConfirmarLimpieza.confirmed.connect(_confirmar_limpieza)
	%ConfirmarRestaurar.confirmed.connect(_confirmar_restaurar)
	cab_nombre.pressed.connect(func() -> void: _ui_cabecera("nombre"))
	cab_estado.pressed.connect(func() -> void: _ui_cabecera("estado"))
	cab_fecha.pressed.connect(func() -> void: _ui_cabecera("fecha"))
	cab_imagen.pressed.connect(func() -> void: _ui_cabecera("imagen"))
	ventana_agregar.guardado.connect(_on_enlace_guardado)
	ventana_agregar.lote_guardado.connect(_on_lote_guardado)
	ventana_agregar.editado.connect(_on_enlace_editado)
	dialogo_cambios.filtrar_pedido.connect(_cambios_filtrar_lista)
	dialogo_cambios.dashboard_pedido.connect(_cambios_abrir_dashboard)
	%BotonSelTodos.pressed.connect(_sel_todo)
	%BotonSelComprobar.pressed.connect(_sel_comprobar)
	%BotonSelCopiar.pressed.connect(_sel_copiar)
	%BotonSelExportar.pressed.connect(_sel_exportar)
	%BotonSelEliminar.pressed.connect(_sel_eliminar)
	%BotonSelLimpiar.pressed.connect(_sel_limpiar)
	_sel.preparar(barra_seleccion, %SelContador, Callable(self, "_ui_filas_visibles"), Callable(self, "_urls_catalogo"))
	_abrir_almacen()
	_cargar_datos()
	_config_store = ConfigStoreScript.new(CONFIG_BASE, _almacen.para_stores())
	_updates = UpdateControllerScript.new(self, %DialogoActualizacion, _config_store, _config_ctrl, _dialogos, func() -> Array: return [_orden_columna, _orden_direccion])
	_instantanea_store = InstantaneaStoreScript.new(CONFIG_BASE, _almacen.para_stores())
	_nav = NavigationControllerScript.new(boton_vista, lista, grilla, fila_cabeceras, filtro, filtro_cat, busqueda, dashboard, progreso, _estado_store, _instantanea_store, func() -> void: _ui_refrescar(), func() -> bool: return _persistir_config(), func() -> Array: return _entradas)
	_imp_exp = ImportExportControllerScript.new(progreso, func() -> Array: return _entradas, func() -> Dictionary: return _estados, func() -> Array: return _urls_existentes(), func() -> bool: return _guardar_datos(), func() -> void: _cargar_datos(), func() -> void: _ui_refrescar(), func() -> void: _ui_status(), func() -> Array: return _tomar_urls_informe(), func() -> Dictionary: return _datos_diagnostico(), func(tipo: String, msg: String) -> void: _log_app(tipo, msg))
	dashboard.navegar.connect(_nav.navegar_dashboard)
	_cola_store = ColaStoreScript.new("user://", _almacen.para_stores())
	_scan = ScanControllerScript.new(_cola_store)
	_scan_ui = ScanUiControllerScript.new(
		func() -> RefCounted: return _scan,
		func() -> Node: return _contenedor_activo(),
		get_tree(),
		barra_progreso,
		progreso,
		%BotonComprobar,
		timer_auto,
		%ConfirmarReanudar,
		dialogo_cambios,
		func() -> RefCounted: return _estado_store,
		func() -> Dictionary: return _estados,
		func() -> Array: return _entradas,
		func() -> void: _instantanea_guardar(),
		func() -> void: _cambios_al_terminar(),
		func() -> void: _cambios_al_abrir(),
		func() -> void: _ui_aplicar_filtro(),
		func() -> void: _ui_status(),
		func() -> bool: return _es_headless(),
		func(url: String, resultado: String, detalle: String) -> void: _scan_log(url, resultado, detalle),
		func() -> bool: return _reintentar_transitorios,
		func() -> bool: return _red_sin_comprobar,
		func() -> bool: return _aceptar_certificados,
		func() -> bool: return _auto_abrir
	)
	_scan.configure(_scan_ui.lanzar_item)
	_scan.tope_por_host = TOPE_POR_HOST
	_scan.progreso.connect(_scan_ui.progreso_actualizado)
	_scan.item_actualizado.connect(_scan_ui.item_actualizado)
	_scan.terminado.connect(_scan_ui.terminado)
	%ConfirmarReanudar.confirmed.connect(_scan_ui.reanudar)
	%ConfirmarReanudar.canceled.connect(_scan_ui.descartar_pendientes)
	timer_auto.timeout.connect(_scan_ui.auto_timer)
	%BotonComprobar.pressed.connect(_scan_ui.iniciar)
	dashboard.comprobar_ya.connect(_scan_ui.iniciar)
	_edicion = EdicionControllerScript.new(
		func() -> String: return _orden_columna,
		func() -> Array: return _ui_filas_visibles(),
		func() -> Array: return _entradas,
		func() -> bool: return _guardar_datos(),
		func() -> void: _cargar_datos(),
		func() -> void: _ui_refrescar(),
		func() -> void: _ui_aplicar_filtro(),
		func() -> void: _ui_status(),
		func() -> void: _seleccion_conservar(),
		func(item) -> bool: return _fila_en_lista(item),
		func() -> Array: return _sugerir_etiquetas(),
		func() -> String: return ASSETS_BASE,
		func() -> RefCounted: return _catalogo,
		func() -> RefCounted: return _estado_store,
		func() -> Dictionary: return _estados,
		func() -> Array: return _borrados,
		func() -> RefCounted: return _dialogos,
		progreso,
		dialogo_historial,
		ventana_agregar,
		%ConfirmarBorrado,
		%ConfirmarReubicar,
		Callable(self, "_sel_al_clic"),
		Callable(_scan_ui, "recomprobar")
	)
	%ConfirmarBorrado.confirmed.connect(_edicion.confirmar_borrado)
	%ConfirmarBorrado.canceled.connect(_edicion.cancelar_borrado)
	%ConfirmarReubicar.confirmed.connect(_edicion.confirmar_reubicar)
	%ConfirmarReubicar.canceled.connect(_edicion.cancelar_reubicar)
	dashboard.actualizar_urls.connect(_edicion.pedir_reubicar_lote)
	_presets_store = PresetsStoreScript.new(CONFIG_BASE, _almacen.para_stores())
	_presets = _presets_store.cargar()
	var cfg: Dictionary = _config_store.cargar()
	IdiomaScript.cargar_traducciones()
	TranslationServer.set_locale(IdiomaScript.aplicar(String(cfg.get("idioma", "")), OS.get_locale()))
	_paralelismo = clampi(int(cfg.get("paralelismo", 3)), 1, 8)
	_timeout = clampf(float(cfg.get("timeout", 10.0)), 3.0, 60.0)
	_auto_abrir = cfg.get("auto_abrir", true) == true
	_intervalo_auto = int(cfg.get("intervalo", 0))
	_reintentar_transitorios = cfg.get("reintentar_transitorios", true) == true
	_red_sin_comprobar = cfg.get("red_sin_comprobar", true) == true
	_aceptar_certificados = cfg.get("aceptar_certificados", false) == true
	_instantaneas_dias = InstantaneaStoreScript.limite_ok(cfg.get("instantaneas_dias", InstantaneaStoreScript.LIMITE_DEFAULT))
	_scan.paralelismo = _paralelismo
	_scan.intervalo_auto = _intervalo_auto
	_scan.auto_abrir = _auto_abrir
	_scan.es_headless = _es_headless()
	_tema_ctrl.aplicar_tema(String(cfg.get("tema", "auto")))
	_tema_ctrl.conectar_cambio_tema(Callable(self, "_on_tema_sistema_cambio"))
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
	_nav.modo_vista = "grilla" if str(cfg.get("vista", "lista")) == "grilla" else "lista"
	_presets_recargar_ui()
	boton_preset.pressed.connect(_ui_boton_preset)
	%DialogoPreset.confirmed.connect(_dialogo_preset_confirmado)
	_boton_eliminar_preset = %DialogoPreset.add_button(tr("Eliminar"))
	_boton_eliminar_preset.pressed.connect(_dialogo_preset_eliminar)
	boton_vista.pressed.connect(_nav.toggle_vista)
	grilla.resized.connect(_nav.grilla_redimensionada)
	_ui_pintar_cabeceras()
	if _orden_columna != "":
		_ui_aplicar_filtro()
	preferencias.aplicado.connect(_aplicar_preferencias)
	%DialogoImportar.file_selected.connect(_imp_exp.importar)
	%DialogoExportar.file_selected.connect(_imp_exp.exportar)
	%DialogoInforme.file_selected.connect(_imp_exp.informe)
	if not _es_headless():
		_logger = LoggerScript.new("user://")
		_log_app("inicio", "aplicación iniciada")
	%DialogoDiagnostico.file_selected.connect(_imp_exp.diagnostico)
	%DialogoImportar.access = FileDialog.ACCESS_FILESYSTEM
	%DialogoExportar.access = FileDialog.ACCESS_FILESYSTEM
	%DialogoInforme.access = FileDialog.ACCESS_FILESYSTEM
	%DialogoDiagnostico.access = FileDialog.ACCESS_FILESYSTEM
	_nav.aplicar_vista()
	_ui_refrescar()
	version_label.text = "v" + str(ProjectSettings.get_setting("application/config/version", "0.0.1"))
	_ui_status()
	_scan_ui.revisar_pendientes()
	_scan_ui.rearmar_auto()
	_scan_ui.iniciar_auto()
	_updates.lanzar_auto()


func _exit_tree() -> void:
	if _config_store != null:
		_persistir_config()
	_lista.pool_vaciar()
	if _estado_store != null:
		_estado_store.volcar()
	_hacer_limpieza_capturas()
	if not _cambios.vistos():
		_cambios.guardar_pendientes(_cambios.pendientes_al_salir())


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
	menu_util.add_item(tr("Viendo cambios…"), 6)
	menu_util.add_item(tr("Purgar instantáneas antiguas…"), 7)
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
		preferencias.abrir(_paralelismo, _timeout, _auto_abrir, _intervalo_auto, String(_config_store.cargar().get("tema", "auto")), String(_config_store.cargar().get("idioma", "")), _reintentar_transitorios, _red_sin_comprobar, _aceptar_certificados, _instantaneas_dias)
	elif id == 2:
		_solicitar_limpieza_capturas()
	elif id == 3:
		%DialogoDiagnostico.popup_centered()
	elif id == 4:
		_updates.comprobar(true)
	elif id == 5:
		_nav.abrir_dashboard()
	elif id == 6:
		_cambios_ver()
	elif id == 7:
		_purgar_instantaneas()


func _purgar_instantaneas() -> void:
	var res: Dictionary = _instantanea_store.purgar(_instantaneas_dias)
	if not res.get("ok", false):
		progreso.text = tr("No se pudieron purgar las instantáneas.")
		return
	var borradas := int(res.get("borradas", 0))
	if borradas == 0:
		progreso.text = tr("No hay instantáneas más antiguas de %d días.") % _instantaneas_dias
		return
	progreso.text = tr("Instantáneas antiguas eliminadas: %d") % borradas


func _unhandled_input(event: InputEvent) -> void:
	var seleccion := SeleccionControllerScript.atajo_de(event)
	if not seleccion.is_empty():
		_on_seleccion(seleccion)
		return
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
			_scan_ui.iniciar()
		"ui_cancel":
			if ventana_agregar.visible:
				ventana_agregar.hide()
			elif preferencias.visible:
				preferencias.hide()
			else:
				_sel_limpiar()


func _on_seleccion(accion: String) -> void:
	match accion:
		"todo":
			_sel_todo()
		"copiar":
			_sel_copiar()
		"comprobar":
			_sel_comprobar()
		"eliminar":
			_sel_eliminar()
		"limpiar":
			_sel_limpiar()


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


func _abrir_almacen() -> void:
	# El almacenamiento se abre antes que nada: CONFIG_BASE decide de donde salen
	# enlaces.json, estados.json, config.json y las capturas, y todos los stores
	# se crean despues. Con -- --almacen=<ruta> se puede apuntar a otra carpeta
	# sin tocar el fichero de configuracion (#63).
	_almacen = AlmacenControllerScript.new(OS.get_cmdline_user_args())
	_almacen.aplicar_a(self)
	_cambios.almacen = _almacen.para_stores()
	for aviso in _almacen.avisos:
		push_warning(str(aviso))


func _cargar_datos() -> void:
	var base := GestorDatosScript.cargar(DATA_RES)
	var usuario: Array = _almacen.entradas_de(DATA_USER)
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

	_estado_store = EstadoStoreScript.new("user://", _almacen.para_stores())
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
	var inicio := Time.get_ticks_usec()
	_scan.reiniciar()
	_lista.cambiar_vista(_nav.modo_vista)
	var contenedor := _contenedor_activo()
	_lista.pool_devolver(contenedor)
	var escena: PackedScene = GRID_ITEM_SCENE if _nav.modo_vista == "grilla" else LIST_ITEM_SCENE

	for entrada in entradas:
		if typeof(entrada) != TYPE_DICTIONARY:
			continue
		var item: Button = _lista.pool_tomar()
		if item == null:
			item = escena.instantiate()
			_edicion.conectar_fila(item)
		item.setup(
			str(entrada.get("nombre", "")),
			str(entrada.get("desc", "")),
			str(entrada.get("url", "")),
			str(entrada.get("img", "")),
			GestorCatalogoScript.normalizar_categoria(entrada.get("cat", ""))
		)
		item.tags = EtiquetasScript.parsear(entrada.get("tags", []))
		item.configurar_timeout(_timeout)
		item.configurar_reintentos(_reintentar_transitorios, _red_sin_comprobar)
		item.configurar_certificados(_aceptar_certificados)
		var url_item := str(entrada.get("url", ""))
		var estado: Dictionary = _estados.get(GestorCatalogoScript.clave_unica(url_item), {})
		if not estado.is_empty():
			item.aplicar_estado(
				estado.get("valido"),
				str(estado.get("mensaje", "")),
				int(estado.get("codigo", 0)),
				int(estado.get("fecha", 0)),
				maxi(int(estado.get("intentos", 1)), 1),
				str(estado.get("motivo", "")),
				str(estado.get("url_final", ""))
			)
		if item.has_method("marcar_cambio"):
			item.marcar_cambio(_cambios.marca_de(GestorCatalogoScript.clave_unica(url_item)))
		item.seleccionar(_sel.contiene(url_item))
		contenedor.add_child(item)

	_ui_aplicar_filtro()
	_seleccion_conservar()
	progreso.text = tr("%d enlaces") % contenedor.get_child_count()
	_ultimo_repaint_ms = float(Time.get_ticks_usec() - inicio) / 1000.0
	_filas_visibles = contenedor.get_child_count()


func _fila_en_lista(item) -> bool:
	return is_instance_valid(item) and (item.get_parent() == lista or item.get_parent() == grilla)


func _ui_aplicar_filtro() -> void:
	_lista.configurar(
		filtro.get_selected_id(),
		filtro_cat.get_selected_id(),
		ListaControllerScript.clave_de_categoria(filtro_cat.get_selected_id()),
		_etiqueta_seleccionada(),
		ListaControllerScript.clave_de_codigo(filtro_codigo.get_selected_id()),
		int(filtro_dias.value),
		_orden_columna,
		_orden_direccion
	)
	_lista.aplicar(_contenedor_activo())


func _contenedor_activo() -> Node:
	return grilla if _nav.modo_vista == "grilla" else lista


func _ui_busqueda(_texto: String) -> void:
	_espera_busqueda.start()


func _ui_busqueda_aplicar() -> void:
	_ui_refrescar()


func _ui_busqueda_guardar() -> void:
	_persistir_config()


func _ui_busqueda_enviada(_texto: String) -> void:
	_espera_busqueda.stop()
	_ui_refrescar()
	_persistir_config()


func _ui_filtro_estado(_indice: int) -> void:
	_ui_aplicar_filtro()
	_persistir_config()


func _ui_filtro_categoria(_indice: int) -> void:
	_ui_aplicar_filtro()
	_persistir_config()


func _ui_filtro_etiqueta(_indice: int) -> void:
	_ui_aplicar_filtro()
	_persistir_config()


func _ui_filtro_codigo(_indice: int) -> void:
	_ui_aplicar_filtro()
	_persistir_config()


func _ui_filtro_dias(_valor: float) -> void:
	_ui_aplicar_filtro()
	_persistir_config()


func _ui_filtro_modo(_indice: int) -> void:
	_ui_refrescar()
	_persistir_config()


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
	_persistir_config()
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
	total_valor_label.add_theme_color_override("font_color", TemaStoreScript.color_clave("acento"))


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
	if not _persistir_config():
		_orden_columna = prev_col
		_orden_direccion = prev_dir
		_ui_pintar_cabeceras()
		_ui_aplicar_filtro()
		progreso.text = tr("No se pudo guardar el orden.")


func _ui_filas_visibles() -> Array:
	return _lista.filas_visibles(_contenedor_activo())


func _urls_visibles() -> Array:
	return SeleccionControllerScript.urls_de_filas(_ui_filas_visibles())


func _urls_catalogo() -> Array:
	return SeleccionControllerScript.urls_de_entradas(_entradas)


func _sel_al_clic(url: String, ctrl: bool, rango: bool, item: Button) -> void:
	if url.is_empty() or not _fila_en_lista(item):
		return
	_sel.pintar(_sel.alternar(url, ctrl, rango, _urls_visibles()))


func _sel_todo() -> void:
	_sel.pintar(_sel.seleccionar_todo(_urls_visibles()))


func _sel_limpiar() -> void:
	_sel.pintar(_sel.limpiar())


func _seleccion_conservar() -> void:
	_sel.pintar(_sel.conservar(_urls_catalogo()))


func _sel_urls() -> Array:
	return _sel.intersectar(_urls_catalogo())


func _sel_comprobar() -> void:
	var filas: Array = _sel.filas_de(_sel_urls())
	if filas.is_empty():
		return
	_scan_ui.arrancar(filas, filas)


func _sel_copiar() -> void:
	var urls := _sel_urls()
	if urls.is_empty():
		return
	DisplayServer.clipboard_set(SeleccionControllerScript.texto_urls(urls))
	progreso.text = SeleccionControllerScript.texto_copiadas(urls.size())


func _sel_exportar() -> void:
	var urls := _sel_urls()
	if urls.is_empty():
		return
	_urls_informe = urls
	%DialogoInforme.current_file = "seleccion.csv"
	%DialogoInforme.popup_centered()


func _sel_eliminar() -> void:
	_edicion.pedir_borrado(_sel_urls())


func _instantanea_guardar() -> void:
	if _instantanea_store == null:
		return
	_instantanea_store.guardar(_entradas, _estados, _instantaneas_dias)


func _cambios_al_terminar() -> void:
	var cambios := _cambios.nuevo_delta(_estado_previo, _estados)
	_estado_previo = _estados.duplicate(true)
	_cambios_mostrar(cambios)


func _cambios_al_abrir() -> void:
	_estado_previo = _estados.duplicate(true)
	_cambios_mostrar(_cambios.leer_pendientes())


func _cambios_ver() -> void:
	_cambios_mostrar(_cambios.leer_pendientes())


func _cambios_mostrar(cambios: Array) -> void:
	if _es_headless() or cambios.is_empty():
		return
	dialogo_cambios.abrir(cambios, _cambios.nombres_de(_entradas), _cambios.cobertura_de(_estados))
	_cambios.marcar_vistos()


func _cambios_filtrar_lista() -> void:
	filtro.select(2)
	_ui_aplicar_filtro()
	_persistir_config()


func _cambios_abrir_dashboard() -> void:
	_nav.abrir_dashboard()


func _scan_log(url: String, resultado: String, detalle := "") -> void:
	if _logger != null:
		_logger.scan(url, resultado, detalle)


func _logger_base() -> String:
	return _logger.get("_base") if _logger != null else "user://"


func _log_app(tipo: String, msg: String) -> void:
	if _logger != null:
		_logger.app(tipo, msg)


func _tomar_urls_informe() -> Array:
	var solo := _urls_informe.duplicate()
	_urls_informe = []
	return solo


func _datos_diagnostico() -> Dictionary:
	var base := "user://"
	if _logger != null:
		base = _logger_base()
	return {
		"base": base,
		"total": _entradas.size(),
		"datos": {
			"assets_lectura": RutasScript.ASSETS_RES,
			"assets_escritura": ASSETS_BASE,
			"catalogo_base": DATA_RES,
			"enlaces": DATA_USER,
			"config": CONFIG_BASE,
			"ui_filas": _filas_visibles,
			"ui_repaint_ms": "%.1f" % _ultimo_repaint_ms,
			"ui_cache_texturas": CacheTexturasScript.tamano(),
			"tls_aceptar_certificados": str(_aceptar_certificados),
			"tls_aviso": _tls_aviso(),
		},
	}


func _on_enlace_guardado(datos: Dictionary) -> void:
	var res: Dictionary = _catalogo.agregar(_entradas, datos)
	if not res.get("ok", false):
		progreso.text = str(res.get("mensaje", ""))
		return
	if not _guardar_datos():
		_entradas.pop_back()
		return
	_ui_refrescar()
	_ui_status()
	progreso.text = _estado_texto(str(res.get("mensaje", "")))
	if res.get("reutilizada", false):
		progreso.text += " · " + tr("Captura reutilizada")


func _on_lote_guardado(urls: Array) -> void:
	var res: Dictionary = _catalogo.agregar_lote(_entradas, urls)
	if not res.get("ok", false):
		progreso.text = str(res.get("mensaje", ""))
		return
	var nuevas := int(res.get("nuevas", 0))
	if not _guardar_datos():
		for i in range(nuevas):
			_entradas.pop_back()
		progreso.text = tr("No se pudo guardar el lote.")
		return
	_ui_refrescar()
	_ui_status()
	progreso.text = _estado_texto(str(res.get("mensaje", "")))


func _on_enlace_editado(datos: Dictionary, url_original: String) -> void:
	var res: Dictionary = _catalogo.editar(_entradas, _estados, _borrados, datos, url_original, ASSETS_BASE)
	if not res.get("ok", false):
		progreso.text = str(res.get("mensaje", ""))
		if res.has("reabrir"):
			ventana_agregar.abrir_edicion(res["reabrir"], url_original, _sugerir_etiquetas())
		return
	if not _guardar_datos():
		_cargar_datos()
		_ui_refrescar()
		progreso.text = tr("No se pudo guardar el enlace.")
		return
	var renombrar: Array = res.get("renombrar", [])
	if renombrar.size() == 2:
		_estado_store.renombrar(str(renombrar[0]), str(renombrar[1]))
	var img_anterior := str(res.get("img_anterior", ""))
	if str(res.get("img", "")) != img_anterior:
		_borrar_captura_si_huerfana(img_anterior)
	_ui_refrescar()
	_ui_status()
	progreso.text = _estado_texto(str(res.get("mensaje", "")))
	if res.get("reutilizada", false):
		progreso.text += " · " + tr("Captura reutilizada")


func _guardar_datos() -> bool:
	if not _persistir:
		return true
	if not _almacen.guardar_entradas_en(DATA_USER, _entradas):
		progreso.text = tr("No se pudo guardar el enlace.")
		return false
	_guardar_catalogo_base(RutasScript.es_escribible(DATA_RES))
	return true


func _guardar_catalogo_base(escribible: bool) -> void:
	if not escribible or not _aviso_base.is_empty():
		return
	if not GestorDatosScript.guardar(DATA_RES, _entradas):
		_aviso_base = tr("No se pudo escribir el catálogo base.")


func _estado_texto(texto: String) -> String:
	return "%s · %s" % [texto, _aviso_base] if not _aviso_base.is_empty() else texto


func _urls_existentes() -> Array:
	return _catalogo.urls_existentes(_entradas)


func _url_existente(url: String) -> String:
	return _catalogo.url_existente(_entradas, url)


func _buscar_entrada(url_entrada: String) -> Dictionary:
	return _catalogo.buscar_entrada(_entradas, url_entrada)


func _cambios_url_validos(url_original: String, url_nueva: String) -> bool:
	return _catalogo.cambios_url_validos(_entradas, url_original, url_nueva)


func _indice_entrada(url: String) -> int:
	return _catalogo.indice_entrada(_entradas, url)


func _es_captura_propia(ruta: String) -> bool:
	return _catalogo.es_captura_propia(ruta, ASSETS_BASE)


func _borrar_captura_si_huerfana(ruta: String) -> void:
	_catalogo.borrar_captura_si_huerfana(_entradas, ruta, ASSETS_BASE)


func _tls_aviso() -> int:
	var n := 0
	for clave in _estados.keys():
		var estado: Dictionary = _estados[clave]
		if estado.get("valido") == true and str(estado.get("motivo", "")) == "tls":
			n += 1
	return n


func _rutas_captura_referidas() -> Array:
	var rutas := {}
	for lista in [GestorDatosScript.cargar(DATA_RES), _almacen.entradas_de(DATA_USER), _entradas]:
		for entrada in lista:
			if typeof(entrada) != TYPE_DICTIONARY:
				continue
			var ruta := RutasScript.resolver(str(entrada.get("img", "")), ASSETS_BASE)
			if not ruta.is_empty():
				rutas[ruta] = true
	return rutas.keys()


func _hacer_limpieza_capturas() -> Dictionary:
	return GestorImagenesScript.limpiar_huerfanas(_rutas_captura_referidas(), ASSETS_BASE)


func _solicitar_limpieza_capturas() -> void:
	var res := _hacer_limpieza_capturas()
	if not res.get("ok", false):
		progreso.text = str(res.get("error", "No se pudo limpiar las capturas."))
		return
	var borradas := int(res.get("borradas", 0))
	if borradas == 0:
		progreso.text = tr("No hay capturas huérfanas.")
		return
	_dialogos.guardar_limpieza(res)
	%ConfirmarLimpieza.dialog_text = tr("¿Borrar %d capturas huérfanas?") % borradas
	%ConfirmarLimpieza.popup_centered()


func _confirmar_limpieza() -> void:
	var res: Dictionary = _dialogos.tomar_limpieza()
	CacheTexturasScript.limpiar()
	var borradas := int(res.get("borradas", 0))
	var errores := int(res.get("errores", 0))
	var texto := tr("Capturas huérfanas eliminadas: %d") % borradas
	if errores > 0:
		texto += tr(" (%d errores)") % errores
	progreso.text = texto


func _on_restaurar_copia() -> void:
	if not _almacen.hay_copia(DATA_USER) and not GestorDatosScript.hay_copia(DATA_RES):
		progreso.text = tr("No hay copia de seguridad disponible.")
		return
	%ConfirmarRestaurar.popup_centered()


func _confirmar_restaurar() -> void:
	var ok_rest := true
	if not _almacen.restaurar_copia(DATA_USER):
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


func _aplicar_preferencias(paralelismo: int, timeout: float, auto_abrir := true, intervalo := 0, tema := "auto", idioma := "es", reintentar_transitorios := true, red_sin_comprobar := true, aceptar_certificados := false, instantaneas_dias := 0) -> void:
	var locale_anterior := TranslationServer.get_locale()
	_paralelismo = paralelismo
	_timeout = timeout
	_auto_abrir = auto_abrir
	_intervalo_auto = intervalo
	_reintentar_transitorios = reintentar_transitorios
	_red_sin_comprobar = red_sin_comprobar
	_aceptar_certificados = aceptar_certificados
	_instantaneas_dias = InstantaneaStoreScript.limite_ok(instantaneas_dias) if instantaneas_dias > 0 else _instantaneas_dias
	_scan.paralelismo = _paralelismo
	_scan.intervalo_auto = _intervalo_auto
	_scan.auto_abrir = _auto_abrir
	_tema_ctrl.aplicar_tema(tema)
	TranslationServer.set_locale(idioma)
	var cambios := _config_desde_ui()
	cambios["paralelismo"] = paralelismo
	cambios["timeout"] = timeout
	cambios["auto_abrir"] = auto_abrir
	cambios["intervalo"] = intervalo
	cambios["tema"] = tema
	cambios["ultima_version_vista"] = ""
	cambios["orden_columna"] = ""
	cambios["orden_direccion"] = 1
	cambios["idioma"] = idioma
	cambios["reintentar_transitorios"] = reintentar_transitorios
	cambios["red_sin_comprobar"] = red_sin_comprobar
	cambios["aceptar_certificados"] = aceptar_certificados
	cambios["instantaneas_dias"] = _instantaneas_dias
	if not _config_ctrl.guardar(_config_store, cambios):
		TranslationServer.set_locale(locale_anterior)
		progreso.text = tr("No se pudo guardar la configuración.")
	_retraducir_ui()
	_scan_ui.rearmar_auto()
	if _scan.auto_abrir and _scan.auto_posible():
		_scan_ui.iniciar()


func _on_tema_sistema_cambio() -> void:
	var cfg: Dictionary = _config_store.cargar()
	if str(cfg.get("tema", "auto")) == "auto":
		_tema_ctrl.aplicar_tema("auto")


func _retraducir_ui() -> void:
	_configurar_menus()
	_cargar_filtros()
	_presets_recargar_ui()
	if _boton_eliminar_preset != null:
		_boton_eliminar_preset.text = tr("Eliminar")
	_ui_status()
	_ui_refrescar()
	_nav.aplicar_vista()


func _config_desde_ui() -> Dictionary:
	return {
		"orden_columna": _orden_columna,
		"orden_direccion": _orden_direccion,
		"filtro_estado": filtro.get_selected_id(),
		"filtro_categoria": filtro_cat.get_selected_id(),
		"filtro_etiqueta": _etiqueta_seleccionada(),
		"busqueda": busqueda.text,
		"filtro_codigo": _codigo_seleccionado(),
		"filtro_dias": int(filtro_dias.value),
		"busqueda_modo": _modo_busqueda(),
		"vista": _nav.modo_vista,
	}


func _persistir_config() -> bool:
	return _config_ctrl.guardar(_config_store, _config_desde_ui())
