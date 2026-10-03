extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const Ayuda := preload("res://tests/ayuda.gd")
const LIST_ITEM_SCENE := preload("res://scenes/ListItem.tscn")
const ConfigStoreScript := preload("res://scripts/config_store.gd")
const EstadoStoreScript := preload("res://scripts/estado_store.gd")
const ScanControllerScript := preload("res://scripts/scan_controller.gd")
const InformeControllerScript := preload("res://scripts/informe_controller.gd")

var _fallos := 0


func _scan_controller_nuevo(store, main_script) -> RefCounted:
	var ctrl = ScanControllerScript.new(store)
	ctrl.configure(Callable(main_script, "_scan_lanzar_item"))
	ctrl.tope_por_host = main_script.TOPE_POR_HOST
	ctrl.progreso.connect(Callable(main_script, "_scan_progreso"))
	ctrl.item_actualizado.connect(Callable(main_script, "_scan_item_actualizado"))
	ctrl.terminado.connect(Callable(main_script, "_scan_terminado"))
	return ctrl


func _initialize() -> void:
	_arrancar()

func _arrancar() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://__test_main_flujos__"))
	ConfigStoreScript.new("user://__test_main_flujos__").guardar(3, 10.0, false, 0, "oscuro", "", "", 1, "es")
	TranslationServer.set_locale("es")
	var main := MAIN_SCENE.instantiate()
	main.DATA_RES = "user://__test_main_flujos__/data.json"
	main.DATA_USER = "user://__test_main_flujos__/enlaces.json"
	main.CONFIG_BASE = "user://__test_main_flujos__"
	root.add_child(main)
	main.ASSETS_BASE = "user://__test_main_flujos__/Assets"

	await process_frame
	await process_frame

	_check(main.has_node("%Rotos"), "la barra tiene el label Rotos")
	_check(main.has_node("%Activos"), "la barra tiene el label Activos")
	_check(main.has_node("%Total"), "la barra tiene el label Total")
	_check(main.has_node("%Version"), "la barra tiene el label Version")

	if not main.has_node("%Rotos"):
		_cerrar()
		return

	_check(main.get_node("%Version").text.begins_with("v"), "la versión se muestra con prefijo v")
	_check(not main.get_node("%Rotos").text.is_empty(), "Rotos muestra un valor")
	_check(not main.get_node("%Activos").text.is_empty(), "Activos muestra un valor")
	_check(not main.get_node("%Total").text.is_empty(), "Total muestra un valor")

	var main_script = main.get_node(".")

	# Catálogo: copiar URL desde la fila informa en la barra
	main_script._entradas = [{"nombre": "Copiar", "desc": "", "url": "https://copiar.test", "img": ""}]
	main_script._ui_refrescar()
	await process_frame
	var fila = main.get_node("%ListaContenedor").get_child(0)
	fila.copiar_pedido.emit(fila.url)
	_check(main.get_node("%Progreso").text == "URL copiada: https://copiar.test", "copiar desde la fila informa en la barra")

	_check(not main.get_node("%BarraProgreso").visible, "la barra de progreso nace oculta")
	main_script._ui_barra(3, 5)
	_check(main.get_node("%BarraProgreso").value == 3, "la barra refleja los enlaces comprobados")
	_check(main.get_node("%BarraProgreso").max_value == 5, "la barra usa el total de enlaces como máximo")
	main_script._ui_barra_final(0)
	var verde: StyleBoxFlat = main.get_node("%BarraProgreso").get_theme_stylebox("fill")
	_check(verde.bg_color.is_equal_approx(Color(0.35, 0.85, 0.45, 1)), "con 0 caídos la barra se pone verde")
	main_script._ui_barra_final(2)
	var rojo: StyleBoxFlat = main.get_node("%BarraProgreso").get_theme_stylebox("fill")
	_check(rojo.bg_color.is_equal_approx(Color(0.95, 0.35, 0.35, 1)), "con caídos la barra se pone roja")
	for hijo in main.get_node("%ListaContenedor").get_children():
		hijo.visible = false
	main_script._scan_iniciar()
	_check(not main.get_node("%BarraProgreso").visible, "sin enlaces visibles la barra se oculta")
	_check(main.get_node("%Progreso").text == "Nada que comprobar", "sin enlaces visibles se muestra el aviso")

	# Cola persistida y reanudación (#13) — la lógica vive ya en ScanController (#62)
	var store_cola = (load("res://scripts/cola_store.gd") as GDScript).new("user://__test_main__")
	main_script._cola_store = store_cola
	main_script._scan = _scan_controller_nuevo(store_cola, main_script)

	var item_a: Button = LIST_ITEM_SCENE.instantiate()
	item_a.url = "https://a.test"
	var item_c: Button = LIST_ITEM_SCENE.instantiate()
	item_c.url = "https://c.test"
	main_script._scan.preparar([item_a, item_c])
	var cola_guardada: Array = store_cola.cargar().get("urls", [])
	_check(cola_guardada.size() == 2 and "https://a.test" in cola_guardada and "https://c.test" in cola_guardada, "persistir cola guarda las urls de los items")
	item_a.free()
	item_c.free()
	store_cola.limpiar()

	main_script._entradas = [
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""},
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": ""},
	]
	main_script._ui_refrescar()
	await process_frame
	_check(main.has_node("%ConfirmarReanudar"), "el diálogo ConfirmarReanudar existe en Main.tscn")
	var filas: Node = main.get_node("%ListaContenedor")
	main_script._scan.preparar([], filas.get_children())
	main_script._scan.rearmar_pendientes(["https://b.test"])
	var cola_reanudada: Array = main_script._scan.cola()
	_check(cola_reanudada.size() == 1 and cola_reanudada[0].url == "https://b.test", "reanudar reconstruye la cola con solo las urls pendientes")

	store_cola.guardar(["https://nope.test"])
	main_script._entradas = []
	main_script._scan.preparar([], filas.get_children())
	main_script._scan_reanudar()
	_check((main_script._scan.cola() as Array).is_empty() and (store_cola.cargar().get("urls", []) as Array).is_empty(), "reanudar con urls inexistentes descarta y limpia")
	DirAccess.remove_absolute("user://__test_main__")

	# Catálogo: categorías (persistencia y normalización)
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""}]
	main_script._on_lote_guardado(["https://nueva.test"])
	_check(main_script._entradas[1].get("cat") == "otro", "el lote crea los enlaces con cat otro")
	main_script._entradas = [
		{"nombre": "A", "url": "https://a.test"},
		{"nombre": "B", "url": "https://b.test", "cat": "cliente"},
		{"nombre": "C", "url": "https://c.test", "cat": "raro"},
	]
	main_script._normalizar_categorias()
	_check(main_script._entradas[0].get("cat") == "otro" and main_script._entradas[1].get("cat") == "cliente", "normalizar fija otro a ausente y conserva la clave válida")
	_check(main_script._entradas[2].get("cat") == "otro", "normalizar lleva el valor desconocido a otro")

	var filtro_cat: OptionButton = main.get_node("%FiltroCategoria")
	_check(filtro_cat.get_item_count() == 6 and filtro_cat.get_item_text(0) == "Todas" and filtro_cat.get_item_text(1) == "Otro" and filtro_cat.get_item_text(2) == "Cliente" and filtro_cat.get_item_text(3) == "Servidor" and filtro_cat.get_item_text(4) == "Códigos fuente" and filtro_cat.get_item_text(5) == "Parche", "el filtro de categoría ofrece Todas y las 5 categorías en orden")

	main_script._entradas = [
		{"nombre": "SOK", "url": "https://srv.test", "cat": "servidor"},
		{"nombre": "SCAI", "url": "https://srv2.test", "cat": "servidor"},
		{"nombre": "COK", "url": "https://cli.test", "cat": "cliente"},
	]
	main_script._estados = {
		"srv.test": {"valido": true},
		"srv2.test": {"valido": false},
		"cli.test": {"valido": true},
	}
	main_script._ui_refrescar()
	main.get_node("%FiltroEstado").select(1)
	main.get_node("%FiltroCategoria").select(3)
	main_script._ui_aplicar_filtro()
	var visibles: Array = []
	for hijo in main.get_node("%ListaContenedor").get_children():
		if hijo.visible:
			visibles.append(hijo.url)
	_check(visibles == ["https://srv.test"], "el filtro combina estado válido y categoría servidor")
	main.get_node("%FiltroCategoria").select(0)
	main_script._ui_aplicar_filtro()
	var visibles_todas: Array = []
	for hijo in main.get_node("%ListaContenedor").get_children():
		if hijo.visible:
			visibles_todas.append(hijo.url)
	_check(visibles_todas == ["https://srv.test", "https://cli.test"], "categoría Todas no filtra por categoría y mantiene el estado")

	# Filtros: etiquetas (#42)
	main.get_node("%FiltroEstado").select(0)
	main_script._entradas = [
		{"nombre": "SOK", "url": "https://srv.test", "cat": "servidor", "tags": ["AO 1.6", "servidor"]},
		{"nombre": "SCAI", "url": "https://srv2.test", "cat": "servidor", "tags": ["AO 1.4"]},
		{"nombre": "COK", "url": "https://cli.test", "cat": "cliente", "tags": ["AO 1.6"]},
	]
	main_script._cargar_filtros()
	main_script._ui_refrescar()
	var filtro_tag: OptionButton = main.get_node("%FiltroEtiqueta")
	_check(filtro_tag.item_count == 4 and filtro_tag.get_item_text(0) == "Todas" and filtro_tag.get_item_text(1) == "AO 1.6" and filtro_tag.get_item_text(2) == "AO 1.4" and filtro_tag.get_item_text(3) == "servidor", "el filtro de etiquetas ofrece Todas y las etiquetas por frecuencia")
	filtro_tag.select(1)
	main_script._ui_aplicar_filtro()
	var visibles_tag: Array = []
	for hijo in main.get_node("%ListaContenedor").get_children():
		if hijo.visible:
			visibles_tag.append(hijo.url)
	_check(visibles_tag == ["https://srv.test", "https://cli.test"], "el filtro de etiquetas muestra solo las filas que la tienen")
	filtro_tag.select(3)
	main_script._ui_filtro_etiqueta(3)
	var visibles_servidor: Array = []
	for hijo in main.get_node("%ListaContenedor").get_children():
		if hijo.visible:
			visibles_servidor.append(hijo.url)
	_check(visibles_servidor == ["https://srv.test"], "etiqueta servidor deja fuera a las filas sin esa etiqueta")
	_check(main_script._config_store.cargar().get("filtro_etiqueta", "#") == "servidor", "cambiar el filtro de etiqueta persiste en config")
	filtro_tag.select(0)
	main_script._ui_aplicar_filtro()

	# Filtros: persistencia en config (#39)
	filtro_cat.select(4)
	main_script._ui_filtro_categoria(4)
	_check(main_script._config_store.cargar().get("filtro_categoria", -1) == 4, "cambiar el filtro de categoría persiste en config")
	main.get_node("%FiltroEstado").select(2)
	main_script._ui_filtro_estado(2)
	_check(main_script._config_store.cargar().get("filtro_estado", -1) == 2, "cambiar el filtro de estado persiste en config")
	main.get_node("%Busqueda").text = "srv"
	var busqueda_previa: String = str(main_script._config_store.cargar().get("busqueda", "#"))
	main_script._ui_busqueda("srv")
	_check(
		str(main_script._config_store.cargar().get("busqueda", "#")) == busqueda_previa,
		"escribir en la búsqueda no reescribe config.json en cada tecla (#52)"
	)
	main_script._ui_busqueda_guardar()
	_check(main_script._config_store.cargar().get("busqueda", "#") == "srv", "al salir del buscador se guarda el texto (#52)")
	main.get_node("%Busqueda").text = ""
	main_script._ui_busqueda_guardar()

	# Importar/Exportar: menú y flujos (#3)
	main_script._persistir = false
	var diag_imp: FileDialog = main.get_node("%DialogoImportar")
	var diag_exp: FileDialog = main.get_node("%DialogoExportar")
	main_script._on_file_id(1)
	_check(diag_imp.visible, "Archivo > Importar… abre el diálogo de importación")
	diag_imp.hide()
	main_script._on_file_id(2)
	_check(diag_exp.visible, "Archivo > Exportar… abre el diálogo de exportación")
	diag_exp.hide()
	var diag_inf_i18n: FileDialog = main.get_node("%DialogoInforme")
	var diag_diag_i18n: FileDialog = main.get_node("%DialogoDiagnostico")
	_check(diag_imp.access == FileDialog.ACCESS_FILESYSTEM and diag_exp.access == FileDialog.ACCESS_FILESYSTEM and diag_inf_i18n.access == FileDialog.ACCESS_FILESYSTEM and diag_diag_i18n.access == FileDialog.ACCESS_FILESYSTEM, "los diálogos de archivo navegan por todo el disco (no quedan atrapados en res://)")
	_check(diag_imp.use_native_dialog and diag_exp.use_native_dialog and diag_inf_i18n.use_native_dialog and diag_diag_i18n.use_native_dialog, "los diálogos de archivo del Main usan el diálogo nativo del SO (#38)")

	# Informe de disponibilidad (#11)
	var menu_file_inf: PopupMenu = main.get_node("%File")
	var hay_informe := false
	for i in menu_file_inf.get_item_count():
		if menu_file_inf.get_item_id(i) == 5 and menu_file_inf.get_item_text(i) == "Informe de disponibilidad…":
			hay_informe = true
	_check(hay_informe, "Archivo > Informe de disponibilidad… está en el menú")
	_check(main.has_node("%DialogoInforme"), "el diálogo DialogoInforme existe en Main.tscn")
	main_script._on_file_id(5)
	_check(main.get_node("%DialogoInforme").visible, "Archivo > Informe de disponibilidad… abre el diálogo de guardado")
	main.get_node("%DialogoInforme").hide()
	_check(InformeControllerScript.formato_de("informe.html") == "html", "el formato del informe se deduce por extensión")
	_check(InformeControllerScript.formato_de("informe.csv") == "csv", "un .csv es csv")
	_check(InformeControllerScript.formato_de("informe") == "csv", "sin extensión se asume csv")

	# Restaurar copia (#23, #24)
	var menu_file: PopupMenu = main.get_node("%File")
	var hay_restaurar := false
	for i in menu_file.get_item_count():
		if menu_file.get_item_id(i) == 4 and menu_file.get_item_text(i) == "Restaurar copia…":
			hay_restaurar = true
	_check(hay_restaurar, "Archivo > Restaurar copia… está en el menú")
	var hay_copia := FileAccess.file_exists(main_script.DATA_USER + ".bak") or FileAccess.file_exists(main_script.DATA_RES + ".bak")
	main_script._on_file_id(4)
	if hay_copia:
		_check(main.has_node("%ConfirmarRestaurar") and main.get_node("%ConfirmarRestaurar").visible, "Restaurar copia… abre el diálogo de confirmación al existir copia")
		if main.has_node("%ConfirmarRestaurar"):
			main.get_node("%ConfirmarRestaurar").hide()
	else:
		_check(main.get_node("%Progreso").text == "No hay copia de seguridad disponible.", "Restaurar copia… sin copia informa en la barra")

	var ruta_imp := "user://__test_import_export__.json"
	var f_imp := FileAccess.open(ruta_imp, FileAccess.WRITE)
	f_imp.store_string(JSON.stringify([
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""},
		{"nombre": "B", "desc": "", "url": "https://bb.test", "img": ""},
		{"nombre": "C", "desc": "", "url": "https://cc.test", "img": ""},
	], "\t"))
	f_imp.close()
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""}]
	main_script._on_importar_elegido(ruta_imp)
	_check(main_script._entradas.size() == 3, "importar fusiona añadiendo solo las nuevas")
	_check(main.get_node("%Progreso").text == "2 importados, 1 omitidos.", "importar informa importados y omitidos")

	var ruta_exp := "user://__test_import_export_export__.json"
	main_script._on_exportar_elegido(ruta_exp)
	_check(FileAccess.file_exists(ruta_exp) and (JSON.parse_string(FileAccess.get_file_as_string(ruta_exp)) as Array).size() == 3, "exportar escribe un JSON con el catálogo")

	# Rutas de escritura (#50)
	main_script._persistir = true
	main_script._aviso_base = ""
	var data_res: String = main_script.DATA_RES
	DirAccess.remove_absolute(ProjectSettings.globalize_path(data_res))
	main_script._guardar_catalogo_base(false)
	_check(not FileAccess.file_exists(data_res) and main_script._aviso_base.is_empty(), "sin permiso no se toca el catálogo base ni se avisa (#50)")
	_check(main_script._estado_texto("Alta") == "Alta", "sin aviso de base el texto de la barra queda intacto (#50)")
	main_script._guardar_catalogo_base(true)
	_check(FileAccess.file_exists(data_res) and main_script._aviso_base.is_empty(), "con permiso se escribe el catálogo base (#50)")
	main_script.DATA_RES = "res://__test_main_flujos_ausente__/data.json"
	main_script._guardar_catalogo_base(true)
	_check(main_script._aviso_base == "No se pudo escribir el catálogo base.", "si el catálogo base no se puede escribir se avisa (#50)")
	_check(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://__test_main_flujos_ausente__")), "el intento fallido no crea carpetas en res:// (#50)")
	_check(main_script._estado_texto("Alta") == "Alta · No se pudo escribir el catálogo base.", "el aviso de base se añade al texto de la barra (#50)")
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""}]
	main_script._on_enlace_guardado({"nombre": "B", "desc": "", "url": "https://b.test", "img": ""})
	_check(main.get_node("%Progreso").text == "Enlace agregado: B · No se pudo escribir el catálogo base.", "el aviso de base sale con el mensaje de alta (#50)")
	main_script.DATA_RES = data_res
	main_script._persistir = false

	# Pool de filas y debounce de la búsqueda (#52)
	var lista = main.get_node("%ListaContenedor")
	main_script._espera_busqueda.wait_time = 0.01
	main_script._entradas = []
	for i in range(12):
		main_script._entradas.append({"nombre": "Fila %d" % i, "desc": "", "url": "https://fila%d.test" % i, "img": ""})
	main_script._ui_refrescar()
	await process_frame
	_check(lista.get_child_count() == 12, "la lista muestra las 12 filas (#52): %d" % lista.get_child_count())
	_check(_instancias(main_script) == 12, "solo hay 12 instancias de fila (#52): %d" % _instancias(main_script))
	main.get_node("%Busqueda").text = "fila1"
	main_script._ui_busqueda("fila1")
	_check(lista.get_child_count() == 12, "la lista no se repinta en la misma tecla (#52)")
	await main_script._espera_busqueda.timeout
	await process_frame
	_check(lista.get_child_count() == 3, "tras la espera la búsqueda deja 3 filas (#52): %d" % lista.get_child_count())
	_check(main_script._lista.pool_tamano() == 9, "las 9 filas sobrantes quedan en el pool (#52): %d" % main_script._lista.pool_tamano())
	for texto in ["fila", "fila1", "fila11", "fila1", "fila", ""]:
		main.get_node("%Busqueda").text = texto
		main_script._ui_busqueda(texto)
		await main_script._espera_busqueda.timeout
		await process_frame
	_check(_instancias(main_script) == 12, "escribir 6 caracteres no crea filas nuevas (#52): %d" % _instancias(main_script))
	_check(lista.get_child_count() == 12, "al vaciar la búsqueda vuelven las 12 filas (#52): %d" % lista.get_child_count())
	var en_vuelo = lista.get_child(0)
	en_vuelo.en_escaneo = true
	_check(not en_vuelo.reutilizable(), "una fila en vuelo de escaneo no se recicla (#52)")
	main.get_node("%Busqueda").text = "nada-de-esto"
	main_script._ui_busqueda_enviada("nada-de-esto")
	await process_frame
	_check(lista.get_child_count() == 0, "una búsqueda sin resultados deja la lista vacía (#52)")
	_check(main_script._lista.pool_tamano() == 11, "la fila en vuelo se libera en vez de ir al pool (#52): %d" % main_script._lista.pool_tamano())
	main.get_node("%Busqueda").text = ""
	main_script._ui_busqueda_enviada("")
	await process_frame
	_check(lista.get_child_count() == 12, "se recuperan las 12 filas (#52): %d" % lista.get_child_count())
	main_script._ui_toggle_vista()
	await process_frame
	_check(main.get_node("%GridContenedor").get_child_count() == 12, "la grilla muestra las 12 filas (#52)")
	_check(main_script._lista.pool_tamano() == 0, "al cambiar de vista se vacía el pool de la anterior (#52)")
	main_script._ui_toggle_vista()
	await process_frame
	_check(lista.get_child_count() == 12, "al volver a la lista se restauran las 12 filas (#52): %d" % lista.get_child_count())
	_check(_instancias(main_script) == 12, "cambiar de vista tampoco crea filas nuevas (#52): %d" % _instancias(main_script))
	_check(main_script._ultimo_repaint_ms >= 0.0, "el diagnóstico mide el último repintado (#52): %.2f ms" % main_script._ultimo_repaint_ms)

	# Volcado por lotes del escaneo (#51)
	var store = EstadoStoreScript.new("user://__test_main_flujos__")
	main_script._estado_store = store
	var enlaces := 50
	main_script._entradas = []
	for i in range(enlaces):
		main_script._entradas.append({"nombre": "E%d" % i, "desc": "", "url": "https://e%d.test" % i, "img": ""})
	main_script._ui_refrescar()
	await process_frame
	var items := main.get_node("%ListaContenedor")
	main_script._scan.preparar([], items.get_children())
	main_script._scan.escaneo().total = enlaces
	main_script._scan.escaneo().en_vuelo = enlaces
	main_script._scan.escaneo().hechos = 0
	store.volcar()
	var escrituras_iniciales: int = store.escrituras
	for i in range(enlaces):
		var item = items.get_child(i)
		item.verificacion_terminada.connect(main_script._scan_item_terminado.bind(item), CONNECT_ONE_SHOT)
		item.valido = true
		item.mensaje = "OK (200)"
		item.codigo = 200
		item.fecha = int(Time.get_unix_time_from_system())
		item.verificacion_terminada.emit()
	var volcados: int = store.escrituras - escrituras_iniciales
	_check(volcados <= 6, "un escaneo de %d enlaces escribe como mucho 6 veces, no una por enlace (#51): %d" % [enlaces, volcados])
	var estados: Dictionary = EstadoStoreScript.new("user://__test_main_flujos__").cargar()["estados"]
	_check(estados.size() == enlaces, "tras el escaneo los %d estados quedan en el fichero (#51)" % enlaces)
	_check(int(estados.get("e7.test", {}).get("codigo", -1)) == 200, "el estado volcado conserva el código (#51)")
	await _reubicar(main, main_script)
	Ayuda.borrar_arbol("user://__test_main_flujos__")
	_cerrar()


