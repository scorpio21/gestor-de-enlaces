extends RefCounted

const DashboardStoreScript := preload("res://scripts/dashboard_store.gd")

const LIMITE_DEFAULT := 365
const LIMITE_MIN := 30
const LIMITE_MAX := 3650
const NOMBRE := "instantaneas.json"

var _base: String
var escrituras := 0


func _init(base := "user://") -> void:
	_base = base


func ruta() -> String:
	if _base.ends_with("://"):
		return _base + NOMBRE
	return _base + "/" + NOMBRE


func cargar() -> Array:
	var dato: Variant = _leer_json()
	if typeof(dato) != TYPE_ARRAY:
		return []
	var lista: Array = []
	var vistas := {}
	for fila in dato:
		var limpia := normalizar(fila)
		if limpia.is_empty():
			continue
		var clave := str(limpia["fecha"])
		if vistas.has(clave):
			continue
		vistas[clave] = true
		lista.append(limpia)
	lista.sort_custom(_por_fecha)
	return lista


func guardar(entradas: Array, estados: Dictionary, limite := LIMITE_DEFAULT) -> Dictionary:
	var fila := fila_de(entradas, estados)
	var clave := str(fila["fecha"])
	var previas := cargar()
	var reemplaza := false
	var finales: Array = []
	for f in previas:
		if str(f.get("fecha", "")) == clave:
			reemplaza = true
			continue
		finales.append(f)
	finales.append(fila)
	finales.sort_custom(_por_fecha)
	var descartadas := _recortar(finales, limite_ok(limite))
	if int(fila["total"]) <= 0:
		return {"ok": true, "guardada": false, "fecha": clave, "total": 0, "reemplazo": reemplaza, "descartadas": descartadas}
	return {"ok": _escribir_json(descartadas), "guardada": true, "fecha": clave, "total": int(fila["total"]), "reemplazo": reemplaza, "descartadas": descartadas}


func purgar(dias := LIMITE_DEFAULT) -> Dictionary:
	var lista := cargar()
	var finales := _recortar(lista, limite_ok(dias))
	if finales.size() == lista.size():
		return {"ok": true, "borradas": 0, "quedan": lista.size()}
	return {"ok": _escribir_json(finales), "borradas": lista.size() - finales.size(), "quedan": finales.size()}


func limpiar() -> bool:
	if not FileAccess.file_exists(ruta()):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta())) == OK


static func fila_de(entradas: Array, estados: Dictionary, dia := "") -> Dictionary:
	var r: Dictionary = DashboardStoreScript.resumen(entradas, estados)
	return {
		"fecha": dia if fecha_valida(dia) else DashboardStoreScript.clave_de_dia(int(Time.get_unix_time_from_system())),
		"total": int(r.get("total", 0)),
		"validos": int(r.get("activos", 0)),
		"caidos": int(r.get("rotos", 0)),
		"sin_comprobar": int(r.get("sin_comprobar", 0)),
	}


static func normalizar(fila: Variant) -> Dictionary:
	if typeof(fila) != TYPE_DICTIONARY:
		return {}
	var dato: Dictionary = fila
	var clave := str(dato.get("fecha", ""))
	if not fecha_valida(clave):
		return {}
	var total := maxi(0, int(dato.get("total", 0)))
	var validos := clampi(int(dato.get("validos", 0)), 0, total)
	var caidos := clampi(int(dato.get("caidos", 0)), 0, total)
	return {
		"fecha": clave,
		"total": total,
		"validos": validos,
		"caidos": caidos,
		"sin_comprobar": clampi(int(dato.get("sin_comprobar", 0)), 0, total - validos - caidos),
	}


static func fecha_valida(clave: String) -> bool:
	if clave.length() != 10 or clave[4] != "-" or clave[7] != "-":
		return false
	var mes := int(clave.substr(5, 2))
	var dia := int(clave.substr(8, 2))
	return mes >= 1 and mes <= 12 and dia >= 1 and dia <= 31


static func fecha_a_unix(clave: String) -> int:
	if not fecha_valida(clave):
		return 0
	return int(Time.get_unix_time_from_datetime_dict({
		"year": int(clave.substr(0, 4)),
		"month": int(clave.substr(5, 2)),
		"day": int(clave.substr(8, 2)),
		"hour": 12,
	}))


static func limite_ok(v: Variant) -> int:
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		return LIMITE_DEFAULT
	return clampi(int(v), LIMITE_MIN, LIMITE_MAX)


func _recortar(lista: Array, limite: int) -> Array:
	var hoy := DashboardStoreScript.clave_de_dia(int(Time.get_unix_time_from_system()))
	var desde := fecha_a_unix(hoy) - maxi(0, limite - 1) * 86400
	var finales: Array = []
	for f in lista:
		if fecha_a_unix(str(f.get("fecha", ""))) >= desde:
			finales.append(f)
	return finales


func _por_fecha(a: Dictionary, b: Dictionary) -> bool:
	return str(a["fecha"]) < str(b["fecha"])


func _leer_json() -> Variant:
	if not FileAccess.file_exists(ruta()):
		return null
	var archivo := FileAccess.open(ruta(), FileAccess.READ)
	if archivo == null:
		return null
	var json := JSON.new()
	if json.parse(archivo.get_as_text()) != OK:
		return null
	return json.data


func _escribir_json(lista: Array) -> bool:
	if not _base.ends_with("://"):
		DirAccess.make_dir_recursive_absolute(_base)
	var texto := JSON.stringify(lista, "\t")
	if texto.is_empty():
		return false
	escrituras += 1
	var archivo := FileAccess.open(ruta(), FileAccess.WRITE)
	if archivo == null:
		return false
	archivo.store_string(texto)
	archivo.close()
	return true
