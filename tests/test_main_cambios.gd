extends SceneTree

class _FakeStore extends RefCounted:
	func volcar() -> bool:
		return true
	func cargar() -> Dictionary:
		return {"estados": {}}
	func guardar_estado(_clave: String, _valido, _mensaje: String, _codigo: int, _intentos: int, _motivo: String, _url_final: String) -> void:
		pass
	func borrar_estado(_clave: String) -> bool:
		return true

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const ConfigStoreScript := preload("res://scripts/config_store.gd")
const CambiosStoreScript := preload("res://scripts/cambios_store.gd")
const Ayuda := preload("res://tests/ayuda.gd")

const BASE := "user://__test_main_cambios__"

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE))
	ConfigStoreScript.new(BASE).guardar(3, 10.0, false, 0, "oscuro", "", "", 1, "es")
	TranslationServer.set_locale("es")
	var main := MAIN_SCENE.instantiate()
	main.DATA_RES = "%s/data.json" % BASE
	main.DATA_USER = "%s/enlaces.json" % BASE
	main.CONFIG_BASE = BASE
	main.ASSETS_BASE = "%s/Assets" % BASE
	root.add_child(main)

	await process_frame
	await process_frame

	if not main.has_node("%DialogoCambios"):
		_check(false, "la ventana de cambios esta cableada en Main")
		_cerrar()
		return

	var s = main.get_node(".")
	s._persistir = false
	s._estado_store = _FakeStore.new()
	s._cambios.ruta = "%s/pendientes.json" % BASE
	s._cambios.borrar_pendientes()
	s._entradas = [
		{"nombre": "Servidor A", "desc": "", "url": "https://a.test", "img": ""},
		{"nombre": "Servidor B", "desc": "", "url": "https://b.test", "img": ""},
	]
	s._estados = {
		"a.test": {"valido": true, "mensaje": "OK", "codigo": 200, "fecha": 1},
		"b.test": {"valido": true, "mensaje": "OK", "codigo": 200, "fecha": 1},
	}
	s._ui_refrescar()
	await process_frame

	_menu(s)
	await _marca_tras_cambios(s)
	await _escaneo_con_cambios(main, s)
	await _filtro_y_dashboard(s)
	_al_salir(main, s)
	_cerrar()


func _menu(s) -> void:
	var utilidades: PopupMenu = s.get_node("%Utilidades")
	var ultimo := utilidades.item_count - 1
	_check(utilidades.get_item_text(ultimo - 1) == "Viendo cambios…", "el menu de utilidades ofrece ver los cambios")
	_check(utilidades.get_item_id(ultimo - 1) == 6, "la entrada de cambios tiene su propio identificador")
	_check(utilidades.get_item_id(ultimo) == 7, "purgar instantáneas tiene su propio identificador (#60)")


func _marca_de(s, clave: String) -> String:
	for fila in s._ui_filas_visibles():
		if str(fila.url) == "https://%s" % clave:
			return str(fila.get_node("%MarcaCambio").text)
	return "fila no encontrada"


func _marca_tras_cambios(s) -> void:
	s._estado_previo = {
		"a.test": {"valido": true, "mensaje": "OK", "codigo": 200, "fecha": 1},
		"b.test": {"valido": false, "mensaje": "Connection refused", "codigo": 0, "fecha": 1},
	}
	s._estados = {
		"a.test": {"valido": false, "mensaje": "Connection refused", "codigo": 0, "fecha": 2},
		"b.test": {"valido": true, "mensaje": "OK", "codigo": 200, "fecha": 2},
	}
	s._cambios_al_terminar()
	s._ui_refrescar()
	await process_frame
	_check(_marca_de(s, "a.test") == "cambió", "un enlace que pasa a caido queda marcado en la lista")
	_check(_marca_de(s, "b.test") == "cambió", "un enlace que se recupera tambien queda marcado")
	_check(s._cambios.marca_de("a.test") == "caido", "el marcado de A es el de caido")
	_check(s._cambios.marca_de("b.test") == "valido", "el marcado de B es el de valido")
	_check(_tooltip_de(s, "a.test").contains("caído"), "el aviso al pasar el raton explica que esta caido")
	_check(_tooltip_de(s, "b.test").contains("válido"), "y el de un enlace recuperado explica que esta valido")
	await _recomprobar_limpia_la_marca(s)

	s._estados["b.test"] = {"valido": false, "mensaje": "Not Found", "codigo": 404, "fecha": 3}
	s._cambios_al_terminar()
	s._ui_refrescar()
	await process_frame
	_check(_marca_de(s, "a.test").is_empty(), "el escaneo siguiente borra las marcas del anterior")
	_check(_marca_de(s, "b.test") == "cambió", "y marca lo que ha cambiado en esta pasada")

	s._cambios_al_terminar()
	s._ui_refrescar()
	await process_frame
	_check(_marca_de(s, "b.test").is_empty(), "un escaneo sin cambios deja las filas sin marcar")


