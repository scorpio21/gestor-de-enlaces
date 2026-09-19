class_name ColaStore
extends RefCounted

var _base: String
const _NOMBRE := "colas.json"


func _init(base := "user://") -> void:
	_base = base


func cargar() -> Dictionary:
	return {
		"urls": _leer_urls(),
		"fecha": _leer_fecha(),
	}


func guardar(urls: Array) -> bool:
	if not _base.ends_with("://"):
		DirAccess.make_dir_recursive_absolute(_base)
	var datos := {"urls": urls, "fecha": int(Time.get_unix_time_from_system())}
	return _escribir_json(_ruta(), datos)


func limpiar() -> bool:
	if not FileAccess.file_exists(_ruta()):
		return true
	var err := DirAccess.remove_absolute(_ruta())
	return err == OK


func _leer_urls() -> Array:
	var dato: Variant = _leer_json(_ruta())
	if typeof(dato) != TYPE_DICTIONARY:
		return []
	var u: Variant = (dato as Dictionary).get("urls", [])
	return u if typeof(u) == TYPE_ARRAY else []


func _leer_fecha() -> int:
	var dato: Variant = _leer_json(_ruta())
	if typeof(dato) != TYPE_DICTIONARY:
		return 0
	return int((dato as Dictionary).get("fecha", 0))


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


func _ruta() -> String:
	if _base.ends_with("://"):
		return _base + _NOMBRE
	return _base + "/" + _NOMBRE