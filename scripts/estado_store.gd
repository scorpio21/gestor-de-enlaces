class_name EstadoStore
extends RefCounted

var _base: String
var almacen = null
var _estados: Dictionary = {}
var _borrados: Array = []
var _cargado := false
var escrituras := 0


func _init(base := "user://", almacen_almacen = null) -> void:
	_base = base
	almacen = almacen_almacen


func cargar() -> Dictionary:
	_asegurar_cargado()
	return {
		"estados": _estados,
		"borrados": _borrados,
	}


const LIMITE_HISTORIAL := 50
const INTERVALO_VOLCADO := 25


func guardar_estado(url: String, valido: Variant, mensaje: String, codigo := 0, intentos := 1, motivo := "", url_final := "") -> bool:
	_asegurar_cargado()
	var ahora := int(Time.get_unix_time_from_system())
	var previa: Dictionary = _estados.get(url, {})
	var hist: Variant = previa.get("historial", [])
	var historial: Array = hist if typeof(hist) == TYPE_ARRAY else []
	var nuevo := {"fecha": ahora, "valido": valido, "mensaje": mensaje, "codigo": codigo, "intentos": intentos, "motivo": motivo, "url_final": url_final}
	if historial.is_empty() or not _estados_iguales(historial[0], nuevo):
		historial.push_front(nuevo)
		if historial.size() > LIMITE_HISTORIAL:
			historial.resize(LIMITE_HISTORIAL)
	_estados[url] = {
		"valido": valido,
		"mensaje": mensaje,
		"codigo": codigo,
		"fecha": ahora,
		"intentos": intentos,
		"motivo": motivo,
		"url_final": url_final,
		"historial": historial,
	}
	return true


func volcar() -> bool:
	_asegurar_cargado()
	if almacen != null:
		escrituras += 1
		return almacen.guardar_estados_y_borrados(_estados, _borrados)
	return _escribir_json(_ruta("estados.json"), _estados) \
		and _escribir_json(_ruta("borrados.json"), _borrados)


func historial_de(url: String) -> Array:
	_asegurar_cargado()
	var e: Dictionary = _estados.get(url, {})
	var h: Variant = e.get("historial", [])
	return h if typeof(h) == TYPE_ARRAY else []


func _estados_iguales(a: Dictionary, b: Dictionary) -> bool:
	return a.get("valido") == b.get("valido") \
		and a.get("mensaje") == b.get("mensaje") \
		and a.get("codigo") == b.get("codigo") \
		and str(a.get("url_final", "")) == str(b.get("url_final", ""))


func marcar_borrado(url: String) -> bool:
	_asegurar_cargado()
	if not _borrados.has(url):
		_borrados.append(url)
	return volcar()


func borrar_estado(url: String) -> void:
	_asegurar_cargado()
	if _estados.erase(url):
		volcar()


func renombrar(url_antigua: String, url_nueva: String) -> bool:
	_asegurar_cargado()
	if url_antigua != url_nueva and _estados.has(url_antigua):
		_estados[url_nueva] = _estados[url_antigua]
		_estados.erase(url_antigua)
	if url_antigua != url_nueva:
		for i in range(_borrados.size() - 1, -1, -1):
			if str(_borrados[i]) == url_antigua:
				_borrados[i] = url_nueva
	return volcar()


func _asegurar_cargado() -> void:
	if _cargado:
		return
	_cargado = true
	if almacen != null:
		var estados: Variant = almacen.estados()
		_estados = estados if typeof(estados) == TYPE_DICTIONARY else {}
		var borrados: Variant = almacen.borrados()
		_borrados = borrados if typeof(borrados) == TYPE_ARRAY else []
		return
	var leidos: Variant = _leer_json(_ruta("estados.json"))
	_estados = leidos if typeof(leidos) == TYPE_DICTIONARY else {}
	var leidos_borrados: Variant = _leer_json(_ruta("borrados.json"))
	_borrados = leidos_borrados if typeof(leidos_borrados) == TYPE_ARRAY else []


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
	var texto := JSON.stringify(dato, "\t")
	if texto.is_empty():
		return false
	escrituras += 1
	var abs := ProjectSettings.globalize_path(ruta)
	var abs_tmp := ProjectSettings.globalize_path(ruta + ".tmp")
	var abs_bak := ProjectSettings.globalize_path(ruta + ".bak")
	var archivo := FileAccess.open(ruta + ".tmp", FileAccess.WRITE)
	if archivo == null:
		return false
	archivo.store_string(texto)
	archivo.close()
	if archivo.get_error() != OK:
		DirAccess.remove_absolute(abs_tmp)
		return false
	if FileAccess.file_exists(ruta):
		if FileAccess.file_exists(ruta + ".bak"):
			DirAccess.remove_absolute(abs_bak)
		if DirAccess.rename_absolute(abs, abs_bak) != OK:
			DirAccess.remove_absolute(abs_tmp)
			return false
	if DirAccess.rename_absolute(abs_tmp, abs) != OK:
		DirAccess.remove_absolute(abs_tmp)
		return false
	return true


func _ruta(nombre: String) -> String:
	if _base.ends_with("://"):
		return _base + nombre
	return _base + "/" + nombre
