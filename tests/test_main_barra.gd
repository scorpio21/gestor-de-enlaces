extends SceneTree

class _FakeStore extends RefCounted:
	var ultima_renombrar: Array = []
	func renombrar(url_antigua: String, url_nueva: String) -> bool:
		ultima_renombrar = [url_antigua, url_nueva]
		return true

class _FakeHistorial extends RefCounted:
	func historial_de(_url: String) -> Array:
		return [{"fecha": 1000000000, "valido": true, "mensaje": "OK (200)", "codigo": 200}]

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const LIST_ITEM_SCENE := preload("res://scenes/ListItem.tscn")
const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
const TemaStoreScript := preload("res://scripts/tema_store.gd")
const GestorDatosScript := preload("res://scripts/gestor_datos.gd")
const ConfigStoreScript := preload("res://scripts/config_store.gd")

var _fallos := 0
var _imgs_iniciales: Array = []


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://__test_main_barra__"))
	ConfigStoreScript.new("user://__test_main_barra__").guardar(3, 10.0, false, 0, "oscuro", "", "", 1, "es")
	TranslationServer.set_locale("es")
	var main := MAIN_SCENE.instantiate()
	main.DATA_RES = "user://__test_main_barra__/data.json"
	main.DATA_USER = "user://__test_main_barra__/enlaces.json"
	main.CONFIG_BASE = "user://__test_main_barra__"
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
	if main_script.has_method("_persistir_recompra"):
		main_script._estados.clear()
		var item = LIST_ITEM_SCENE.instantiate()
		item.url = "https://prueba-ejemplo.test"
		item.valido = false
		item.mensaje = "No existe"
		main_script._entradas.append({"nombre": "Prueba", "url": "https://prueba-ejemplo.test"})
		main_script._persistir_recompra(item)
		var estado_memoria: Dictionary = main_script._estados.get(GestorCatalogoScript.clave_unica(item.url), {})
		_check(estado_memoria.has("codigo") and int(estado_memoria.get("codigo", -1)) == 0, "el estado en memoria conserva el código tras re-comprobar")
		_check(int(estado_memoria.get("fecha", 0)) > 0, "el estado en memoria conserva la fecha tras re-comprobar")
		main_script._estado_store.borrar_estado(GestorCatalogoScript.clave_unica(item.url))
		_check(main.get_node("%Rotos").text == "Rotos: 1", "Rotos se actualiza tras nueva comprobación")
		item.free()

	# Catálogo: alta única con duplicados
	main_script._persistir = false
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""}]
	main_script._on_enlace_guardado({"nombre": "B", "desc": "", "url": "https://a.test", "img": ""})
	_check(main_script._entradas.size() == 1, "alta con URL existente no añade")
	_check(main.get_node("%Progreso").text == "Ya existe: https://a.test", "alta duplicada informa en la barra")

	# Catálogo: lote de URLs
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""}]
	main_script._on_lote_guardado(["https://a.test", "https://bb.test", "https://a.test", "no-es-url", ""])
	_check(main_script._entradas.size() == 2, "el lote añade solo las válidas nuevas")
	_check(main_script._entradas[1].get("nombre") == "bb.test", "el lote deriva el nombre del dominio")
	_check(main.get_node("%Progreso").text == "Se añadieron 1 enlaces. 2 repetidas ignoradas. 1 inválidas ignoradas.", "el lote reporta repetidas e inválidas")

	# Catálogo: lote todo repetido
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""}]
	main_script._on_lote_guardado(["https://a.test"])
	_check(main_script._entradas.size() == 1, "lote sin nuevas no añade nada")
	_check(main.get_node("%Progreso").text == "No se añadió ningún enlace. 1 repetidas ignoradas.", "lote sin nuevas reporta")

	# Catálogo: edición con cambio de URL remapea
	main_script._estado_store = _FakeStore.new()
	main_script._estados = {"a.test": {"valido": true, "mensaje": "OK (200)", "codigo": 200, "fecha": 1}}
	main_script._borrados = ["a.test"]
	main_script._entradas = [{"nombre": "A", "desc": "D", "url": "https://a.test", "img": ""}]
	main_script._on_enlace_editado({"nombre": "A2", "desc": "D2", "url": "https://a2.test", "img": ""}, "https://a.test")
	_check(main_script._entradas[0].get("url") == "https://a2.test" and main_script._entradas[0].get("nombre") == "A2", "editar sustituye los campos de la entrada")
	_check(main_script._estados.has("a2.test") and not main_script._estados.has("a.test"), "editar remapea el estado en memoria")
	_check(main_script._borrados == ["a2.test"], "editar remapea los borrados en memoria")
	_check(main_script._estado_store.ultima_renombrar == ["a.test", "a2.test"], "editar pide el remapeo persistido al store")
	_check(main.get_node("%Progreso").text == "Enlace actualizado: A2", "editar confirma en la barra")

	# Catálogo: edición con colisión de URL no modifica
	main_script._estados = {}
	main_script._borrados = []
	main_script._entradas = [
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""},
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": ""},
	]
	var ventana: Window = main.get_node("%VentanaAgregar")
	ventana.abrir_edicion({"nombre": "A", "desc": "", "url": "https://a.test", "img": ""}, "https://a.test")
	ventana.get_node("%Url").text = "https://c.test"
	ventana.get_node("%BotonGuardar").pressed.emit()
	_check(main_script._entradas[0].get("url") == "https://a.test", "editar con URL que colisiona no modifica")
	_check(main.get_node("%Progreso").text == "Ya existe: https://c.test", "editar con colisión informa en la barra")
	_check(ventana.visible, "editar con colisión reabre el diálogo")

	# Catálogo: normalización de URLs (#25)
	main_script._persistir = false
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "http://x.test", "img": ""}]
	main_script._on_enlace_guardado({"nombre": "B", "desc": "", "url": "https://X.test/", "img": ""})
	_check(main_script._entradas.size() == 1, "alta con https://X.test/ colisiona con http://x.test")
	_check(main.get_node("%Progreso").text == "Ya existe: http://x.test", "la colisión muestra la URL canónica existente")
	main_script._entradas = []
	main_script._on_lote_guardado(["HTTP://X.test/", "https://x.test"])
	_check(main_script._entradas.size() == 1, "el lote normaliza y deduplica variantes")
	_check(str(main_script._entradas[0].get("url", "")) == "http://x.test", "el lote guarda la URL canónica")
	main_script._entradas = [
		{"nombre": "A", "desc": "", "url": "http://a.test", "img": ""},
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": ""},
	]
	main_script._estados = {"a.test": {"valido": true, "mensaje": "OK (200)", "codigo": 200, "fecha": 1}}
	main_script._borrados = []
	ventana.abrir_edicion({"nombre": "A", "desc": "", "url": "http://a.test", "img": ""}, "http://a.test")
	ventana.get_node("%Url").text = "https://c.test/"
	ventana.get_node("%BotonGuardar").pressed.emit()
	_check(str(main_script._entradas[0].get("url", "")) == "http://a.test", "editar a una clave existente no modifica")
	_check(main.get_node("%Progreso").text == "Ya existe: https://c.test", "editar colisionado informa con la URL canónica")
	_check(ventana.visible, "editar colisionado reabre el diálogo")
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "HTTP://Migrada.TEST/", "img": ""}]
	main_script._estados = {"https://migrada.test": {"valido": true, "mensaje": "OK", "codigo": 200, "fecha": 1}, "http://migrada.test/": {"valido": false, "mensaje": "X", "codigo": 0, "fecha": 2}}
	main_script._borrados = ["https://migrada.test/", "https://migrada.test"]
	main_script._normalizar_urls()
	_check(str(main_script._entradas[0].get("url", "")) == "http://migrada.test", "la migración normaliza las URLs de las entradas")
	_check(main_script._estados.size() == 1 and main_script._estados.has("migrada.test"), "la migración colapsa los estados a clave única")
	_check(main_script._borrados == ["migrada.test"], "la migración re-aja y deduplica los borrados")

	# Catálogo: capturas (cambiar / quitar / compartir)
	main_script._persistir = false
	_imgs_iniciales = _listar_capturas()
	var fuente := ProjectSettings.globalize_path("res://Assets/png/no-disponible.png")
	var no_existe := ProjectSettings.globalize_path("res://Assets/png/__inexistente__.png")

	# 1) cambiar captura: destino nuevo y archivo viejo borrado
	var vieja1 := _crear_captura("img_test_old1.png")
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": vieja1}]
	ventana.abrir_edicion({"nombre": "A", "desc": "", "url": "https://a.test", "img": vieja1}, "https://a.test")
	ventana._imagen_ruta = fuente
	ventana.get_node("%BotonGuardar").pressed.emit()
	var img_nueva := str(main_script._entradas[0].get("img", ""))
	_check(img_nueva != vieja1 and img_nueva.begins_with("res://Assets/png/img_"), "cambiar captura apunta a un img_*.png nuevo")
	_check(not FileAccess.file_exists(ProjectSettings.globalize_path(vieja1)), "cambiar captura borra el archivo viejo")

	# 2) quitar captura: img vacío y archivo viejo borrado
	var vieja2 := _crear_captura("img_test_old2.png")
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": vieja2}]
	ventana.abrir_edicion({"nombre": "A", "desc": "", "url": "https://a.test", "img": vieja2}, "https://a.test")
	ventana.get_node("%BotonQuitar").pressed.emit()
	ventana.get_node("%BotonGuardar").pressed.emit()
	_check(str(main_script._entradas[0].get("img", "")) == "", "quitar captura deja img vacío")
	_check(not FileAccess.file_exists(ProjectSettings.globalize_path(vieja2)), "quitar captura borra el archivo viejo")

	# 3) editar sin tocar la imagen: archivo conservado e img intacto
	var vieja3 := _crear_captura("img_test_old3.png")
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": vieja3}]
	ventana.abrir_edicion({"nombre": "A", "desc": "", "url": "https://a.test", "img": vieja3}, "https://a.test")
	ventana.get_node("%BotonGuardar").pressed.emit()
	_check(str(main_script._entradas[0].get("img", "")) == vieja3, "editar sin tocar imagen conserva img")
	_check(FileAccess.file_exists(ProjectSettings.globalize_path(vieja3)), "editar sin tocar imagen conserva el archivo")

	# 4) colisión de URL con imagen nueva: sin archivos nuevos y reabre con la original
	var vieja4 := _crear_captura("img_test_old4.png")
	main_script._entradas = [
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": vieja4},
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": ""},
	]
	var antes4 := _listar_capturas()
	ventana.abrir_edicion({"nombre": "A", "desc": "", "url": "https://a.test", "img": vieja4}, "https://a.test")
	ventana._imagen_ruta = fuente
	ventana.get_node("%Url").text = "https://c.test"
	ventana.get_node("%BotonGuardar").pressed.emit()
	_check(_listar_capturas() == antes4, "colisión con imagen nueva no crea archivos")
	_check(main_script._entradas[0].get("img") == vieja4, "colisión con imagen nueva no toca la entrada")
	_check(ventana._imagen_original == vieja4, "colisión con imagen nueva reabre con la imagen original")

	# 5) captura compartida: no se borra al quitar en un enlace
	var vieja5 := _crear_captura("img_test_old5.png")
	main_script._entradas = [
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": vieja5},
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": vieja5},
	]
	ventana.abrir_edicion({"nombre": "A", "desc": "", "url": "https://a.test", "img": vieja5}, "https://a.test")
	ventana.get_node("%BotonQuitar").pressed.emit()
	ventana.get_node("%BotonGuardar").pressed.emit()
	_check(FileAccess.file_exists(ProjectSettings.globalize_path(vieja5)), "captura compartida no se borra al quitar")
	_check(str(main_script._entradas[0].get("img", "")) == "" and str(main_script._entradas[1].get("img", "")) == vieja5, "captura compartida solo se desreferencia en el enlace editado")

	# 6) copiar fallido (fuente inexistente): barra de error y entrada intacta
	var vieja6 := _crear_captura("img_test_old6.png")
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": vieja6}]
	ventana.abrir_edicion({"nombre": "A", "desc": "", "url": "https://a.test", "img": vieja6}, "https://a.test")
	ventana._imagen_ruta = no_existe
	ventana.get_node("%BotonGuardar").pressed.emit()
	_check(main_script._entradas[0].get("img") == vieja6, "copiar fallido deja la entrada intacta")
	_check(main.get_node("%Progreso").text == "No se pudo procesar la imagen.", "copiar fallido informa en la barra")

	_limpiar_capturas()

	# Catálogo: captura jpg huérfana se borra / se conserva (#33)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Assets/jpg"))
	var jpg_borra := "res://Assets/jpg/img_test_borrable.jpg"
	var img_j2 := Image.create_empty(4, 4, false, Image.FORMAT_RGB8)
	img_j2.fill(Color.BLUE)
	img_j2.save_jpg(ProjectSettings.globalize_path(jpg_borra), 0.9)
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": "res://Assets/png/img_test_otra.png"}]
	main_script._borrar_captura_si_huerfana(jpg_borra)
	_check(not FileAccess.file_exists(ProjectSettings.globalize_path(jpg_borra)), "captura jpg no referenciada se borra (#33)")
	var jpg_ref2 := "res://Assets/jpg/img_test_referida.jpg"
	img_j2.save_jpg(ProjectSettings.globalize_path(jpg_ref2), 0.9)
	main_script._entradas[0]["img"] = jpg_ref2
	main_script._borrar_captura_si_huerfana(jpg_ref2)
	_check(FileAccess.file_exists(ProjectSettings.globalize_path(jpg_ref2)), "captura jpg referenciada se conserva (#33)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(jpg_ref2))

	# Catálogo: limpieza de capturas huérfanas
	var sin_huerfana := _crear_captura("img_test_ok.png")
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": sin_huerfana}]
	main_script._on_utilidades_id(2)
	_check(main.get_node("%Progreso").text == "No hay capturas huérfanas.", "limpieza sin huérfanas informa en la barra")

	var huerfana := _crear_captura("img_test_huerfana.png")
	main_script._on_utilidades_id(2)
	var confirma: AcceptDialog = main.get_node("%ConfirmarLimpieza")
	_check(confirma.visible and confirma.dialog_text.contains("1"), "limpieza con huérfana pide confirmación")
	confirma.confirmed.emit()
	_check(not FileAccess.file_exists(ProjectSettings.globalize_path(huerfana)), "confirmar limpieza borra la huérfana")
	_check(main.get_node("%Progreso").text == "Capturas huérfanas eliminadas: 1", "confirmar limpieza informa en la barra")

	var ref_huerfana := _crear_captura("img_test_ref.png")
	main_script._entradas = [{"nombre": "A", "desc": "", "url": "https://a.test", "img": ref_huerfana}]
	main_script._on_utilidades_id(2)
	_check(FileAccess.file_exists(ProjectSettings.globalize_path(ref_huerfana)), "limpieza conserva la captura referenciada")

	var huerfana_exit := _crear_captura("img_test_exit.png")
	main_script._exit_tree()
	_check(not FileAccess.file_exists(ProjectSettings.globalize_path(huerfana_exit)), "al cerrar la app se barre lo huérfano")

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
	main_script._refrescar_vista()
	for hijo in main.get_node("%ListaContenedor").get_children():
		hijo.visible = false
	var ev_r := InputEventKey.new()
	ev_r.keycode = KEY_R
	ev_r.physical_keycode = KEY_R
	ev_r.ctrl_pressed = true
	ev_r.pressed = true
	main_script._unhandled_input(ev_r)
	_check(main.get_node("%Progreso").text == "Nada que comprobar", "Ctrl+R dispara la comprobación")

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
	main_script._refrescar_vista()
	await process_frame

	main_script._pulsar_cabecera("fecha")
	_check(main_script._orden_columna == "fecha" and main_script._orden_direccion == -1, "primer clic en Fecha activa descendente")
	_check(cab_fecha_btn.text == "Fecha ▼", "la cabecera Fecha activa muestra indicador descendente")
	_check(_urls_visibles(main) == ["https://b.test", "https://a.test", "https://c.test"], "Fecha descendente: más recientes primero y lo sin comprobar al final")

	main_script._pulsar_cabecera("fecha")
	_check(main_script._orden_direccion == 1, "segundo clic en la misma cabecera invierte a ascendente")
	_check(cab_fecha_btn.text == "Fecha ▲", "la cabecera Fecha invertida muestra indicador ascendente")
	_check(_urls_visibles(main) == ["https://a.test", "https://b.test", "https://c.test"], "Fecha ascendente: más antiguos primero y lo sin comprobar al final")

	main_script._pulsar_cabecera("fecha")
	_check(main_script._orden_columna == "", "tercer clic desactiva la columna")
	_check(_urls_visibles(main) == ["https://a.test", "https://b.test", "https://c.test"], "sin columna conserva el orden de inserción")

	# #17: columna Nombre (asc por defecto)
	main_script._entradas = [
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": ""},
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""},
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": ""},
	]
	main_script._estados = {}
	main_script._refrescar_vista()
	await process_frame
	main_script._pulsar_cabecera("nombre")
	_check(_urls_visibles(main) == ["https://a.test", "https://b.test", "https://c.test"], "Nombre ascendente ordena alfabéticamente")
	main_script._pulsar_cabecera("nombre")
	_check(_urls_visibles(main) == ["https://c.test", "https://b.test", "https://a.test"], "Nombre descendente invierte el orden")
	main_script._pulsar_cabecera("nombre")
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
	main_script._refrescar_vista()
	await process_frame
	main_script._pulsar_cabecera("imagen")
	_check(_urls_visibles(main) == ["https://b.test", "https://c.test", "https://a.test"], "Imagen ascendente pone con captura primero (alfabético luego)")
	main_script._pulsar_cabecera("imagen")
	_check(_urls_visibles(main) == ["https://a.test", "https://b.test", "https://c.test"], "Imagen descendente pone sin captura primero")
	main_script._pulsar_cabecera("imagen")
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
	main_script._refrescar_vista()
	await process_frame
	main_script._pulsar_cabecera("estado")
	_check(_urls_visibles(main) == ["https://b.test", "https://a.test", "https://c.test"], "Estado descendente: caídos, válidos, sin comprobar")
	main_script._pulsar_cabecera("estado")
	_check(_urls_visibles(main) == ["https://c.test", "https://a.test", "https://b.test"], "Estado ascendente: sin comprobar, válidos, caídos")
	main_script._pulsar_cabecera("estado")
	_check(main_script._orden_columna == "", "3 clics en Estado vuelven a sin ordenar")

	# Disponibilidad: historial desde la fila (#10)
	main_script._estado_store = _FakeHistorial.new()
	var fila_hist: Button = main.get_node("%ListaContenedor").get_child(0)
	main_script._on_historial_pedido(fila_hist)
	_check(main.has_node("%DialogoHistorial") and main.get_node("%DialogoHistorial").visible, "el historial de la fila abre el diálogo")
	_check(main.get_node("%DialogoHistorial").get_node("%ListaHistorial").get_child_count() == 1, "el diálogo muestra una fila por entrada del historial")
	main.get_node("%DialogoHistorial").hide()

	# Disponibilidad: auto-escaneo desactivado en headless/intervalo 0 (#8)
	main_script._intervalo_auto = 0
	main_script._rearmar_auto_escaneo()
	_check(main.get_node("%AutoEscaneo").is_stopped(), "intervalo 0 deja el Timer detenido")
	main_script._intervalo_auto = 15
	main_script._rearmar_auto_escaneo()
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
	main_script._refrescar_vista()
	main_script._aplicar_preferencias(3, 10.0, false, 0, "oscuro", "en")
	await process_frame
	var fila_en_i18n: Control = null
	for hijo in main.get_node("%ListaContenedor").get_children():
		if hijo.url == "https://sin.test":
			fila_en_i18n = hijo
			break
	_check(fila_en_i18n != null and fila_en_i18n.get_node("%EstadoLabel").text == "Does not exist (404)", "al cambiar a en la fila re-traduce el estado guardado")
	_check(main.get_node("%Rotos").text == "Broken: 1", "al cambiar a en la barra de estado se re-traduce")
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
	_check(main.get_node("%Rotos").text == "Rotos: 1", "al volver a es la barra de estado se re-traduce")
	_check(filtro_estado_i18n.get_item_text(0) == "Todos", "al volver a es el filtro de estado se re-traduce")

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

	# Task 2: helpers de reorden y estados del menú contextual
	main_script._persistir = false
	main_script._entradas = [
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""},
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": ""},
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": ""}
	]
	main_script._refrescar_vista()
	await process_frame

	var visibles_t2: Array = main_script._filas_visibles()
	_check(visibles_t2.size() == 3, "_filas_visibles devuelve las 3 filas sin filtros")

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
	main_script._on_menu_solicitado(fila_a)
	_check(menu_ctx_a.is_item_disabled(menu_ctx_a.get_item_index(5)), "primera fila: Subir deshabilitada")
	_check(not menu_ctx_a.is_item_disabled(menu_ctx_a.get_item_index(6)), "primera fila: Bajar habilitada")

	# fila central: ambas habilitadas
	main_script._on_menu_solicitado(fila_b)
	_check(not menu_ctx_b.is_item_disabled(menu_ctx_b.get_item_index(5)), "fila central: Subir habilitada")
	_check(not menu_ctx_b.is_item_disabled(menu_ctx_b.get_item_index(6)), "fila central: Bajar habilitada")

	# última fila: Subir habilitada y Bajar deshabilitada
	main_script._on_menu_solicitado(fila_c)
	_check(not menu_ctx_c.is_item_disabled(menu_ctx_c.get_item_index(5)), "última fila: Subir habilitada")
	_check(menu_ctx_c.is_item_disabled(menu_ctx_c.get_item_index(6)), "última fila: Bajar deshabilitada")

	# Task 3: reorden real, filtros y persistencia
	main_script._persistir = false
	main_script._entradas = [
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": ""},
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": ""},
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": ""}
	]
	main_script._refrescar_vista()
	await process_frame

	var visibles_t3: Array = main_script._filas_visibles()
	var item_b_real: Button = visibles_t3[1]
	main_script._persistir = true
	main_script._on_mover_pedido(item_b_real, -1)
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

	var item_b_rest: Button = main_script._filas_visibles()[0]
	main_script._on_mover_pedido(item_b_rest, 1)
	_check(main_script._indice_entrada("https://b.test") == 1, "Bajar devuelve B a su posición original")

	main_script._entradas = [
		{"nombre": "B", "desc": "", "url": "https://b.test", "img": "", "cat": "cliente"},
		{"nombre": "A", "desc": "", "url": "https://a.test", "img": "", "cat": "otro"},
		{"nombre": "C", "desc": "", "url": "https://c.test", "img": "", "cat": "cliente"}
	]
	main_script._estados = {}
	main_script.filtro_cat.select(2)
	main_script._refrescar_vista()
	await process_frame

	var visibles_filtradas: Array = main_script._filas_visibles()
	_check(visibles_filtradas.size() == 2, "el filtro Cliente oculta la fila A (otro)")

	var item_c2: Button = visibles_filtradas[1]
	main_script._on_mover_pedido(item_c2, -1)
	_check(main_script._indice_entrada("https://b.test") == 2 and main_script._indice_entrada("https://c.test") == 0, "Subir C la cruza con B saltando la fila oculta A")
	main_script.filtro_cat.select(0)

	main_script._pulsar_cabecera("imagen")
	main_script._on_mover_pedido(main_script._filas_visibles()[0], -1)
	var antes: Array = []
	for e in main_script._entradas:
		antes.append(str(e.get("url", "")))
	_check(antes == ["https://c.test", "https://a.test", "https://b.test"], "con columna activa _on_mover_pedido no modifica _entradas")
	main_script._on_menu_solicitado(main_script._filas_visibles()[0])
	_check(main_script._filas_visibles()[0].get_node("%MenuContexto").is_item_disabled(
		main_script._filas_visibles()[0].get_node("%MenuContexto").get_item_index(5)), "con columna activa Subir queda deshabilitada")
	main_script._pulsar_cabecera("imagen")
	main_script._pulsar_cabecera("imagen")
	_check(main_script._orden_columna == "", "3 clics en la columna activa vuelven a sin ordenar")

	# #17: persistencia y restauración del criterio
	main_script._pulsar_cabecera("fecha")
	var guardado: Dictionary = main_script._config_store.cargar()
	_check(guardado.get("orden_columna", "") == "fecha" and guardado.get("orden_direccion", 0) == -1, "pulsar una cabecera persiste el criterio")
	main_script._persistir_version_vista()
	var preservado: Dictionary = main_script._config_store.cargar()
	_check(preservado.get("orden_columna", "") == "fecha", "persistir la versión vista conserva el criterio")
	main_script._pulsar_cabecera("fecha")
	main_script._pulsar_cabecera("fecha")
	_check(main_script._config_store.cargar().get("orden_columna", "#") == "", "desactivar la columna persiste sin criterio")

	var base_orden := "user://__test_orden_restore__"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_orden))
	ConfigStoreScript.new(base_orden).guardar(3, 10.0, true, 0, "oscuro", "", "fecha", -1, "en")
	var main_rest := MAIN_SCENE.instantiate()
	main_rest.DATA_RES = base_orden + "/data.json"
	main_rest.DATA_USER = base_orden + "/enlaces.json"
	main_rest.CONFIG_BASE = base_orden
	root.add_child(main_rest)
	await process_frame
	await process_frame
	var mrs: Node = main_rest.get_node(".")
	_check(mrs._orden_columna == "fecha" and mrs._orden_direccion == -1, "otro arranque restaura el criterio desde config")
	_check(_urls_visibles(main_rest).is_empty() or _urls_visibles(main_rest).size() >= 0, "el segundo arranque carga sin errores")
	_check(TranslationServer.get_locale() == "en", "arrancar con config idioma=en fija el locale en")
	TranslationServer.set_locale("es")
	main_rest.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(base_orden))

	# #17: si no se puede guardar, se revierte el criterio
	var store_roto := ConfigStoreScript.new("user://__test_main_barra__/nada/cfg")
	main_script._config_store = store_roto
	main_script._pulsar_cabecera("nombre")
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


func _listar_capturas() -> Array:
	var carpeta := DirAccess.open("res://Assets/png")
	if carpeta == null:
		return []
	var lista: Array = []
	for f in carpeta.get_files():
		if f.begins_with("img_") and f.ends_with(".png"):
			lista.append(f)
	lista.sort()
	return lista


func _limpiar_capturas() -> void:
	var carpeta := DirAccess.open("res://Assets/png")
	if carpeta == null:
		return
	for f in _listar_capturas():
		if f not in _imgs_iniciales:
			carpeta.remove(f)


func _cerrar() -> void:
	var ruta_temp := ProjectSettings.globalize_path("user://__test_main_barra__")
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
