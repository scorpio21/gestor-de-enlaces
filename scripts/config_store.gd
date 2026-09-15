extends RefCounted

const PARALELO_DEFAULT := 3
const TIMEOUT_DEFAULT := 10.0
const PARALELO_MIN := 1
const PARALELO_MAX := 8
const TIMEOUT_MIN := 3.0
const TIMEOUT_MAX := 60.0
const AUTO_ABRIR_DEFAULT := true
const INTERVALO_DEFAULT := 0
const INTERVALOS_VALIDOS := [0, 15, 30, 60]

var _base: String


func _init(base := "user://") -> void:
	_base = base


func cargar() -> Dictionary:
	var v: Variant = _leer_json(_ruta("config.json"))
	if typeof(v) != TYPE_DICTIONARY:
		return {
			"paralelismo": PARALELO_DEFAULT,
			"timeout": TIMEOUT_DEFAULT,
			"auto_abrir": AUTO_ABRIR_DEFAULT,
			"intervalo": INTERVALO_DEFAULT,
		}
	return {
		"paralelismo": _paralelismo_ok(v.get("paralelismo", PARALELO_DEFAULT)),
		"timeout": _timeout_ok(v.get("timeout", TIMEOUT_DEFAULT)),
		"auto_abrir": _auto_abrir_ok(v.get("auto_abrir", AUTO_ABRIR_DEFAULT)),
		"intervalo": _intervalo_ok(v.get("intervalo", INTERVALO_DEFAULT)),
	}


func guardar(paralelismo: int, timeout: float, auto_abrir := AUTO_ABRIR_DEFAULT, intervalo := INTERVALO_DEFAULT) -> bool:
	var dato := {
		"paralelismo": clampi(int(paralelismo), PARALELO_MIN, PARALELO_MAX),
		"timeout": clampf(float(timeout), TIMEOUT_MIN, TIMEOUT_MAX),
		"auto_abrir": typeof(auto_abrir) == TYPE_BOOL and bool(auto_abrir),
		"intervalo": _intervalo_ok(intervalo),
	}
	return _escribir_json(_ruta("config.json"), dato)


func _auto_abrir_ok(v: Variant) -> bool:
	return v if typeof(v) == TYPE_BOOL else AUTO_ABRIR_DEFAULT


func _intervalo_ok(v: Variant) -> int:
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		return INTERVALO_DEFAULT
	var n := int(v)
	return n if INTERVALOS_VALIDOS.has(n) else INTERVALO_DEFAULT


func _paralelismo_ok(v: Variant) -> int:
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		return PARALELO_DEFAULT
	return clampi(int(v), PARALELO_MIN, PARALELO_MAX)


func _timeout_ok(v: Variant) -> float:
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		return TIMEOUT_DEFAULT
	return clampf(float(v), TIMEOUT_MIN, TIMEOUT_MAX)


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