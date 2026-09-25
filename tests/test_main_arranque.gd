extends SceneTree

class _FakeHistorial extends RefCounted:
	func historial_de(_url: String) -> Array:
		return [{"fecha": 1000000000, "valido": true, "mensaje": "OK (200)", "codigo": 200}]

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const LIST_ITEM_SCENE := preload("res://scenes/ListItem.tscn")
const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
const TemaStoreScript := preload("res://scripts/tema_store.gd")
const ConfigStoreScript := preload("res://scripts/config_store.gd")

var _fallos := 0


func _initialize() -> void:
	_arrancar()

func _arrancar() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://__test_main_arranque__"))
	ConfigStoreScript.new("user://__test_main_arranque__").guardar(3, 10.0, false, 0, "oscuro", "", "", 1, "es")
	TranslationServer.set_locale("es")
	var main := MAIN_SCENE.instantiate()
	main.DATA_RES = "user://__test_main_arranque__/data.json"
	main.DATA_USER = "user://__test_main_arranque__/enlaces.json"
	main.CONFIG_BASE = "user://__test_main_arranque__"
	root.add_child(main)

	await process_frame
	await process_frame

	_check(main.has_node("%Rotos"), "la barra tiene el label Rotos")
	_check(main.has_node("%Activos"), "la barra tiene el label Activos")
	_check(main.has_node("%Total"), "la barra tiene el label Total")
	_check(main.has_node("%RotosValor"), "la barra tiene el label RotosValor")
	_check(main.has_node("%ActivosValor"), "la barra tiene el label ActivosValor")
	_check(main.has_node("%TotalValor"), "la barra tiene el label TotalValor")
	_check(main.has_node("%Version"), "la barra tiene el label Version")
	_check(main.has_node("%FiltroCodigo"), "la barra tiene el filtro de código HTTP")
	_check(main.has_node("%FiltroModo"), "la barra tiene el modo de búsqueda")
	_check(main.has_node("%FiltroDias"), "la barra tiene el filtro por días")

	if not main.has_node("%Rotos"):
		_cerrar()
		return

	_check(main.get_node("%Version").text.begins_with("v"), "la versión se muestra con prefijo v")
	_check(not main.get_node("%Rotos").text.is_empty(), "Rotos muestra su nombre")
	_check(not main.get_node("%RotosValor").text.is_empty(), "RotosValor muestra un valor")
	_check(not main.get_node("%Activos").text.is_empty(), "Activos muestra su nombre")
	_check(not main.get_node("%ActivosValor").text.is_empty(), "ActivosValor muestra un valor")
	_check(not main.get_node("%Total").text.is_empty(), "Total muestra su nombre")
	_check(not main.get_node("%TotalValor").text.is_empty(), "TotalValor muestra un valor")

	var main_script = main.get_node(".")
	if main_script.has_method("_scan_recompra"):
		main_script._estados.clear()
		var item = LIST_ITEM_SCENE.instantiate()
		item.url = "https://prueba-ejemplo.test"
		item.valido = false
		item.mensaje = "No existe"
		main_script._entradas.append({"nombre": "Prueba", "url": "https://prueba-ejemplo.test"})
		main_script._scan_recompra(item)
		var estado_memoria: Dictionary = main_script._estados.get(GestorCatalogoScript.clave_unica(item.url), {})
		_check(estado_memoria.has("codigo") and int(estado_memoria.get("codigo", -1)) == 0, "el estado en memoria conserva el código tras re-comprobar")
		_check(int(estado_memoria.get("fecha", 0)) > 0, "el estado en memoria conserva la fecha tras re-comprobar")
		main_script._estado_store.borrar_estado(GestorCatalogoScript.clave_unica(item.url))
		_check(main.get_node("%RotosValor").text == "1", "RotosValor se actualiza tras nueva comprobación")
		item.free()


	# Atajos de teclado (#14)
	_check(
		InputMap.has_action("atajo_buscar") and InputMap.has_action("atajo_agregar") and InputMap.has_action("atajo_comprobar"),
		"las acciones de los atajos están definidas"
	)

	var ev_f := InputEventKey.new()
	ev_f.keycode = KEY_F
	ev_f.physical_keycode = KEY_F
	ev_f.ctrl_pressed = true
	ev_f.pressed = true
	main_script._unhandled_input(ev_f)
	_check(main.get_viewport().gui_get_focus_owner() == main.get_node("%Busqueda") or main.get_node("%Busqueda").has_focus(), "Ctrl+F enfoca el buscador")

	var ev_n := InputEventKey.new()
	ev_n.keycode = KEY_N
	ev_n.physical_keycode = KEY_N
	ev_n.ctrl_pressed = true
	ev_n.pressed = true
	main_script._unhandled_input(ev_n)
	_check(main.get_node("%VentanaAgregar").visible, "Ctrl+N abre la ventana Agregar enlace")

	main_script._entradas = []
	main_script._ui_refrescar()
	for hijo in main.get_node("%ListaContenedor").get_children():
		hijo.visible = false
	var ev_r := InputEventKey.new()
	ev_r.keycode = KEY_R
	ev_r.physical_keycode = KEY_R
	ev_r.ctrl_pressed = true
	ev_r.pressed = true
	main_script._unhandled_input(ev_r)
	_check(main.get_node("%Progreso").text == "Nada que comprobar", "Ctrl+R dispara la comprobación")

	# Disponibilidad: historial desde la fila (#10)
	main_script._entradas = [
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""},
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": ""},
	]
	main_script._estados = {}
	main_script._ui_refrescar()
	await process_frame
	main_script._estado_store = _FakeHistorial.new()
	var fila_hist: Button = main.get_node("%ListaContenedor").get_child(0)
	main_script._ui_historial(fila_hist)
	_check(main.has_node("%DialogoHistorial") and main.get_node("%DialogoHistorial").visible, "el historial de la fila abre el diálogo")
	_check(main.get_node("%DialogoHistorial").get_node("%ListaHistorial").get_child_count() == 1, "el diálogo muestra una fila por entrada del historial")
	main.get_node("%DialogoHistorial").hide()

	# Disponibilidad: auto-escaneo desactivado en headless/intervalo 0 (#8)
	main_script._intervalo_auto = 0
	main_script._scan_rearmar_auto()
	_check(main.get_node("%AutoEscaneo").is_stopped(), "intervalo 0 deja el Timer detenido")
	main_script._intervalo_auto = 15
	main_script._scan_rearmar_auto()
	_check(main.get_node("%AutoEscaneo").is_stopped(), "en headless el intervalo no arranca el Timer")

	var ev_esc := InputEventKey.new()
	ev_esc.keycode = KEY_ESCAPE
	ev_esc.physical_keycode = KEY_ESCAPE
	ev_esc.pressed = true
	main_script._unhandled_input(ev_esc)
	_check(not main.get_node("%VentanaAgregar").visible, "Esc cierra la ventana Agregar enlace")

	# Regresión: ventanas nativas y arrastrables (por defecto embebidas en 4.7.2)
	main_script._persistir = false
	_check(
		ProjectSettings.has_setting("display/window/subwindows/embed_subwindows") \
		and not ProjectSettings.get_setting("display/window/subwindows/embed_subwindows"),
		"embed_subwindows está en false (ventanas no embebidas)"
	)

	_check(main.get_node("%DialogoDiagnostico") != null, "existe el diálogo DialogoDiagnostico")
	var menu_util: PopupMenu = main.get_node("%Utilidades")
	var tiene_diag := false
	for i in range(menu_util.item_count):
		if menu_util.get_item_text(i) == "Exportar diagnóstico…":
			tiene_diag = true
	_check(tiene_diag, "el menú Utilidades tiene la opción Exportar diagnóstico…")
	if main_script.has_method("_on_diag_elegido"):
		var ruta_zip := "user://__test_diag_main__.zip"
		var l = (load("res://scripts/logger.gd") as GDScript).new("user://__test_diag_main__")
		l.app("inicio", "arranque de prueba")
		l.scan("https://a.test", "valido", "OK (200)")
		l.flush()
		main_script._logger = l
		main_script._entradas = [{"nombre": "A", "url": "https://a.test"}]
		main_script._on_diag_elegido(ruta_zip)
		var z := ZIPReader.new()
		var ok_zip := z.open(ruta_zip) == OK
		if ok_zip:
			ok_zip = ("info.txt" in z.get_files()) and ("app.log" in z.get_files()) and ("scan.log" in z.get_files())
			z.close()
		_check(ok_zip, "_on_diag_elegido genera zip con info.txt y logs")
		DirAccess.remove_absolute("user://__test_diag_main__")
		DirAccess.remove_absolute(ruta_zip)

	# Tema claro/oscuro (#19)
	TemaStoreScript.aplicar("oscuro", main)
	_check(TemaStoreScript.color_estado(true) == Color(0.35, 0.85, 0.45, 1), "la paleta por defecto es la oscura")
	main_script._aplicar_preferencias(3, 10.0, false, 0, "claro")
	_check(main_script._config_store.cargar().get("tema", "") == "claro", "preferencias guardan el tema claro")
	_check(TemaStoreScript.color_estado(true) == Color(0.1, 0.55, 0.25, 1), "aplicar claro deja la paleta clara activa")
	var fondo_principal: ColorRect = main.get_node("Fondo")
	_check(fondo_principal.color == Color(0.95, 0.95, 0.95, 1), "aplicar claro pinta el fondo de la ventana principal")
	main_script._aplicar_preferencias(3, 10.0, false, 0, "oscuro")
	_check(main_script._config_store.cargar().get("tema", "") == "oscuro", "preferencias guardan el tema oscuro")
	_check(fondo_principal.color == Color(0.1, 0.1, 0.1, 1), "aplicar oscuro restaura el fondo original")

	# Idioma: al cambiar el idioma se re-traduce filas, barra, menús y filtros
	main_script._persistir = false
	main_script._entradas = [{"nombre": "SIN", "desc": "", "url": "https://sin.test", "img": ""}]
	main_script._estados = {"sin.test": {"valido": false, "mensaje": "No existe (404)", "codigo": 404, "fecha": 0}}
	main_script._ui_refrescar()
	main_script._aplicar_preferencias(3, 10.0, false, 0, "oscuro", "en")
	await process_frame
	var fila_en_i18n: Control = null
	for hijo in main.get_node("%ListaContenedor").get_children():
		if hijo.url == "https://sin.test":
			fila_en_i18n = hijo
			break
	_check(fila_en_i18n != null and fila_en_i18n.get_node("%EstadoLabel").text == "Does not exist (404)", "al cambiar a en la fila re-traduce el estado guardado")
	_check(main.get_node("%Rotos").text == "Broken:" and main.get_node("%RotosValor").text == "1", "al cambiar a en la barra de estado se re-traduce")
	var menu_file_i18n: PopupMenu = main.get_node("%File")
	_check(menu_file_i18n.get_item_text(menu_file_i18n.get_item_index(1)) == "Import…", "al cambiar a en el menú Archivo se re-traduce")
	var menu_util_i18n: PopupMenu = main.get_node("%Utilidades")
	_check(menu_util_i18n.get_item_text(menu_util_i18n.get_item_index(1)) == "Preferences…", "al cambiar a en el menú Utilidades se re-traduce")
	var filtro_estado_i18n: OptionButton = main.get_node("%FiltroEstado")
	_check(filtro_estado_i18n.get_item_text(0) == "All", "al cambiar a en el filtro de estado se re-traduce")
	main_script._aplicar_preferencias(3, 10.0, false, 0, "oscuro", "es")
	await process_frame
	var fila_es_i18n: Control = null
	for hijo in main.get_node("%ListaContenedor").get_children():
		if hijo.url == "https://sin.test":
			fila_es_i18n = hijo
			break
	_check(fila_es_i18n != null and fila_es_i18n.get_node("%EstadoLabel").text == "No existe (404)", "al volver a es la fila re-traduce el estado guardado")
	_check(main.get_node("%Rotos").text == "Rotos:" and main.get_node("%RotosValor").text == "1", "al volver a es la barra de estado se re-traduce")
	_check(filtro_estado_i18n.get_item_text(0) == "Todos", "al volver a es el filtro de estado se re-traduce")

	var filtro_codigo_ui: OptionButton = main.get_node("%FiltroCodigo")
	var indice_404 := 0
	for i in range(filtro_codigo_ui.item_count):
		if filtro_codigo_ui.get_item_id(i) == 404:
			indice_404 = i
	filtro_codigo_ui.select(indice_404)
	main_script._ui_filtro_codigo(0)
	_check(fila_es_i18n.visible, "el filtro por código 404 mantiene la fila 404 visible")
	filtro_codigo_ui.select(0)
	main_script._ui_filtro_codigo(0)
	var indice_500 := 0
	for i in range(filtro_codigo_ui.item_count):
		if filtro_codigo_ui.get_item_id(i) == 500:
			indice_500 = i
	filtro_codigo_ui.select(indice_500)
	main_script._ui_filtro_codigo(0)
	_check(not fila_es_i18n.visible, "el filtro por código 500 oculta la fila 404")
	filtro_codigo_ui.select(0)
	main_script._ui_filtro_codigo(0)

	# Actualización (#27): diálogo y comprobación en headless
	_check(main_script.has_method("_lanzar_comprobacion_auto"), "main tiene el disparo automático")
	_check(main.has_node("%DialogoActualizacion"), "existe el diálogo DialogoActualizacion")
	var menu_act: PopupMenu = main.get_node("%Utilidades")
	var tiene_act := false
	for i in range(menu_act.item_count):
		if menu_act.get_item_id(i) == 4 and menu_act.get_item_text(i) == "Comprobar actualizaciones…":
			tiene_act = true
	_check(tiene_act, "el menú Utilidades tiene Comprobar actualizaciones… (id 4)")

	main_script._comprobar_actualizaciones(true)
	_check(main.get_node("%DialogoActualizacion").visible, "en headless la comprobación manual abre el diálogo")
	_check(main.get_node("%DialogoActualizacion").dialog_text == "No se pudo comprobar actualizaciones.", "en headless el diálogo informa del fallo")
	main.get_node("%DialogoActualizacion").hide()

	main_script._config_store.guardar(3, 10.0, false, 0, "oscuro", "")
	main_script._on_actualizacion_terminado({"nueva": true, "version": "2.0", "url": "https://github.com/scorpio21/gestor-de-enlaces", "error": ""}, true)
	_check(main.get_node("%DialogoActualizacion").visible, "nueva versión abre el diálogo")
	_check(main.get_node("%DialogoActualizacion").dialog_text == "Hay una nueva versión: 2.0", "el diálogo muestra la versión nueva")
	_check(main.get_node("%DialogoActualizacion").ok_button_text == "Ver release", "el botón principal es Ver release")
	main_script._on_actualizacion_cerrar()
	_check(main_script._config_store.cargar().get("ultima_version_vista", "") == "2.0", "cerrar el aviso persiste la versión vista")
	main.get_node("%DialogoActualizacion").hide()

	main_script._on_actualizacion_terminado({"nueva": false, "version": "0.1.0", "url": "", "error": ""}, true)
	_check(main.get_node("%DialogoActualizacion").visible, "comprobación manual al día abre el diálogo")
	main.get_node("%DialogoActualizacion").hide()
	main_script._config_store.guardar(3, 10.0, false, 0, "oscuro", "")

	main_script._persistir = false
	_cerrar()


func _cerrar() -> void:
	var ruta_temp := ProjectSettings.globalize_path("user://__test_main_arranque__")
	for f in ["data.json", "enlaces.json"]:
		if FileAccess.file_exists(ruta_temp.path_join(f)):
			DirAccess.remove_absolute(ruta_temp.path_join(f))
	if DirAccess.dir_exists_absolute(ruta_temp):
		DirAccess.remove_absolute(ruta_temp)
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)