extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const LIST_ITEM_SCENE := preload("res://scenes/ListItem.tscn")
const ConfigStoreScript := preload("res://scripts/config_store.gd")

var _fallos := 0


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
	main_script._refrescar_vista()
	await process_frame
	var fila = main.get_node("%ListaContenedor").get_child(0)
	fila.copiar_pedido.emit(fila.url)
	_check(main.get_node("%Progreso").text == "URL copiada: https://copiar.test", "copiar desde la fila informa en la barra")

	_check(not main.get_node("%BarraProgreso").visible, "la barra de progreso nace oculta")
	main_script._actualizar_barra(3, 5)
	_check(main.get_node("%BarraProgreso").value == 3, "la barra refleja los enlaces comprobados")
	_check(main.get_node("%BarraProgreso").max_value == 5, "la barra usa el total de enlaces como máximo")
	main_script._marcar_barra_final(0)
	var verde: StyleBoxFlat = main.get_node("%BarraProgreso").get_theme_stylebox("fill")
	_check(verde.bg_color.is_equal_approx(Color(0.35, 0.85, 0.45, 1)), "con 0 caídos la barra se pone verde")
	main_script._marcar_barra_final(2)
	var rojo: StyleBoxFlat = main.get_node("%BarraProgreso").get_theme_stylebox("fill")
	_check(rojo.bg_color.is_equal_approx(Color(0.95, 0.35, 0.35, 1)), "con caídos la barra se pone roja")
	for hijo in main.get_node("%ListaContenedor").get_children():
		hijo.visible = false
	main_script._comprobar_visibles()
	_check(not main.get_node("%BarraProgreso").visible, "sin enlaces visibles la barra se oculta")
	_check(main.get_node("%Progreso").text == "Nada que comprobar", "sin enlaces visibles se muestra el aviso")

	# Cola persistida (#13)
	main_script._cola_store = (load("res://scripts/cola_store.gd") as GDScript).new("user://__test_main__")
	var item_a: Button = LIST_ITEM_SCENE.instantiate()
	item_a.url = "https://a.test"
	main_script._cola.append(item_a)
	var item_c: Button = LIST_ITEM_SCENE.instantiate()
	item_c.url = "https://c.test"
	main_script._cola.append(item_c)
	var item_b: Button = LIST_ITEM_SCENE.instantiate()
	item_b.url = "https://b.test"
	main_script._persistir_cola()
	var cola_guardada: Array = main_script._cola_store.cargar().get("urls", [])
	_check(cola_guardada.size() == 2 and "https://a.test" in cola_guardada and "https://c.test" in cola_guardada, "persistir cola guarda las urls de los items")
	item_a.free()
	item_c.free()
	main_script._cola.clear()
	main_script._cola_store.limpiar()

	# Reanudación (#13)
	main_script._entradas = [
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""},
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": ""},
	]
	main_script._refrescar_vista()
	await process_frame
	_check(main.has_node("%ConfirmarReanudar"), "el diálogo ConfirmarReanudar existe en Main.tscn")
	main_script._cola.clear()
	main_script._rearmar_cola_pendiente(["https://b.test"])
	_check(main_script._cola.size() == 1 and main_script._cola[0].url == "https://b.test", "reanudar reconstruye la cola con solo las urls pendientes")
	main_script._cola.clear()

	main_script._cola_store.guardar(["https://nope.test"])
	main_script._reanudar_escaneo()
	_check(main_script._cola.is_empty() and (main_script._cola_store.cargar().get("urls", []) as Array).is_empty(), "reanudar con urls inexistentes descarta y limpia")
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
	main_script._refrescar_vista()
	main.get_node("%FiltroEstado").select(1)
	main.get_node("%FiltroCategoria").select(3)
	main_script._aplicar_filtro()
	var visibles: Array = []
	for hijo in main.get_node("%ListaContenedor").get_children():
		if hijo.visible:
			visibles.append(hijo.url)
	_check(visibles == ["https://srv.test"], "el filtro combina estado válido y categoría servidor")
	main.get_node("%FiltroCategoria").select(0)
	main_script._aplicar_filtro()
	var visibles_todas: Array = []
	for hijo in main.get_node("%ListaContenedor").get_children():
		if hijo.visible:
			visibles_todas.append(hijo.url)
	_check(visibles_todas == ["https://srv.test", "https://cli.test"], "categoría Todas no filtra por categoría y mantiene el estado")

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
	_check(main_script._formato_informe("informe.html") == "html", "_formato_informe deduce html por extensión")
	_check(main_script._formato_informe("informe.csv") == "csv", "_formato_informe deduce csv por extensión")
	_check(main_script._formato_informe("informe") == "csv", "_formato_informe asume csv sin extensión")

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

	main_script._persistir = false
	_cerrar()


func _cerrar() -> void:
	var ruta_temp := ProjectSettings.globalize_path("user://__test_main_flujos__")
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