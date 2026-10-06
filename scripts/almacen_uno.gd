extends AlmacenScript

const AlmacenScript := preload("res://scripts/almacen.gd")
const GestorDatosScript := preload("res://scripts/gestor_datos.gd")
const RutasScript := preload("res://scripts/rutas.gd")

const FICHERO := "gestorao.json"
const S_ENTRADAS := "entradas"
const S_ESTADOS := "estados"
const S_BORRADOS := "borrados"
const S_COLA := "cola"
const S_CONFIG := "config"
const S_INSTANTANEAS := "instantaneas"
const S_PRESETS := "presets"
const S_CAMBIOS := "cambios"
const SECCIONES_FICHERO := [S_ENTRADAS, S_ESTADOS, S_BORRADOS, S_COLA, S_CONFIG, S_INSTANTANEAS, S_PRESETS, S_CAMBIOS]

var _datos: Dictionary = {}
var _hay := false
var _futuro := false


func _init(base_datos := "user://") -> void:
	base = base_datos


func modo() -> String:
	return MODO_UNICO


func assets() -> String:
	return RutasScript.assets_escritura(base)


func ruta_de_nombre(nombre: String) -> String:
	return ruta_de(base, FICHERO)


func abrir() -> bool:
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base)) != OK:
		return false
	_leer()
	abierto = true
	return true


func entradas() -> Array:
	var seccion: Variant = _seccion(S_ENTRADAS)
	if typeof(seccion) != TYPE_DICTIONARY:
		return []
	# El schema_version va dentro de la seccion, igual que en enlaces.json, porque
	# el que decide si esos datos se pueden leer es gestor_datos (#63).
	if int(seccion.get("schema_version", -1)) != GestorDatosScript.SCHEMA_ACTUAL:
		return []
	var e: Variant = seccion.get("entradas", [])
	if typeof(e) != TYPE_ARRAY:
		return []
	return e


func guardar_entradas(lista: Array) -> bool:
	_poner(S_ENTRADAS, {"schema_version": GestorDatosScript.SCHEMA_ACTUAL, "entradas": lista})
	return _persistir()


func estados() -> Dictionary:
	var e: Variant = _seccion(S_ESTADOS)
	return e if typeof(e) == TYPE_DICTIONARY else {}


func estado(clave: String) -> Dictionary:
	var e: Variant = estados().get(clave, {})
	return e if typeof(e) == TYPE_DICTIONARY else {}


func guardar_estado(clave: String, datos: Dictionary) -> bool:
	var todos := estados()
	todos[clave] = datos
	return guardar_estados(todos)


func guardar_estados(todos: Dictionary) -> bool:
	_poner(S_ESTADOS, todos)
	return _persistir()


func historial(clave: String) -> Array:
	var h: Variant = estado(clave).get("historial", [])
	return h if typeof(h) == TYPE_ARRAY else []


func borrar_estado(clave: String) -> bool:
	var todos := estados()
	if not todos.has(clave):
		return true
	todos.erase(clave)
	_poner(S_ESTADOS, todos)
	return _persistir()


func borrados() -> Array:
	var e: Variant = _seccion(S_BORRADOS)
	return e if typeof(e) == TYPE_ARRAY else []


func guardar_borrados(lista: Array) -> bool:
	_poner(S_BORRADOS, lista)
	return _persistir()


func guardar_estados_y_borrados(estados: Dictionary, borrados: Array) -> bool:
	# Las dos cosas en un solo guardado. Con dos escrituras, un corte a mitad
	# dejaba la entrada borrada con su estado, o al reves, que es justo el estado a
	# medias que este backend viene a quitar (#63).
	_poner(S_ESTADOS, estados)
	_poner(S_BORRADOS, borrados)
	return _persistir()


func marcar_borrado(url: String) -> bool:
	var lista := borrados()
	if lista.has(url):
		return true
	lista.append(url)
	return guardar_borrados(lista)


func cola() -> Array:
	var e: Variant = _seccion(S_COLA).get("urls", [])
	return e if typeof(e) == TYPE_ARRAY else []


func guardar_cola(urls: Array) -> bool:
	_poner(S_COLA, {"urls": urls, "fecha": int(Time.get_unix_time_from_system())})
	return _persistir()


func limpiar_cola() -> bool:
	# No se borra el fichero entero: en este backend vive tambien el catalogo, los
	# estados y la configuracion. Solo se vacia la seccion, como en ficheros es
	# borrar colas.json y no user://.
	_poner(S_COLA, {"urls": [], "fecha": 0})
	return _persistir()


func config() -> Dictionary:
	var e: Variant = _seccion(S_CONFIG)
	return e if typeof(e) == TYPE_DICTIONARY else {}


func guardar_config(datos: Dictionary) -> bool:
	_poner(S_CONFIG, datos)
	return _persistir()


func instantaneas() -> Array:
	var e: Variant = _seccion(S_INSTANTANEAS)
	return e if typeof(e) == TYPE_ARRAY else []


func guardar_instantaneas(filas: Array) -> bool:
	_poner(S_INSTANTANEAS, filas)
	return _persistir()


func presets() -> Dictionary:
	var e: Variant = _seccion(S_PRESETS)
	return e if typeof(e) == TYPE_DICTIONARY else {}


