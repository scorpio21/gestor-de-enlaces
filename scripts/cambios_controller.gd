extends RefCounted

const CambiosStoreScript := preload("res://scripts/cambios_store.gd")
const GestorCatalogoScript := preload("res://scripts/gestor_catalogo.gd")
const AlmacenScript := preload("res://scripts/almacen.gd")

const PENDIENTES := "user://cambios_pendientes.json"

var ruta := PENDIENTES
var almacen = null
var _claves := {}
var _vistos := false


func registrar(cambios: Array) -> Array:
	_claves = {}
	for cambio in cambios:
		if typeof(cambio) != TYPE_DICTIONARY:
			continue
		var clave := str(cambio.get("clave", ""))
		if not clave.is_empty():
			_claves[clave] = str(cambio.get("tipo", ""))
	return cambios


func marcar_vistos() -> void:
	_vistos = true
	borrar_pendientes()


func vistos() -> bool:
	return _vistos


func marca_de(clave: String) -> String:
	match str(_claves.get(clave, "")):
		CambiosStoreScript.TIPO_NUEVO_CAIDO:
			return "caido"
		CambiosStoreScript.TIPO_RECUPERADO:
			return "valido"
		CambiosStoreScript.TIPO_REUBICADO:
			return "aviso"
	return ""


func nombres_de(entradas: Array) -> Dictionary:
	var nombres := {}
	for entrada in entradas:
		if typeof(entrada) == TYPE_DICTIONARY:
			nombres[GestorCatalogoScript.clave_unica(str(entrada.get("url", "")))] = str(entrada.get("nombre", ""))
	return nombres


func claves() -> Dictionary:
	return _claves


func cobertura_de(estados: Dictionary) -> int:
	return CambiosStoreScript.cobertura(estados)


func pendientes_al_salir() -> Array:
	var cambios: Array = []
	for clave in _claves.keys():
		cambios.append({"clave": clave, "tipo": str(_claves[clave])})
	return cambios


func nuevo_delta(antes: Dictionary, despues: Dictionary) -> Array:
	return registrar(CambiosStoreScript.cambios_de(CambiosStoreScript.delta(antes, despues)))


func leer_pendientes() -> Array:
	if almacen != null:
		return almacen.cambios()
	if not FileAccess.file_exists(ruta):
		return []
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	return datos if typeof(datos) == TYPE_ARRAY else []


func guardar_pendientes(cambios: Array) -> bool:
	if almacen != null:
		return almacen.guardar_cambios(cambios)
	# Esto abria el destino en WRITE y escribia encima: un corte a mitad dejaba
	# cambios_pendientes.json corrupto y con ello se perdia el aviso de cambios sin
	# ver de la sesion anterior. Es la misma escritura atomica del resto (#63).
	return AlmacenScript.escribir_json(ruta, cambios, false)


func borrar_pendientes() -> bool:
	if almacen != null:
		return almacen.guardar_cambios([])
	if not FileAccess.file_exists(ruta):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta)) == OK