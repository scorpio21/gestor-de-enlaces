extends SceneTree

# Los stores de verdad, no el backend. #63 los deja de escribir encima del
# destino: config_store.gd abria el fichero en WRITE y, si se cortaba a mitad,
# lo dejaba en cero. Un config.json vacio no es un annoyance pequeno: son todos
# los ajustes del usuario de golpe, y no hay forma de recuperarlos.
#
# Por que mirar el .bak y no "se sigue pudiendo leer": un truncate de un fichero
# pequeno suele acabar en un JSON truncado que el parser rechaza, y a veces en
# uno que si parsea con menos campos. Lo que se comprueba aqui es que la version
# anterior esta entera en algun sitio, no solo que el nuevo se lea.

const AlmacenScript := preload("res://scripts/almacen.gd")
const ConfigStore := preload("res://scripts/config_store.gd")
const ColaStore := preload("res://scripts/cola_store.gd")
const EstadoStore := preload("res://scripts/estado_store.gd")
const InstantaneaStore := preload("res://scripts/instantanea_store.gd")

const BASE := "user://__test_almacen_stores__"
const NOMBRES := ["config.json", "colas.json", "estados.json", "borrados.json", "instantaneas.json"]

var _fallos := 0


func _initialize() -> void:
	_limpiar()
	_check(config_deja_copia(), "config.json guarda una copia .bak de la version anterior (#63)")
	_check(config_no_deja_tmp(), "config.json no deja un .tmp a medias (#63)")
	_check(config_bak_es_el_anterior(), "el .bak de config.json es la version previa, no la nueva (#63)")
	_check(config_se_relee(), "config.json sigue siendo valido despues de escribir dos veces (#63)")
	_check(cola_deja_copia(), "colas.json guarda una copia .bak (#63)")
	_check(cola_no_deja_tmp(), "colas.json no deja un .tmp a medias (#63)")
	_check(cola_se_relee(), "colas.json devuelve lo ultimo guardado (#63)")
	_check(cola_con_hueco(), "la copia se hace antes de quitar el destino (#63)")
	_check(estado_sigue_atomico(), "estado_store.gd sigue dejando su .bak (#63)")
	_check(instantaneas_sigue_atomica(), "instantanea_store.gd sigue dejando su .bak (#63)")
	_limpiar()
	_check(escribir_devuelve_false_sin_destino(), "una ruta imposible devuelve false y no revienta (#63)")
	if _fallos == 0:
		print("TESTS OK")
		quit(0)
		return
	print("TESTS FALLIDOS: %d" % _fallos)
	quit(1)


func _limpiar() -> void:
	# La carpeta se crea a proposito: config_store e instantanea_store no la crean
	# ellos (asumen user://), asi que sin esto sus escrituras fallarian y el
	# test mediria el fallo del directorio, no el de la atomicidad.
	DirAccess.make_dir_recursive_absolute(BASE)
	for nombre in NOMBRES:
		for sufijo in ["", ".tmp", ".bak"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s%s" % [BASE, nombre, sufijo]))


func _leer(nombre: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [BASE, nombre]))


func config_deja_copia() -> bool:
	var store = ConfigStore.new(BASE)
	store.guardar(3, 10.0)
	store.guardar(5, 12.0)
	return FileAccess.file_exists("%s/config.json.bak" % BASE)


func config_no_deja_tmp() -> bool:
	var store = ConfigStore.new(BASE)
	store.guardar(2, 9.0)
	store.guardar(7, 13.0)
	return not FileAccess.file_exists("%s/config.json.tmp" % BASE)


func config_bak_es_el_anterior() -> bool:
	# Si el .bak fuera una copia del fichero nuevo no serviria de nada: el
	# objetivo es poder volver atras, no tener el dato dos veces.
	var store = ConfigStore.new(BASE)
	store.guardar(3, 10.0)
	store.guardar(5, 12.0)
	var previo: Variant = _leer("config.json.bak")
	if typeof(previo) != TYPE_DICTIONARY:
		return false
	return int((previo as Dictionary).get("paralelismo", 0)) == 3


