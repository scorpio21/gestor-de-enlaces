class_name EstadoStore
extends RefCounted

var _base: String


func _init(base := "user://") -> void:
	_base = base


func cargar() -> Dictionary:
	return {
		"estados": _leer_estados(),
		"borrados": _leer_borrados(),
	}


func guardar_estado(url: String, valido: bool, mensaje: String, codigo := 0) -> bool:
	var estados := _leer_estados()
	estados[url] = {
		"valido": valido,
		"mensaje": mensaje,
		"codigo": codigo,
		"fecha": int(Time.get_unix_time_from_system()),
	}
	return _escribir_json(_ruta("estados.json"), estados)


func marcar_borrado(url: String) -> bool:
	var borrados := _leer_borrados()
	if not borrados.has(url):
		borrados.append(url)
	return _escribir_json(_ruta("borrados.json"), borrados)


func borrar_estado(url: String) -> void:
	var estados := _leer_estados()
	if estados.erase(url):
		_escribir_json(_ruta("estados.json"), estados)


func _leer_estados() -> Dictionary:
	var v: Variant = _leer_json(_ruta("estados.json"))
	return v if typeof(v) == TYPE_DICTIONARY else {}


func _leer_borrados() -> Array:
	var v: Variant = _leer_json(_ruta("borrados.json"))
	return v if typeof(v) == TYPE_ARRAY else []


func _leer_json(ruta: String) -> Variant:
	if not FileAccess.file_exists(ruta):
		return null
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return null
	var json := JSON.new()
	if json.parse(archivo.get_as_text()) != OK:
		return null
	return json.data


func _escribir_json(ruta: String, dato: Variant) -> bool:
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		return false
	archivo.store_string(JSON.stringify(dato, "\t"))
	archivo.close()
	return true


func _ruta(nombre: String) -> String:
	if _base.ends_with("://"):
		return _base + nombre
	return _base + "/" + nombre