extends SceneTree

class _FakeStore extends RefCounted:
	var ultima_renombrar: Array = []
	func renombrar(url_antigua: String, url_nueva: String) -> bool:
		ultima_renombrar = [url_antigua, url_nueva]
		return true

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const ConfigStoreScript := preload("res://scripts/config_store.gd")

var _fallos := 0
var _imgs_iniciales: Array = []


func _initialize() -> void:
	_arrancar()

func _arrancar() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://__test_main_catalogo__"))
	ConfigStoreScript.new("user://__test_main_catalogo__").guardar(3, 10.0, false, 0, "oscuro", "", "", 1, "es")
	TranslationServer.set_locale("es")
	var main := MAIN_SCENE.instantiate()
	main.DATA_RES = "user://__test_main_catalogo__/data.json"
	main.DATA_USER = "user://__test_main_catalogo__/enlaces.json"
	main.CONFIG_BASE = "user://__test_main_catalogo__"
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
	_check(img_nueva != vieja1 and img_nueva == "res://Assets/png/A.png", "cambiar captura apunta a una captura nombrada según el enlace (#47)")
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

	main_script._persistir = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ref_huerfana))
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
		if f.ends_with(".png") and f != "no-disponible.png":
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
	var ruta_temp := ProjectSettings.globalize_path("user://__test_main_catalogo__")
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