func guardar_presets(datos: Dictionary) -> bool:
	_poner(S_PRESETS, datos)
	return _persistir()


func cambios() -> Array:
	var e: Variant = _seccion(S_CAMBIOS)
	return e if typeof(e) == TYPE_ARRAY else []


func guardar_cambios(lista: Array) -> bool:
	_poner(S_CAMBIOS, lista)
	return _persistir()


func capturas() -> Dictionary:
	# Las capturas NO van dentro del fichero, a diferencia de lo que haria el
	# backend de base de datos. Meterlas en base64 dentro del JSON haria que cada
	# guardado del cataleto reescribiera cientos de MB de texto, que es justo lo
	# que este backend viene a evitar. Se quedan como ficheros al lado, que es
	# donde ya estan y donde las manages gestor_imagenes con su slug y su hash.
	var mapa := {}
	for sub in RutasScript.SUBCARPETAS:
		var carpeta := "%s/%s" % [assets(), sub]
		var abs := ProjectSettings.globalize_path(carpeta)
		if not DirAccess.dir_exists_absolute(abs):
			continue
		var dir := DirAccess.open(abs)
		if dir == null:
			continue
		for f in dir.get_files():
			if f.ends_with(".import") or f.ends_with(".tmp") or f.ends_with(".bak"):
				continue
			mapa["%s/%s" % [sub, f]] = "%s/%s" % [carpeta, f]
	return mapa


func guardar_captura(nombre: String, origen: String) -> Dictionary:
	if nombre.is_empty():
		return {"ok": false, "error": "La captura no tiene nombre."}
	var destino := "%s/%s" % [assets(), nombre]
	if destino == origen:
		return {"ok": true, "destino": destino, "error": ""}
	if not FileAccess.file_exists(origen):
		return {"ok": false, "error": "No se encontro el origen."}
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destino.get_base_dir())) != OK:
		return {"ok": false, "error": "No se pudo crear la carpeta de imagenes."}
	if DirAccess.copy_absolute(ProjectSettings.globalize_path(origen), ProjectSettings.globalize_path(destino)) != OK:
		return {"ok": false, "error": "No se pudo copiar la imagen."}
	return {"ok": true, "destino": destino, "error": ""}


func borrar_captura(nombre: String) -> bool:
	var ruta := "%s/%s" % [assets(), nombre]
	if not FileAccess.file_exists(ruta):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta)) == OK


func rutas() -> Dictionary:
	return {
		"modo": modo(),
		"base": base,
		"ficheros": [ruta_de_nombre(FICHERO)],
		"carpetas": [base, assets()],
	}


func hay_copia() -> bool:
	return FileAccess.file_exists(ruta_de_nombre(FICHERO) + ".bak")


func restaurar_copia() -> bool:
	# El .bak de este backend es el fichero entero, no solo el catalogo: al
	# restaurarlo vuelven tambien estados, borrados, cola, configuracion,
	# instantaneas, presets y cambios pendientes. Por eso no se puede delegar en
	# gestor_datos, que solo sabe leer un {"schema_version", "entradas"}.
	if not hay_copia():
		return false
	var bak := ProjectSettings.globalize_path(ruta_de_nombre(FICHERO) + ".bak")
	if DirAccess.copy_absolute(bak, ProjectSettings.globalize_path(ruta_de_nombre(FICHERO))) != OK:
		return false
	_leer()
	return true


func seccion(nombre: String) -> Variant:
	return _seccion(nombre)


func bloqueado() -> bool:
	return _futuro


func _seccion(nombre: String) -> Variant:
	var e: Variant = (_datos.get("secciones", {}) as Dictionary).get(nombre, null)
	return e if e != null else {}


func _poner(nombre: String, valor: Variant) -> void:
	var secciones := _datos.get("secciones", {}) as Dictionary
	secciones[nombre] = valor
	_datos["secciones"] = secciones


func _persistir() -> bool:
	if _futuro:
		# Hay un gestoror mas nuevo usando este fichero. Se puede leer (lo que se
		# entienda) pero no escribir: un guardado aqui dejaria el catalogo de la
		# otra version en un fichero con la forma de esta, y al siguiente arranque
		# no habria forma de saber que se perdio (#63).
		return false
	var ok := AlmacenScript.escribir_json(ruta_de_nombre(FICHERO), _datos)
	if ok:
		escrituras += 1
	return ok


func _leer() -> void:
	_datos = {}
	_hay = false
	_futuro = false
	var dato: Variant = AlmacenScript.leer_json(ruta_de_nombre(FICHERO))
	if typeof(dato) != TYPE_DICTIONARY:
		_datos = {"esquema": ESQUEMA_ACTUAL, "modo": MODO_UNICO, "secciones": {}}
		return
	if int(dato.get("esquema", 0)) > ESQUEMA_ACTUAL:
		# Un gestoror nuevo abrio un fichero de una version posterior. No se toca:
		# sobreescribirlo perderia datos que esta version no sabe leer.
		_futuro = true
		_datos = {"esquema": ESQUEMA_ACTUAL, "modo": MODO_UNICO, "secciones": {}}
		return
	if typeof(dato.get("secciones", null)) != TYPE_DICTIONARY:
		dato["secciones"] = {}
	dato["esquema"] = ESQUEMA_ACTUAL
	dato["modo"] = MODO_UNICO
	_datos = dato
	_hay = true
