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


const LIMITE_HISTORIAL := 50


func guardar_estado(url: String, valido: bool, mensaje: String, codigo := 0) -> bool:
	var estados := _leer_estados()
	var ahora := int(Time.get_unix_time_from_system())
	var previa: Dictionary = estados.get(url, {})
	var hist: Variant = previa.get("historial", [])
	var historial: Array = hist if typeof(hist) == TYPE_ARRAY else []
	var nuevo := {"fecha": ahora, "valido": valido, "mensaje": mensaje, "codigo": codigo}
	if historial.is_empty() or not _estados_iguales(historial[0], nuevo):
		historial.push_front(nuevo)
		if historial.size() > LIMITE_HISTORIAL:
			historial.resize(LIMITE_HISTORIAL)
	estados[url] = {
		"valido": valido,
		"mensaje": mensaje,
		"codigo": codigo,
		"fecha": ahora,
		"historial": historial,
	}
	return _escribir_json(_ruta("estados.json"), estados)


func historial_de(url: String) -> Array:
	var estados := _leer_estados()
	var e: Dictionary = estados.get(url, {})
	var h: Variant = e.get("historial", [])
	return h if typeof(h) == TYPE_ARRAY else []


func _estados_iguales(a: Dictionary, b: Dictionary) -> bool:
	return a.get("valido") == b.get("valido") \
		and a.get("mensaje") == b.get("mensaje") \
		and a.get("codigo") == b.get("codigo")


func marcar_borrado(url: String) -> bool:
	var borrados := _leer_borrados()
	if not borrados.has(url):
		borrados.append(url)
	return _escribir_json(_ruta("borrados.json"), borrados)


func borrar_estado(url: String) -> void:
	var estados := _leer_estados()
	if estados.erase(url):
		_escribir_json(_ruta("estados.json"), estados)


func renombrar(url_antigua: String, url_nueva: String) -> bool:
	var estados := _leer_estados()
	if url_antigua != url_nueva and estados.has(url_antigua):
		estados[url_nueva] = estados[url_antigua]
		estados.erase(url_antigua)
	var borrados := _leer_borrados()
	if url_antigua != url_nueva:
		for i in range(borrados.size() - 1, -1, -1):
			if str(borrados[i]) == url_antigua:
				borrados[i] = url_nueva
	return _escribir_json(_ruta("estados.json"), estados) \
		and _escribir_json(_ruta("borrados.json"), borrados)


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