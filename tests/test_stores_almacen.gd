extends SceneTree

# Los stores escriben por la interfaz del almacenamiento cuando este no es el de
# ficheros (#63). Aquí se comprueba lo contrario de test_almacen_uno, que mira el
# backend: que cada store caiga de verdad en él y no se quede con su fichero de
# siempre, que en un solo fichero sería guardar en un sitio y leer de otro.

const MAIN_SCENE := preload("res://scenes/Main.tscn")
const AlmacenUno := preload("res://scripts/almacen_uno.gd")
const AlmacenScript := preload("res://scripts/almacen.gd")
const AlmacenController := preload("res://scripts/almacen_controller.gd")
const ConfigStore := preload("res://scripts/config_store.gd")
const ColaStore := preload("res://scripts/cola_store.gd")
const EstadoStore := preload("res://scripts/estado_store.gd")
const InstantaneaStore := preload("res://scripts/instantanea_store.gd")
const PresetsStore := preload("res://scripts/presets_store.gd")
const CambiosController := preload("res://scripts/cambios_controller.gd")

const BASE := "user://__test_stores_almacen__"
const FICHERO := "gestorao.json"

var _fallos := 0


func _initialize() -> void:
	_arrancar()


func _arrancar() -> void:
	_borrar_arbol(BASE)
	_check(para_stores_solo_fuera_de_ficheros(), "para_stores() entrega el backend salvo en modo ficheros (#63)")
	_check(config_store_escribe_por_interfaz(), "config_store escribe en el fichero único y no en config.json (#63)")
	_check(cola_store_escribe_por_interfaz(), "cola_store escribe en el fichero único y no en colas.json (#63)")
	_check(estado_store_vuelca_por_interfaz(), "estado_store vuelca estados y borrados por la interfaz (#63)")
	_check(instantanea_store_escribe_por_interfaz(), "instantanea_store escribe en el fichero único (#63)")
	_check(presets_store_escribe_por_interfaz(), "presets_store escribe en el fichero único (#63)")
	_check(cambios_escribe_por_interfaz(), "los cambios pendientes van al fichero único (#63)")
	_check(limpiar_no_borra_el_fichero(), "limpiar la cola o las instantáneas no borra el resto (#63)")
	_check(sin_almacen_siguen_en_su_fichero(), "sin backend cada store sigue en su fichero de siempre (#63)")
	_check(entradas_respeta_la_ruta_en_ficheros(), "en modo ficheros el catálogo se lee y se escribe en la ruta que se le pasa (#63)")
	_check(entradas_en_unico_ignora_la_ruta(), "en modo único no existe enlaces.json y la ruta se ignora (#63)")
	_check(copia_respeta_la_ruta_en_ficheros(), "la copia de seguridad en modo ficheros es la de esa ruta (#63)")
	_check(copia_en_unico_es_del_fichero(), "la copia de seguridad en modo único es la del fichero entero (#63)")
	_check(fichero_futuro_bloquea_al_controlador(), "un fichero de una versión posterior avisa y no se puede escribir (#63)")
	await principal_conecta_los_stores()
	await principal_conecta_los_stores_bd()
	_borrar_arbol(BASE)
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
		return
	_fallos += 1
	print("  FALLO: %s" % etiqueta)


func _fresca(nombre: String) -> String:
	var ruta := "%s/%s" % [BASE, nombre]
	_borrar_arbol(ruta)
	DirAccess.make_dir_recursive_absolute(ruta)
	return ruta


func _borrar_arbol(ruta: String) -> void:
	var abs := ProjectSettings.globalize_path(ruta)
	if not DirAccess.dir_exists_absolute(abs):
		return
	var dir := DirAccess.open(abs)
	if dir == null:
		return
	for sub in dir.get_directories():
		_borrar_arbol("%s/%s" % [ruta, sub])
	for f in dir.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [ruta, f]))
	DirAccess.remove_absolute(abs)


func _nuevo(base: String) -> RefCounted:
	var a := AlmacenUno.new(base)
	a.abrir()
	return a


func _ctrl(base: String, modo: String) -> AlmacenController:
	return AlmacenController.new(PackedStringArray(), base, {"modo": modo, "base": base})


