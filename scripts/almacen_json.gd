extends AlmacenScript

const AlmacenScript := preload("res://scripts/almacen.gd")
const GestorDatosScript := preload("res://scripts/gestor_datos.gd")
const RutasScript := preload("res://scripts/rutas.gd")

const F_ENLACES := "enlaces.json"
const F_ESTADOS := "estados.json"
const F_BORRADOS := "borrados.json"
const F_COLAS := "colas.json"
const F_CONFIG := "config.json"
const F_INSTANTANEAS := "instantaneas.json"
const F_PRESETS := "presets_filtros.json"
const F_CAMBIOS := "cambios_pendientes.json"
const FICHEROS := [F_ENLACES, F_ESTADOS, F_BORRADOS, F_COLAS, F_CONFIG, F_INSTANTANEAS, F_PRESETS, F_CAMBIOS]


func _init(base_datos := "user://") -> void:
	base = base_datos


func modo() -> String:
	return MODO_FICHEROS


func assets() -> String:
	return RutasScript.assets_escritura(base)


func ruta_de_nombre(nombre: String) -> String:
	return ruta_de(base, nombre)


func abrir() -> bool:
	# Siempre, tambien para user://, que ya existe pero por si la primera vez:
	# sin la carpeta los ocho ficheros se van a make_dir uno a uno en el primer
	# guardado, y solo el primero falla con un error poco claro.
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base)) != OK:
		return false
	abierto = true
	return true


func entradas() -> Array:
	return GestorDatosScript.cargar(ruta_de_nombre(F_ENLACES))


func guardar_entradas(lista: Array) -> bool:
	var ok := GestorDatosScript.guardar(ruta_de_nombre(F_ENLACES), lista)
	if ok:
		escrituras += 1
	return ok


func estados() -> Dictionary:
	var dato: Variant = AlmacenScript.leer_json(ruta_de_nombre(F_ESTADOS))
	return dato if typeof(dato) == TYPE_DICTIONARY else {}


func estado(clave: String) -> Dictionary:
	var e: Variant = estados().get(clave, {})
	return e if typeof(e) == TYPE_DICTIONARY else {}


func guardar_estado(clave: String, datos: Dictionary) -> bool:
	var todos := estados()
	todos[clave] = datos
	return guardar_estados(todos)


func guardar_estados(todos: Dictionary) -> bool:
	return _escribir(ruta_de_nombre(F_ESTADOS), todos)


func historial(clave: String) -> Array:
	var h: Variant = estado(clave).get("historial", [])
	return h if typeof(h) == TYPE_ARRAY else []


func borrar_estado(clave: String) -> bool:
	var todos := estados()
	if not todos.has(clave):
		return true
	todos.erase(clave)
	return _escribir(ruta_de_nombre(F_ESTADOS), todos)


func borrados() -> Array:
	var dato: Variant = AlmacenScript.leer_json(ruta_de_nombre(F_BORRADOS))
	return dato if typeof(dato) == TYPE_ARRAY else []


func guardar_borrados(lista: Array) -> bool:
	return _escribir(ruta_de_nombre(F_BORRADOS), lista)


func marcar_borrado(url: String) -> bool:
	var lista := borrados()
	if lista.has(url):
		return true
	lista.append(url)
	return guardar_borrados(lista)


func cola() -> Array:
	var dato: Variant = AlmacenScript.leer_json(ruta_de_nombre(F_COLAS))
	if typeof(dato) != TYPE_DICTIONARY:
		return []
	var u: Variant = (dato as Dictionary).get("urls", [])
	return u if typeof(u) == TYPE_ARRAY else []


func guardar_cola(urls: Array) -> bool:
	return _escribir(ruta_de_nombre(F_COLAS), {"urls": urls, "fecha": int(Time.get_unix_time_from_system())})


func limpiar_cola() -> bool:
	var ruta := ruta_de_nombre(F_COLAS)
	if not FileAccess.file_exists(ruta):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta)) == OK


func config() -> Dictionary:
	var dato: Variant = AlmacenScript.leer_json(ruta_de_nombre(F_CONFIG))
	return dato if typeof(dato) == TYPE_DICTIONARY else {}


func guardar_config(datos: Dictionary) -> bool:
	return _escribir(ruta_de_nombre(F_CONFIG), datos)


func instantaneas() -> Array:
	var dato: Variant = AlmacenScript.leer_json(ruta_de_nombre(F_INSTANTANEAS))
	return dato if typeof(dato) == TYPE_ARRAY else []


func guardar_instantaneas(filas: Array) -> bool:
	return _escribir(ruta_de_nombre(F_INSTANTANEAS), filas)


func presets() -> Dictionary:
	var dato: Variant = AlmacenScript.leer_json(ruta_de_nombre(F_PRESETS))
	return dato if typeof(dato) == TYPE_DICTIONARY else {}


func guardar_presets(datos: Dictionary) -> bool:
	return _escribir(ruta_de_nombre(F_PRESETS), datos)


func cambios() -> Array:
	var dato: Variant = AlmacenScript.leer_json(ruta_de_nombre(F_CAMBIOS))
	return dato if typeof(dato) == TYPE_ARRAY else []


func guardar_cambios(lista: Array) -> bool:
	return _escribir(ruta_de_nombre(F_CAMBIOS), lista)


func capturas() -> Dictionary:
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
	escrituras += 1
	return {"ok": true, "destino": destino, "error": ""}


func borrar_captura(nombre: String) -> bool:
	var ruta := "%s/%s" % [assets(), nombre]
	if not FileAccess.file_exists(ruta):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta)) == OK


func hay_copia() -> bool:
	return GestorDatosScript.hay_copia(ruta_de_nombre(F_ENLACES))


func restaurar_copia() -> bool:
	return GestorDatosScript.restaurar_copia(ruta_de_nombre(F_ENLACES))


func rutas() -> Dictionary:
	# La base entera, no los ocho ficheros sueltos: tamano_total() la recorre y
	# asi los Assets cuelgan de la misma cifra. Los ficheros se listan aparte
	# porque Preferencias los ensena uno a uno.
	var ficheros := FICHEROS.duplicate()
	return {
		"modo": modo(),
		"base": base,
		"ficheros": ficheros.map(ruta_de_nombre),
		"carpetas": [base, assets()],
	}


func _escribir(ruta: String, dato: Variant) -> bool:
	var ok := AlmacenScript.escribir_json(ruta, dato)
	if ok:
		escrituras += 1
	return ok