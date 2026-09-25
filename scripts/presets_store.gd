extends RefCounted

const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")

const NOMBRE_MAX := 40
const MAX_PRESETS := 20
const FILTRO_ESTADO_DEFAULT := 0
const FILTRO_ESTADO_MAX := 3
const FILTRO_CATEGORIA_DEFAULT := 0
const FILTRO_ETIQUETA_DEFAULT := ""
const BUSQUEDA_DEFAULT := ""
const FILTRO_CODIGO_DEFAULT := ""
const FILTRO_DIAS_DEFAULT := 0
const FILTRO_DIAS_MAX := 3650
const BUSQUEDA_MODO_DEFAULT := "and"
const BUSQUEDA_MODOS_VALIDOS := ["and", "or"]

var _base: String


func _init(base := "user://") -> void:
	_base = base


func cargar() -> Dictionary:
	var v: Variant = _leer_json(_ruta("presets_filtros.json"))
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	var presets := {}
	for nombre in v:
		if not nombre_ok(str(nombre)):
			continue
		presets[str(nombre)] = normalizar_config(v[nombre])
	return presets


func guardar(presets: Dictionary) -> bool:
	var dato := {}
	for nombre in presets:
		if nombre_ok(str(nombre)):
			dato[str(nombre)] = normalizar_config(presets[nombre])
	return _escribir_json(_ruta("presets_filtros.json"), dato)


func normalizar_config(v: Variant) -> Dictionary:
	if typeof(v) != TYPE_DICTIONARY:
		v = {}
	return {
		"filtro_estado": _filtro_estado_ok(v.get("filtro_estado", FILTRO_ESTADO_DEFAULT)),
		"filtro_categoria": _filtro_categoria_ok(v.get("filtro_categoria", FILTRO_CATEGORIA_DEFAULT)),
		"filtro_etiqueta": _string_ok(v.get("filtro_etiqueta", FILTRO_ETIQUETA_DEFAULT)),
		"busqueda": _string_ok(v.get("busqueda", BUSQUEDA_DEFAULT)),
		"filtro_codigo": _string_ok(v.get("filtro_codigo", FILTRO_CODIGO_DEFAULT)),
		"filtro_dias": _filtro_dias_ok(v.get("filtro_dias", FILTRO_DIAS_DEFAULT)),
		"busqueda_modo": _busqueda_modo_ok(v.get("busqueda_modo", BUSQUEDA_MODO_DEFAULT)),
	}


func nombre_ok(nombre: String) -> bool:
	var n := nombre.strip_edges()
	return not n.is_empty() and n.length() <= NOMBRE_MAX


func aplicar_preset(presets: Dictionary, nombre: String) -> Dictionary:
	if not presets.has(nombre):
		return {}
	return normalizar_config(presets[nombre])


func guardar_preset(presets: Dictionary, nombre: String, config: Dictionary) -> Dictionary:
	if not nombre_ok(nombre):
		return presets
	var nuevo := presets.duplicate(true)
	nuevo[str(nombre.strip_edges())] = normalizar_config(config)
	if nuevo.size() > MAX_PRESETS:
		return presets
	return nuevo


func borrar_preset(presets: Dictionary, nombre: String) -> Dictionary:
	if not presets.has(nombre):
		return presets
	var nuevo := presets.duplicate(true)
	nuevo.erase(nombre)
	return nuevo


func nombres(presets: Dictionary) -> Array[String]:
	var lista: Array[String] = []
	for nombre in presets:
		if nombre_ok(str(nombre)):
			lista.append(str(nombre))
	lista.sort()
	return lista


func _filtro_estado_ok(v: Variant) -> int:
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		return FILTRO_ESTADO_DEFAULT
	return clampi(int(v), FILTRO_ESTADO_DEFAULT, FILTRO_ESTADO_MAX)


func _filtro_categoria_ok(v: Variant) -> int:
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		return FILTRO_CATEGORIA_DEFAULT
	return clampi(int(v), FILTRO_CATEGORIA_DEFAULT, GestorCatalogoScript.CATEGORIAS.size())


func _filtro_dias_ok(v: Variant) -> int:
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		return FILTRO_DIAS_DEFAULT
	return clampi(int(v), FILTRO_DIAS_DEFAULT, FILTRO_DIAS_MAX)


func _busqueda_modo_ok(v: Variant) -> String:
	var modo := str(v)
	return modo if BUSQUEDA_MODOS_VALIDOS.has(modo) else BUSQUEDA_MODO_DEFAULT


func _string_ok(v: Variant) -> String:
	return str(v) if typeof(v) == TYPE_STRING else ""


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