func para_stores_solo_fuera_de_ficheros() -> bool:
	var base := _fresca("rutas")
	var unico := _ctrl(base, "unico")
	var ficheros := _ctrl(base, "ficheros")
	var base_datos := _ctrl(base, "base_datos")
	return unico.para_stores() != null and unico.para_stores().modo() == AlmacenScript.MODO_UNICO \
		and ficheros.para_stores() == null \
		and base_datos.para_stores() != null and base_datos.para_stores().modo() == AlmacenScript.MODO_BASE_DATOS


func config_store_escribe_por_interfaz() -> bool:
	var base := _fresca("config")
	var store = ConfigStore.new(base, _nuevo(base))
	if not store.guardar(4, 11.0):
		return false
	if FileAccess.file_exists("%s/config.json" % base):
		return false
	var otras = ConfigStore.new(base, _nuevo(base))
	var leida: Dictionary = otras.cargar()
	return int(leida.get("paralelismo", 0)) == 4 and is_equal_approx(float(leida.get("timeout", 0.0)), 11.0)


func cola_store_escribe_por_interfaz() -> bool:
	var base := _fresca("cola")
	var store = ColaStore.new(base, _nuevo(base))
	store.guardar(["https://a.com/"])
	store.guardar(["https://a.com/", "https://b.com/"])
	if FileAccess.file_exists("%s/colas.json" % base):
		return false
	var otras = ColaStore.new(base, _nuevo(base))
	return (otras.cargar().get("urls", []) as Array) == ["https://a.com/", "https://b.com/"]


func estado_store_vuelca_por_interfaz() -> bool:
	var base := _fresca("estados")
	var store = EstadoStore.new(base, _nuevo(base))
	store.guardar_estado("https://s.com/", true, "OK (200)", 200)
	store.marcar_borrado("https://s.com/")
	if FileAccess.file_exists("%s/estados.json" % base) or FileAccess.file_exists("%s/borrados.json" % base):
		return false
	var otras = EstadoStore.new(base, _nuevo(base))
	var datos: Dictionary = otras.cargar()
	var estados: Dictionary = datos.get("estados", {})
	var e: Dictionary = estados.get("https://s.com/", {})
	return int(e.get("codigo", 0)) == 200 and (datos.get("borrados", []) as Array) == ["https://s.com/"] \
		and otras.historial_de("https://s.com/").size() == 1


func instantanea_store_escribe_por_interfaz() -> bool:
	var base := _fresca("instantaneas")
	var store = InstantaneaStore.new(base, _nuevo(base))
	var res: Dictionary = store.guardar(
		[{"url": "https://a.com/", "nombre": "A", "cat": "", "tags": []}],
		{"https://a.com/": {"valido": true}}
	)
	if not res.get("ok", false) or FileAccess.file_exists("%s/instantaneas.json" % base):
		return false
	var filas := InstantaneaStore.new(base, _nuevo(base)).cargar()
	return filas.size() == 1 and int((filas[0] as Dictionary).get("total", 0)) == 1


func presets_store_escribe_por_interfaz() -> bool:
	var base := _fresca("presets")
	var store = PresetsStore.new(base, _nuevo(base))
	if not store.guardar({"mio": {"filtro_dias": 7}}):
		return false
	if FileAccess.file_exists("%s/presets_filtros.json" % base):
		return false
	var otras = PresetsStore.new(base, _nuevo(base))
	return int(otras.cargar().get("mio", {}).get("filtro_dias", 0)) == 7


func cambios_escribe_por_interfaz() -> bool:
	var base := _fresca("cambios")
	var ruta := "%s/cambios_pendientes.json" % base
	var cambios := CambiosController.new()
	cambios.ruta = ruta
	cambios.almacen = _nuevo(base)
	if not cambios.guardar_pendientes([{"campo": "nombre", "de": "a", "a": "b"}]):
		return false
	if FileAccess.file_exists(ruta):
		return false
	var otras := CambiosController.new()
	otras.ruta = ruta
	otras.almacen = _nuevo(base)
	return otras.leer_pendientes().size() == 1 and otras.borrar_pendientes() \
		and otras.leer_pendientes().is_empty() and FileAccess.file_exists("%s/%s" % [base, FICHERO])