func _recomprobar_limpia_la_marca(s) -> void:
	for fila in s._ui_filas_visibles():
		if str(fila.url) == "https://a.test":
			s._scan_item_actualizado(fila)
			break
	await process_frame
	_check(_marca_de(s, "a.test").is_empty(), "al recomprobar un enlace su marca se va hasta saber el resultado")


func _tooltip_de(s, clave: String) -> String:
	for fila in s._ui_filas_visibles():
		if str(fila.url) == "https://%s" % clave:
			return str(fila.get_node("%MarcaCambio").tooltip_text)
	return ""


func _escaneo_con_cambios(main, s) -> void:
	s._estados = {"a.test": {"valido": true, "mensaje": "OK", "codigo": 200, "fecha": 1}}
	s._estado_previo = {"a.test": {"valido": true, "mensaje": "OK", "codigo": 200, "fecha": 1}}
	s._cambios.borrar_pendientes()

	var ventana: Window = main.get_node("%DialogoCambios")
	ventana.visible = false
	s._estados["a.test"] = {"valido": false, "mensaje": "Connection refused", "codigo": 0, "fecha": 9}
	s._cambios_al_terminar()

	_check(s._estado_previo.get("a.test", {}).get("fecha", 0) == 9, "al terminar el escaneo la base queda actualizada")
	_check(s._cambios.marca_de("a.test") == "caido", "el enlace caido queda marcado para la lista")
	_check(s._cambios.leer_pendientes().is_empty(), "en headless no se molesta al usuario ni se guarda nada aun")


func _filtro_y_dashboard(s) -> void:
	var ventana_cambios: Window = s.get_node("%DialogoCambios")
	s._cambios_filtrar_lista()
	_check(s.filtro.selected == 2, "filtrar desde la ventana deja la lista en caidos")

	s._cambios_abrir_dashboard()
	_check(s.dashboard.visible, "abrir el dashboard desde la ventana lo muestra")

	s._persistir = false
	ventana_cambios.hide()


func _al_salir(main, s) -> void:
	s._cambios.borrar_pendientes()
	s._cambios.nuevo_delta(
		{"a.test": {"valido": true, "mensaje": "OK", "codigo": 200}},
		{"a.test": {"valido": false, "mensaje": "Connection refused", "codigo": 0, "fecha": 5}}
	)
	_check(not s._cambios.vistos(), "un cambio aun no visto cuenta como pendiente al salir")
	s._exit_tree()
	_check(s._cambios.leer_pendientes().size() == 1, "al salir la app guarda el cambio que nadie vio")

	s._cambios.marcar_vistos()
	_check(s._cambios.leer_pendientes().is_empty(), "marcar como visto limpia los pendientes")

	s._cambios.nuevo_delta(
		{"a.test": {"valido": true, "mensaje": "OK", "codigo": 200}},
		{"a.test": {"valido": false, "mensaje": "Connection refused", "codigo": 0, "fecha": 5}}
	)
	s._exit_tree()
	_check(s._cambios.leer_pendientes().is_empty(), "un cambio ya visto no vuelve a molestarse al salir")


func _cerrar() -> void:
	Ayuda.borrar_arbol(BASE)
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