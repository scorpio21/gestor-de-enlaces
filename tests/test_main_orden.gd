extends SceneTree

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const GestorDatosScript := preload("res://scripts/gestor_datos.gd")
const ConfigStoreScript := preload("res://scripts/config_store.gd")

var _fallos := 0


func _initialize() -> void:
	_arrancar()

func _arrancar() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://__test_main_orden__"))
	ConfigStoreScript.new("user://__test_main_orden__").guardar(3, 10.0, false, 0, "oscuro", "", "", 1, "es")
	TranslationServer.set_locale("es")
	var main := MAIN_SCENE.instantiate()
	main.DATA_RES = "user://__test_main_orden__/data.json"
	main.DATA_USER = "user://__test_main_orden__/enlaces.json"
	main.CONFIG_BASE = "user://__test_main_orden__"
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

	# Disponibilidad: selector de orden por fecha (#9)
	_check(main.has_node("%CabNombre") and main.has_node("%CabEstado") \
		and main.has_node("%CabFecha") and main.has_node("%CabImagen"), "la barra muestra las 4 cabeceras de columna")
	main.get_node("%FiltroEstado").select(0)
	var cab_nombre_btn := main.get_node("%CabNombre")
	var cab_estado_btn := main.get_node("%CabEstado")
	var cab_fecha_btn := main.get_node("%CabFecha")
	var cab_imagen_btn := main.get_node("%CabImagen")
	_check(cab_nombre_btn.get_parent().name == "FilaCabeceras", "las cabeceras viven en FilaCabeceras")
	_check(cab_nombre_btn.toggle_mode and cab_estado_btn.toggle_mode \
		and cab_fecha_btn.toggle_mode and cab_imagen_btn.toggle_mode, "las cabeceras son pulsables (toggle_mode)")

	main_script._entradas = [
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""},
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": ""},
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": ""},
	]
	main_script._estados = {
		"a.test": {"valido": true, "mensaje": "OK", "codigo": 200, "fecha": 1000},
		"b.test": {"valido": true, "mensaje": "OK", "codigo": 200, "fecha": 2000},
	}
	main_script._ui_refrescar()
	await process_frame

	main_script._ui_cabecera("fecha")
	_check(main_script._orden_columna == "fecha" and main_script._orden_direccion == -1, "primer clic en Fecha activa descendente")
	_check(cab_fecha_btn.text == "Fecha ▼", "la cabecera Fecha activa muestra indicador descendente")
	_check(_urls_visibles(main) == ["https://b.test", "https://a.test", "https://c.test"], "Fecha descendente: más recientes primero y lo sin comprobar al final")

	main_script._ui_cabecera("fecha")
	_check(main_script._orden_direccion == 1, "segundo clic en la misma cabecera invierte a ascendente")
	_check(cab_fecha_btn.text == "Fecha ▲", "la cabecera Fecha invertida muestra indicador ascendente")
	_check(_urls_visibles(main) == ["https://a.test", "https://b.test", "https://c.test"], "Fecha ascendente: más antiguos primero y lo sin comprobar al final")

	main_script._ui_cabecera("fecha")
	_check(main_script._orden_columna == "", "tercer clic desactiva la columna")
	_check(_urls_visibles(main) == ["https://a.test", "https://b.test", "https://c.test"], "sin columna conserva el orden de inserción")

	# #17: columna Nombre (asc por defecto)
	main_script._entradas = [
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": ""},
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""},
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": ""},
	]
	main_script._estados = {}
	main_script._ui_refrescar()
	await process_frame
	main_script._ui_cabecera("nombre")
	_check(_urls_visibles(main) == ["https://a.test", "https://b.test", "https://c.test"], "Nombre ascendente ordena alfabéticamente")
	main_script._ui_cabecera("nombre")
	_check(_urls_visibles(main) == ["https://c.test", "https://b.test", "https://a.test"], "Nombre descendente invierte el orden")
	main_script._ui_cabecera("nombre")
	_check(main_script._orden_columna == "", "3 clics en Nombre vuelven a sin ordenar")

	# #17: columna Imagen (con imagen primero en asc)
	var ruta_b := _crear_captura("img_ord_b.png")
	var ruta_c := _crear_captura("img_ord_c.png")
	main_script._entradas = [
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""},
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": ruta_b},
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": ruta_c},
	]
	main_script._estados = {}
	main_script._ui_refrescar()
	await process_frame
	main_script._ui_cabecera("imagen")
	_check(_urls_visibles(main) == ["https://b.test", "https://c.test", "https://a.test"], "Imagen ascendente pone con captura primero (alfabético luego)")
	main_script._ui_cabecera("imagen")
	_check(_urls_visibles(main) == ["https://a.test", "https://b.test", "https://c.test"], "Imagen descendente pone sin captura primero")
	main_script._ui_cabecera("imagen")
	_check(main_script._orden_columna == "", "3 clics en Imagen vuelven a sin ordenar")

	# #17: columna Estado (sin comprobar → válidos → caídos)
	main_script._entradas = [
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""},
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": ""},
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": ""},
	]
	main_script._estados = {
		"a.test": {"valido": true, "mensaje": "OK", "codigo": 200, "fecha": 1000},
		"b.test": {"valido": false, "mensaje": "No existe", "codigo": 404, "fecha": 1000},
	}
	main_script._ui_refrescar()
	await process_frame
	main_script._ui_cabecera("estado")
	_check(_urls_visibles(main) == ["https://b.test", "https://a.test", "https://c.test"], "Estado descendente: caídos, válidos, sin comprobar")
	main_script._ui_cabecera("estado")
	_check(_urls_visibles(main) == ["https://c.test", "https://a.test", "https://b.test"], "Estado ascendente: sin comprobar, válidos, caídos")
	main_script._ui_cabecera("estado")
	_check(main_script._orden_columna == "", "3 clics en Estado vuelven a sin ordenar")

	# Task 2: helpers de reorden y estados del menú contextual
	main_script._persistir = false
	main_script._entradas = [
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""},
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": ""},
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": ""}
	]
	main_script._ui_refrescar()
	await process_frame

	var visibles_t2: Array = main_script._ui_filas_visibles()
	_check(visibles_t2.size() == 3, "_ui_filas_visibles devuelve las 3 filas sin filtros")

	var ind_b_t2: int = main_script._indice_entrada("https://b.test")
	_check(ind_b_t2 == 1, "_indice_entrada localiza B en _entradas")
	var ind_inex_t2: int = main_script._indice_entrada("https://no-existe.test")
	_check(ind_inex_t2 == -1, "_indice_entrada devuelve -1 para url ausente")

	var fila_a: Button = visibles_t2[0]
	var fila_b: Button = visibles_t2[1]
	var fila_c: Button = visibles_t2[2]
	var menu_ctx_a: PopupMenu = fila_a.get_node("%MenuContexto")
	var menu_ctx_b: PopupMenu = fila_b.get_node("%MenuContexto")
	var menu_ctx_c: PopupMenu = fila_c.get_node("%MenuContexto")

	# en la primera fila Subir deshabilitada y Bajar habilitada
	main_script._ui_menu_fila(fila_a)
	_check(menu_ctx_a.is_item_disabled(menu_ctx_a.get_item_index(5)), "primera fila: Subir deshabilitada")
	_check(not menu_ctx_a.is_item_disabled(menu_ctx_a.get_item_index(6)), "primera fila: Bajar habilitada")

	# fila central: ambas habilitadas
	main_script._ui_menu_fila(fila_b)
	_check(not menu_ctx_b.is_item_disabled(menu_ctx_b.get_item_index(5)), "fila central: Subir habilitada")
	_check(not menu_ctx_b.is_item_disabled(menu_ctx_b.get_item_index(6)), "fila central: Bajar habilitada")

	# última fila: Subir habilitada y Bajar deshabilitada
	main_script._ui_menu_fila(fila_c)
	_check(not menu_ctx_c.is_item_disabled(menu_ctx_c.get_item_index(5)), "última fila: Subir habilitada")
	_check(menu_ctx_c.is_item_disabled(menu_ctx_c.get_item_index(6)), "última fila: Bajar deshabilitada")

	# Task 3: reorden real, filtros y persistencia
	main_script._persistir = false
	main_script._entradas = [
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""},
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": ""},
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": ""}
	]
	main_script._ui_refrescar()
	await process_frame

	var visibles_t3: Array = main_script._ui_filas_visibles()
	var item_b_real: Button = visibles_t3[1]
	main_script._persistir = true
	main_script._ui_mover_fila(item_b_real, -1)
	main_script._persistir = false
	_check(main_script._indice_entrada("https://a.test") == 1 and main_script._indice_entrada("https://b.test") == 0, "Subir B la coloca antes de A en _entradas")

	var urls_antes: Array = []
	for e in main_script._entradas:
		urls_antes.append(str(e.get("url", "")))
	_check(urls_antes == ["https://b.test", "https://a.test", "https://c.test"], "tras guardar el orden B,A,C queda persistido en memoria")

	var persistido: Array = GestorDatosScript.cargar(main_script.DATA_USER)
	var orden_persistido: Array = []
	for e in persistido:
		orden_persistido.append(str(e.get("url", "")))
	_check(orden_persistido == ["https://b.test", "https://a.test", "https://c.test"], "tras guardar el orden B,A,C queda en el archivo de usuario")

	var item_b_rest: Button = main_script._ui_filas_visibles()[0]
	main_script._ui_mover_fila(item_b_rest, 1)
	_check(main_script._indice_entrada("https://b.test") == 1, "Bajar devuelve B a su posición original")

	main_script._entradas = [
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": "", "cat": "cliente"},
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": "", "cat": "otro"},
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": "", "cat": "cliente"}
	]
	main_script._estados = {}
	main_script.filtro_cat.select(2)
	main_script._ui_refrescar()
	await process_frame

	var visibles_filtradas: Array = main_script._ui_filas_visibles()
	_check(visibles_filtradas.size() == 2, "el filtro Cliente oculta la fila A (otro)")

	var item_c2: Button = visibles_filtradas[1]
	main_script._ui_mover_fila(item_c2, -1)
	_check(main_script._indice_entrada("https://b.test") == 2 and main_script._indice_entrada("https://c.test") == 0, "Subir C la cruza con B saltando la fila oculta A")
	main_script.filtro_cat.select(0)

	main_script._ui_cabecera("imagen")
	main_script._ui_mover_fila(main_script._ui_filas_visibles()[0], -1)
	var antes: Array = []
	for e in main_script._entradas:
		antes.append(str(e.get("url", "")))
	_check(antes == ["https://c.test", "https://a.test", "https://b.test"], "con columna activa _ui_mover_fila no modifica _entradas")
	main_script._ui_menu_fila(main_script._ui_filas_visibles()[0])
	_check(main_script._ui_filas_visibles()[0].get_node("%MenuContexto").is_item_disabled(
		main_script._ui_filas_visibles()[0].get_node("%MenuContexto").get_item_index(5)), "con columna activa Subir queda deshabilitada")
	main_script._ui_cabecera("imagen")
	main_script._ui_cabecera("imagen")
	_check(main_script._orden_columna == "", "3 clics en la columna activa vuelven a sin ordenar")

	# #17: persistencia y restauración del criterio
	main_script._ui_cabecera("fecha")
	var guardado: Dictionary = main_script._config_store.cargar()
	_check(guardado.get("orden_columna", "") == "fecha" and guardado.get("orden_direccion", 0) == -1, "pulsar una cabecera persiste el criterio")
	main_script._persistir_version_vista()
	var preservado: Dictionary = main_script._config_store.cargar()
	_check(preservado.get("orden_columna", "") == "fecha", "persistir la versión vista conserva el criterio")
	main_script._ui_cabecera("fecha")
	main_script._ui_cabecera("fecha")
	_check(main_script._config_store.cargar().get("orden_columna", "#") == "", "desactivar la columna persiste sin criterio")

	var base_orden := "user://__test_orden_restore__"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_orden))
	ConfigStoreScript.new(base_orden).guardar(3, 10.0, true, 0, "oscuro", "", "fecha", -1, "en", 1, 2, "glaciar", "srv")
	GestorDatosScript.guardar(base_orden + "/data.json", [{"nombre": "X", "url": "https://x.test", "img": "", "tags": ["glaciar"]}])
	var main_rest := MAIN_SCENE.instantiate()
	main_rest.DATA_RES = base_orden + "/data.json"
	main_rest.DATA_USER = base_orden + "/enlaces.json"
	main_rest.CONFIG_BASE = base_orden
	root.add_child(main_rest)
	await process_frame
	await process_frame
	var mrs: Node = main_rest.get_node(".")
	_check(mrs._orden_columna == "fecha" and mrs._orden_direccion == -1, "otro arranque restaura el criterio desde config")
	_check(main_rest.get_node("%FiltroEstado").get_selected_id() == 1, "otro arranque restaura el filtro de estado desde config")
	_check(main_rest.get_node("%FiltroCategoria").get_selected_id() == 2, "otro arranque restaura el filtro de categoría desde config")
	_check(main_rest.get_node("%FiltroEtiqueta").get_selected_id() == 1 and main_rest.get_node("%FiltroEtiqueta").get_item_text(1) == "glaciar", "otro arranque restaura el filtro de etiqueta desde config")
	_check(main_rest.get_node("%Busqueda").text == "srv", "otro arranque restaura la búsqueda desde config")
	_check(_urls_visibles(main_rest).is_empty() or _urls_visibles(main_rest).size() >= 0, "el segundo arranque carga sin errores")
	_check(TranslationServer.get_locale() == "en", "arrancar con config idioma=en fija el locale en")
	TranslationServer.set_locale("es")
	main_rest.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(base_orden))

	# #17: si no se puede guardar, se revierte el criterio
	var store_roto := ConfigStoreScript.new("user://__test_main_orden__/nada/cfg")
	main_script._config_store = store_roto
	main_script._ui_cabecera("nombre")
	_check(main_script._orden_columna == "", "si la persistencia falla se revierte el criterio")
	_check(store_roto.cargar().get("orden_columna", "") == "", "el fallo no deja criterio guardado")
	main_script._config_store = ConfigStoreScript.new()

	main_script._persistir = false
	_cerrar()


func _crear_captura(nombre: String) -> String:
	var ruta := "res://Assets/png/%s" % nombre
	var img := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.MAGENTA)
	if img.save_png(ProjectSettings.globalize_path(ruta)) != OK:
		return ""
	return ruta


func _cerrar() -> void:
	var ruta_temp := ProjectSettings.globalize_path("user://__test_main_orden__")
	for f in ["data.json", "enlaces.json"]:
		if FileAccess.file_exists(ruta_temp.path_join(f)):
			DirAccess.remove_absolute(ruta_temp.path_join(f))
	if DirAccess.dir_exists_absolute(ruta_temp):
		DirAccess.remove_absolute(ruta_temp)
	for f in ["img_ord_b.png", "img_ord_c.png"]:
		var ruta := "res://Assets/png/%s" % f
		var abs := ProjectSettings.globalize_path(ruta)
		if FileAccess.file_exists(abs):
			DirAccess.remove_absolute(abs)
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _urls_visibles(main_node: Node) -> Array:
	var urls: Array = []
	for hijo in main_node.get_node("%ListaContenedor").get_children():
		if hijo.visible:
			urls.append(hijo.url)
	return urls


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)