func limpiar_no_borra_el_fichero() -> bool:
	var base := _fresca("limpiar")
	var a := _nuevo(base)
	a.guardar_entradas([{"nombre": "Uno", "url": "https://a.com"}])
	var cola = ColaStore.new(base, a)
	cola.guardar(["https://c.com/"])
	var instantaneas = InstantaneaStore.new(base, a)
	instantaneas.guardar([{"url": "https://a.com/", "nombre": "A", "cat": "", "tags": []}], {"https://a.com/": {"valido": true}})
	cola.limpiar()
	instantaneas.limpiar()
	var otras := _nuevo(base)
	return otras.cola().is_empty() and otras.instantaneas().is_empty() \
		and otras.entradas().size() == 1 and FileAccess.file_exists("%s/%s" % [base, FICHERO])


func sin_almacen_siguen_en_su_fichero() -> bool:
	var base := _fresca("sin_almacen")
	ConfigStore.new(base).guardar(3, 10.0)
	ColaStore.new(base).guardar(["https://a.com/"])
	var estados = EstadoStore.new(base)
	estados.guardar_estado("https://s.com/", true, "OK (200)", 200)
	estados.volcar()
	var cambios := CambiosController.new()
	cambios.ruta = "%s/cambios_pendientes.json" % base
	cambios.guardar_pendientes([{"campo": "nombre", "de": "a", "a": "b"}])
	var estan := true
	for nombre in ["config.json", "colas.json", "estados.json", "borrados.json", "cambios_pendientes.json"]:
		estan = estan and FileAccess.file_exists("%s/%s" % [base, nombre])
	return estan and not FileAccess.file_exists("%s/%s" % [base, FICHERO])


func entradas_respeta_la_ruta_en_ficheros() -> bool:
	# La ruta que manda es la del que llama, no user://enlaces.json: las suites
	# y cualquier carpeta de datos re-apuntan DATA_USER, y si aquí se ignorara se
	# leería el catálogo real y se le borrarían sus imágenes al limpiar huérfanas.
	var base := _fresca("entradas_ficheros")
	DirAccess.make_dir_recursive_absolute("%s/una" % base)
	DirAccess.make_dir_recursive_absolute("%s/otra" % base)
	var ctrl := _ctrl(base, "ficheros")
	var a := "%s/una/enlaces.json" % base
	var b := "%s/otra/enlaces.json" % base
	var lista := [{"nombre": "Uno", "url": "https://a.com"}]
	if not ctrl.guardar_entradas_en(a, lista):
		return false
	return ctrl.entradas_de(a) == lista and ctrl.entradas_de(b).is_empty() \
		and not FileAccess.file_exists("%s/%s" % [base, FICHERO])


func entradas_en_unico_ignora_la_ruta() -> bool:
	var base := _fresca("entradas_unico")
	var ctrl := _ctrl(base, "unico")
	var ruta := "%s/nada/enlaces.json" % base
	var lista := [{"nombre": "Uno", "url": "https://a.com"}]
	if not ctrl.guardar_entradas_en(ruta, lista):
		return false
	return not FileAccess.file_exists(ruta) \
		and ctrl.entradas_de("user://tampoco_existe__.json") == lista \
		and FileAccess.file_exists("%s/%s" % [base, FICHERO])


func copia_respeta_la_ruta_en_ficheros() -> bool:
	var base := _fresca("copia_ficheros")
	DirAccess.make_dir_recursive_absolute("%s/una" % base)
	var ctrl := _ctrl(base, "ficheros")
	var a := "%s/una/enlaces.json" % base
	var lista := [{"nombre": "Uno", "url": "https://a.com"}]
	ctrl.guardar_entradas_en(a, lista)
	if ctrl.hay_copia(a):
		return false
	ctrl.guardar_entradas_en(a, lista + [{"nombre": "Dos", "url": "https://b.com"}])
	return ctrl.hay_copia(a) and not ctrl.hay_copia("%s/una/otro.json" % base) \
		and ctrl.restaurar_copia(a) and ctrl.entradas_de(a) == lista


func copia_en_unico_es_del_fichero() -> bool:
	var base := _fresca("copia_unico")
	var ctrl := _ctrl(base, "unico")
	var ignorada := "%s/nada/enlaces.json" % base
	if ctrl.hay_copia(ignorada):
		return false
	ctrl.guardar_entradas_en(ignorada, [{"nombre": "Uno", "url": "https://a.com"}])
	ctrl.guardar_entradas_en(ignorada, [{"nombre": "Uno", "url": "https://a.com"}, {"nombre": "Dos", "url": "https://b.com"}])
	return ctrl.hay_copia(ignorada) and ctrl.restaurar_copia(ignorada) \
		and ctrl.entradas_de(ignorada).size() == 1 and not FileAccess.file_exists(ignorada)