func _reubicar(main: Node, main_script) -> void:
	var dir := "user://__test_reubicar__"
	Ayuda.borrar_arbol(dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	main_script._estado_store = EstadoStoreScript.new(dir)
	main_script._persistir = false
	main_script._estados = {}
	main_script._entradas = [
		{"nombre": "Foto", "desc": "d", "url": "https://viejo.test/foto.png", "img": "", "cat": "cliente", "tags": ["x"]},
		{"nombre": "Otro", "desc": "", "url": "https://plano.test/pagina.html", "img": "", "cat": "otro"},
	]
	main_script._ui_refrescar()
	await process_frame

	# Sin redirección: la acción no se ofrece
	var fila_plana = _fila(main, "https://plano.test/pagina.html")
	_check(fila_plana != null and not fila_plana.puede_actualizar_url(), "una fila sin redirección no se puede actualizar (#59)")
	fila_plana._on_menu(7)
	await process_frame
	_check(not main.get_node("%ConfirmarReubicar").visible, "sin destino no se abre el diálogo de actualizar URL (#59)")
	_check(main_script._reubicar_pendientes.is_empty(), "sin destino no queda nada pendiente de actualizar (#59)")

	# Con redirección: el diálogo nombra el enlace y el destino
	main_script._estados = {
		"viejo.test/foto.png": {
			"valido": true, "mensaje": "OK (200)", "codigo": 200, "fecha": 100,
			"url_final": "https://nuevo.test/foto.png",
		},
		"plano.test/pagina.html": {"valido": true, "mensaje": "OK (200)", "codigo": 200, "fecha": 100},
	}
	main_script._ui_refrescar()
	await process_frame
	var fila = _fila(main, "https://viejo.test/foto.png")
	_check(fila != null and fila.puede_actualizar_url(), "una fila con destino utilizable sí se puede actualizar (#59)")
	if fila != null:
		_check(fila.get_node("%MarcaUrl").text == "movido", "la fila marca el enlace reubicado (#59)")
		_check(fila.get_node("%MarcaUrl").tooltip_text.contains("https://nuevo.test/foto.png"), "la marca explica cuál es el destino (#59)")
		_check(fila.tooltip_text.contains("Redirige a: https://nuevo.test/foto.png"), "el tooltip de la fila dice a dónde redirige (#59)")
		var menu: PopupMenu = fila.get_node("%MenuContexto")
		_check(menu.get_item_text(menu.get_item_index(7)) == "Actualizar URL a la nueva", "el menú ofrece actualizar la URL (#59)")
		_check(not menu.is_item_disabled(menu.get_item_index(7)), "con destino el menú está habilitado (#59)")
		fila._on_menu(7)
		await process_frame
		_check(main.get_node("%ConfirmarReubicar").visible, "pedir actualizar la URL abre el diálogo (#59)")
		_check(
			str(main.get_node("%ConfirmarReubicar").dialog_text) == "¿Actualizar «Foto» a https://nuevo.test/foto.png?",
			"el diálogo nombra el enlace y el destino (#59): %s" % str(main.get_node("%ConfirmarReubicar").dialog_text)
		)

		# Cancelar no cambia nada
		main_script._ui_cancelar_reubicar()
		main.get_node("%ConfirmarReubicar").hide()
		_check(str(main_script._entradas[0].get("url")) == "https://viejo.test/foto.png", "cancelar no cambia la URL del catálogo (#59)")
		_check(main_script._reubicar_pendientes.is_empty(), "cancelar vacía la lista de pendientes (#59)")

		# Confirmar actualiza de verdad
		main_script._ui_pedir_reubicar(["https://viejo.test/foto.png"])
		main_script._ui_confirmar_reubicar()
		await process_frame
		_check(str(main_script._entradas[0].get("url")) == "https://nuevo.test/foto.png", "confirmar guarda la URL nueva en el catálogo (#59)")
		_check(str(main_script._entradas[0].get("nombre")) == "Foto", "confirmar no renombra el enlace (#59)")
		_check(main_script._entradas[0].get("tags") == ["x"], "confirmar conserva las etiquetas (#59)")
		_check(main_script._estados.has("nuevo.test/foto.png") and not main_script._estados.has("viejo.test/foto.png"), "confirmar traslada el estado a la clave nueva (#59)")
		_check(str(main_script._estados.get("nuevo.test/foto.png", {}).get("valido", "")) == "true", "confirmar conserva el estado al trasladarlo (#59)")
		_check(str(main_script._estados.get("nuevo.test/foto.png", {}).get("url_final", "x")) == "", "tras actualizar no queda una redirección pendiente (#59)")
		_check(main.get_node("%Progreso").text == "1 URL actualizada", "confirmar informa en la barra (#59): %s" % main.get_node("%Progreso").text)

	# Actualización en lote desde el dashboard
	main_script._estados = {
		"nuevo.test/foto.png": {"valido": true, "url_final": "https://final.test/foto.png"},
		"plano.test/pagina.html": {"valido": true, "url_final": "https://final.test/otra.html"},
		"viejo.test/guia.html": {"valido": true, "url_final": "https://final.test/login.html"},
	}
	main_script._ui_pedir_reubicar_lote(["https://nuevo.test/foto.png", "https://plano.test/pagina.html", "https://nieva.test/x.png"])
	_check(main_script._reubicar_pendientes == ["https://nuevo.test/foto.png", "https://plano.test/pagina.html"], "el lote filtra lo que no se puede actualizar (#59)")
	_check(str(main.get_node("%ConfirmarReubicar").dialog_text) == "¿Actualizar la URL de 2 enlaces a la nueva?", "el lote avisa del número de enlaces (#59)")
	main_script._ui_confirmar_reubicar()
	await process_frame
	_check(str(main_script._entradas[0].get("url")) == "https://final.test/foto.png", "el lote actualiza el primer enlace (#59)")
	_check(str(main_script._entradas[1].get("url")) == "https://final.test/otra.html", "el lote actualiza el segundo enlace (#59)")
	_check(main.get_node("%Progreso").text == "2 URLs actualizadas", "el lote informa de cuántos se actualizaron (#59)")

	# Una página de login no se ofrece como reubicación
	main_script._estados = {"viejo.test/guia.html": {"valido": true, "url_final": "https://final.test/login.html"}}
	main_script._ui_pedir_reubicar(["https://viejo.test/guia.html"])
	_check(main_script._reubicar_pendientes.is_empty(), "un destino de login no se ofrece (#59)")
	main_script._reubicar_pendientes = []
	Ayuda.borrar_arbol(dir)


func _fila(main: Node, url: String):
	for hijo in main.get_node("%ListaContenedor").get_children():
		if hijo.url == url:
			return hijo
	return null


func _instancias(main_script) -> int:
	return main_script._lista.pool_tamano() + main_script._contenedor_activo().get_child_count()


func _cerrar() -> void:
	Ayuda.borrar_arbol("user://__test_main_flujos__")
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