func config_se_relee() -> bool:
	var store = ConfigStore.new(BASE)
	store.guardar(6, 21.0)
	var leido: Dictionary = ConfigStore.new(BASE).cargar()
	return int(leido.get("paralelismo", 0)) == 6 and is_equal_approx(float(leido.get("timeout", 0.0)), 21.0)


func cola_deja_copia() -> bool:
	var store = ColaStore.new(BASE)
	store.guardar(["https://a.com/"])
	store.guardar(["https://a.com/", "https://b.com/"])
	return FileAccess.file_exists("%s/colas.json.bak" % BASE)


func cola_no_deja_tmp() -> bool:
	var store = ColaStore.new(BASE)
	store.guardar(["https://a.com/"])
	store.guardar(["https://c.com/"])
	return not FileAccess.file_exists("%s/colas.json.tmp" % BASE)


func cola_se_relee() -> bool:
	var store = ColaStore.new(BASE)
	store.guardar(["https://a.com/", "https://b.com/"])
	store.guardar(["https://d.com/"])
	return (store.cargar().get("urls", []) as Array) == ["https://d.com/"]


func cola_con_hueco() -> bool:
	# La version vieja quitaba el destino antes de renombrar el .tmp. Entre una
	# cosa y otra no habia colas.json: otro proceso, o el propio backup del
	# sistema, podia encontrarse con que el fichero no existia. Con la copia a
	# .bak siempre hay una version anterior en disco.
	var store = ColaStore.new(BASE)
	store.guardar(["https://a.com/"])
	store.guardar(["https://e.com/"])
	if not FileAccess.file_exists("%s/colas.json.bak" % BASE):
		return false
	var previa: Variant = _leer("colas.json.bak")
	if typeof(previa) != TYPE_DICTIONARY:
		return false
	return ((previa as Dictionary).get("urls", []) as Array) == ["https://a.com/"]


func estado_sigue_atomico() -> bool:
	var store = EstadoStore.new(BASE)
	store.guardar_estado("https://s.com/", true, "OK (200)", 200)
	store.volcar()
	store.guardar_estado("https://s.com/", false, "No existe (404)", 404)
	store.volcar()
	var estados: Dictionary = store.cargar().get("estados", {})
	return FileAccess.file_exists("%s/estados.json.bak" % BASE) \
		and not FileAccess.file_exists("%s/estados.json.tmp" % BASE) \
		and int(estados.get("https://s.com/", {}).get("codigo", 0)) == 404


func instantaneas_sigue_atomica() -> bool:
	# Dos llamadas del mismo dia reemplazan la fila, no la anaden: aqui lo que
	# interesa es que la segunda escritura haya dejado copia de la primera.
	var store = InstantaneaStore.new(BASE)
	store.guardar([{"url": "https://a.com/", "nombre": "A", "cat": "", "tags": []}], {"https://a.com/": {"valido": true}})
	store.guardar([{"url": "https://b.com/", "nombre": "B", "cat": "", "tags": []}], {"https://b.com/": {"valido": false}})
	if not FileAccess.file_exists("%s/instantaneas.json.bak" % BASE):
		return false
	if FileAccess.file_exists("%s/instantaneas.json.tmp" % BASE):
		return false
	var filas := store.cargar()
	return filas.size() == 1 and int((filas[0] as Dictionary).get("total", 0)) == 1


func escribir_devuelve_false_sin_destino() -> bool:
	# Sin esto, un disco lleno o un user:// de solo lectura se traduce en un
	# "guardado" que en realidad no ha guardado nada, y el usuario se entera
	# tres sesiones despues.
	var base_imposible := "user://__no_se_puede__/a/b/c"
	if not AlmacenScript.escribir_json("%s/config.json" % base_imposible, {"a": 1}):
		return true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(base_imposible))
	return false


func _check(condicion: bool, etiqueta: String) -> void:
	if condicion:
		print("  OK: %s" % etiqueta)
	else:
		_fallos += 1
		push_error("FALLO: %s" % etiqueta)