func fichero_futuro_bloquea_al_controlador() -> bool:
	var base := _fresca("futuro")
	AlmacenScript.escribir_json("%s/%s" % [base, FICHERO], {"esquema": AlmacenScript.ESQUEMA_ACTUAL + 3, "secciones": {}})
	var ctrl := _ctrl(base, "unico")
	if ctrl.avisos.is_empty() or ctrl.almacen == null or not ctrl.almacen.bloqueado():
		return false
	return not ctrl.guardar_entradas_en("user://da_igual__.json", [{"nombre": "Mio", "url": "https://m.com"}])


func principal_conecta_los_stores() -> void:
	# La comprobación de integración: main no recibe el almacenamiento, lo pide.
	# Los dos variables de entorno son las que usa la app para mudarse de sitio
	# sin tocar almacenamiento.json, y así se prueba en unico() sin acercarse al
	# fichero de configuración real del que esté usando la máquina.
	var base := _fresca("principal")
	var cola_antes := FileAccess.get_file_as_string("user://colas.json")
	var config_antes := FileAccess.get_file_as_string("user://config.json")
	OS.set_environment("GESTORAO_ALMACEN", "unico")
	OS.set_environment("GESTORAO_BASE", base)
	var main := MAIN_SCENE.instantiate()
	main.DATA_RES = "%s/data.json" % base
	main.DATA_USER = "%s/enlaces.json" % base
	main.CONFIG_BASE = base
	main.ASSETS_BASE = "%s/Assets" % base
	root.add_child(main)
	await process_frame
	await process_frame
	var s = main
	var modo_unico: bool = s._almacen != null and s._almacen.almacen != null \
		and s._almacen.almacen.modo() == AlmacenScript.MODO_UNICO
	var conectados := true
	for store in [s._config_store, s._instantanea_store, s._cola_store, s._presets_store, s._estado_store, s._cambios]:
		conectados = conectados and store != null and store.almacen != null
	_check(modo_unico and conectados, "main conecta los seis stores al almacenamiento único (#63)")
	_check(FileAccess.get_file_as_string("user://colas.json") == cola_antes \
		and FileAccess.get_file_as_string("user://config.json") == config_antes,
		"en modo único no se escribe nada de la configuración de user:// (#63)")
	main.free()
	OS.set_environment("GESTORAO_ALMACEN", "")
	OS.set_environment("GESTORAO_BASE", "")


func principal_conecta_los_stores_bd() -> void:
	# El arranque en modo base de datos: _ready() revisa la cola pendiente y eso
	# pasa por cola_store.cargar() -> almacen.seccion("cola"). Aquí se monta la
	# escena entera para que ese camino no se quede sin cubrir (#65).
	var base := _fresca("principal_bd")
	OS.set_environment("GESTORAO_ALMACEN", "base_datos")
	OS.set_environment("GESTORAO_BASE", base)
	var main := MAIN_SCENE.instantiate()
	main.DATA_RES = "%s/data.json" % base
	main.DATA_USER = "%s/enlaces.json" % base
	main.CONFIG_BASE = base
	main.ASSETS_BASE = "%s/Assets" % base
	root.add_child(main)
	await process_frame
	await process_frame
	var s = main
	var modo_bd: bool = s._almacen != null and s._almacen.almacen != null \
		and s._almacen.almacen.modo() == AlmacenScript.MODO_BASE_DATOS
	var conectados := true
	for store in [s._config_store, s._instantanea_store, s._cola_store, s._presets_store, s._estado_store, s._cambios]:
		conectados = conectados and store != null and store.almacen != null
	_check(modo_bd and conectados and FileAccess.file_exists("%s/gestorao.db" % base),
		"main arranca en modo base de datos con los seis stores conectados (#65)")
	var almacen_abierto = s._almacen
	main.free()
	# En Windows un .db con la conexion abierta no se puede borrar: se cierra
	# antes de que la suite limpie su carpeta.
	if almacen_abierto != null:
		almacen_abierto.cerrar()
	OS.set_environment("GESTORAO_ALMACEN", "")
	OS.set_environment("GESTORAO_BASE", "")
